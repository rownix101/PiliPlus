import 'dart:async';
import 'dart:io';

import 'package:PiliPro/http/constants.dart';
import 'package:PiliPro/http/init.dart';
import 'package:PiliPro/utils/storage_pref.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// DNS 缓存条目
class _DnsCacheEntry {
  final List<InternetAddress> addresses;
  final DateTime cachedAt;
  
  _DnsCacheEntry(this.addresses, this.cachedAt);
  
  /// 缓存是否过期（默认 5 分钟）
  bool isExpired({Duration ttl = const Duration(minutes: 5)}) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// 连接预热服务
/// 用于预先建立与主要 API 服务器的连接，减少请求延迟
class ConnectionWarmupService {
  static final ConnectionWarmupService _instance = ConnectionWarmupService._internal();
  factory ConnectionWarmupService() => _instance;
  ConnectionWarmupService._internal();

  // DNS 缓存（带时间戳）
  final Map<String, _DnsCacheEntry> _dnsCache = {};
  
  // 正在进行的 DNS 查询（防止重复请求）
  final Map<String, Future<List<InternetAddress>?>> _pendingDnsLookups = {};
  
  // 预热过的域名集合
  final Set<String> _warmedUpHosts = {};
  
  // 主要的 API 域名列表
  static const List<String> _mainApiHosts = [
    'api.bilibili.com',
    'app.bilibili.com',
    'api.vc.bilibili.com',
    'api.live.bilibili.com',
    'passport.bilibili.com',
  ];
  
  // DNS 缓存 TTL
  static const Duration _dnsCacheTtl = Duration(minutes: 5);

  /// DNS 预解析
  /// 提前解析主要域名的 IP 地址，减少 DNS 查询延迟
  Future<void> preResolveDns() async {
    if (!Pref.enableHttp2) return; // 仅在 HTTP/2 模式下进行优化
    
    for (final host in _mainApiHosts) {
      // 使用乐观缓存策略获取 DNS
      await resolveDnsWithOptimisticCache(host);
    }
  }
  
  /// DNS 乐观缓存解析
  /// 优先返回缓存（即使过期），同时在后台刷新
  Future<List<InternetAddress>?> resolveDnsWithOptimisticCache(String host) async {
    final cachedEntry = _dnsCache[host];
    
    // 如果有有效缓存，直接返回
    if (cachedEntry != null && !cachedEntry.isExpired(ttl: _dnsCacheTtl)) {
      if (kDebugMode) {
        debugPrint('DNS 缓存命中: $host');
      }
      return cachedEntry.addresses;
    }
    
    // 如果有过期缓存，先返回过期值，后台刷新
    if (cachedEntry != null && cachedEntry.isExpired(ttl: _dnsCacheTtl)) {
      if (kDebugMode) {
        debugPrint('DNS 缓存过期（乐观返回）: $host，后台刷新中...');
      }
      // 后台异步刷新，不阻塞当前请求
      _refreshDnsInBackground(host);
      return cachedEntry.addresses;
    }
    
    // 无缓存，需要同步查询
    return await _refreshDnsInBackground(host);
  }
  
  /// 后台刷新 DNS（带防重复请求机制）
  Future<List<InternetAddress>?> _refreshDnsInBackground(String host) async {
    // 检查是否已有正在进行的查询
    if (_pendingDnsLookups.containsKey(host)) {
      return await _pendingDnsLookups[host];
    }
    
    // 创建新的查询 Future
    final lookupFuture = _performDnsLookup(host);
    _pendingDnsLookups[host] = lookupFuture;
    
    try {
      final result = await lookupFuture;
      return result;
    } finally {
      _pendingDnsLookups.remove(host);
    }
  }
  
  /// 执行实际 DNS 查询
  Future<List<InternetAddress>?> _performDnsLookup(String host) async {
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isNotEmpty) {
        // 更新缓存
        _dnsCache[host] = _DnsCacheEntry(addresses, DateTime.now());
        if (kDebugMode) {
          debugPrint('DNS 解析成功: $host -> ${addresses.map((a) => a.address).join(', ')}');
        }
        return addresses;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DNS 解析失败: $host, 错误: $e');
      }
    }
    return null;
  }

  /// 获取预解析的 IP 地址（乐观缓存）
  /// 即使缓存过期也会返回，同时在后台刷新
  List<InternetAddress>? getCachedIps(String host) {
    final entry = _dnsCache[host];
    if (entry == null) return null;
    
    // 如果缓存过期，触发后台刷新但不阻塞
    if (entry.isExpired(ttl: _dnsCacheTtl)) {
      _refreshDnsInBackground(host);
    }
    
    return entry.addresses;
  }

  /// 连接预热
  /// 预先建立与主要 API 服务器的连接
  Future<void> warmupConnections() async {
    if (!Pref.enableHttp2) return; // 仅在 HTTP/2 模式下进行优化
    
    final warmupFutures = <Future<void>>[];
    
    // 预热主要 API 端点
    for (final endpoint in _getWarmupEndpoints()) {
      if (_warmedUpHosts.contains(endpoint)) continue;
      
      warmupFutures.add(_warmupEndpoint(endpoint));
    }
    
    if (warmupFutures.isNotEmpty) {
      // 并行执行所有预热请求，设置较短的超时时间
      await Future.wait(warmupFutures).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('连接预热超时，部分连接可能未建立');
          }
          return [];
        },
      );
    }
  }

  /// 获取需要预热的端点列表
  List<String> _getWarmupEndpoints() {
    return [
      HttpString.apiBaseUrl,
      HttpString.appBaseUrl,
      HttpString.tUrl,
    ];
  }

  /// 预热单个端点
  Future<void> _warmupEndpoint(String baseUrl) async {
    try {
      // 发送 HEAD 请求来建立连接，不获取实际数据
      final response = await Request.dio.head(
        '$baseUrl/x/frontend/finger/spi',
        options: Options(
          extra: {'connection_warmup': true},
        ),
      );
      
      if (response.statusCode == 200) {
        _warmedUpHosts.add(baseUrl);
        if (kDebugMode) {
          debugPrint('连接预热成功: $baseUrl');
        }
      }
    } catch (e) {
      // 预热失败不影响主流程
      if (kDebugMode) {
        debugPrint('连接预热失败: $baseUrl, 错误: $e');
      }
    }
  }

  /// 视频页面特定的连接预热
  /// 在打开视频页面时调用，预热视频相关 API
  Future<void> warmupForVideoPage() async {
    if (!Pref.enableHttp2) return;
    
    final endpoints = [
      HttpString.apiBaseUrl,  // 视频详情、播放地址
      HttpString.tUrl,        // 评论
    ];
    
    final warmupFutures = <Future<void>>[];
    for (final endpoint in endpoints) {
      warmupFutures.add(_warmupEndpoint(endpoint));
    }
    
    await Future.wait(warmupFutures).timeout(
      const Duration(seconds: 2),
      onTimeout: () => [],
    );
  }

  /// 首页连接预热
  Future<void> warmupForHomePage() async {
    if (!Pref.enableHttp2) return;
    
    await Future.wait([
      _warmupEndpoint(HttpString.apiBaseUrl),
      _warmupEndpoint(HttpString.appBaseUrl),
    ]).timeout(
      const Duration(seconds: 2),
      onTimeout: () => [],
    );
  }

  /// 清除预热状态
  void clear() {
    _warmedUpHosts.clear();
    _dnsCache.clear();
    _pendingDnsLookups.clear();
  }

  /// 检查是否已预热
  bool isWarmedUp(String host) {
    return _warmedUpHosts.contains(host);
  }
}

/// 扩展 Options 以支持连接预热标记
extension ConnectionWarmupOptions on Options {
  bool get isConnectionWarmup => extra?['connection_warmup'] == true;
}