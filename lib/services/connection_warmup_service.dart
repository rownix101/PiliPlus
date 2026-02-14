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

  // 视频 CDN 域名列表（用于视频播放预热）
  static const List<String> _videoCdnHosts = [
    'upos-sz-mirrorali.bilivideo.com',
    'upos-sz-mirrorcos.bilivideo.com',
    'upos-sz-mirrorhw.bilivideo.com',
    'upos-hz-mirrorakam.akamaized.net',
    'cn-hk-eq-bcache-01.bilivideo.com',
  ];

  // DNS 缓存 TTL
  static const Duration _dnsCacheTtl = Duration(minutes: 5);

  // 预热超时配置
  static const Duration _defaultWarmupTimeout = Duration(seconds: 3);
  static const Duration _videoPageWarmupTimeout = Duration(seconds: 2);
  static const Duration _singleEndpointTimeout = Duration(seconds: 1);

  /// DNS 预解析
  /// 提前解析主要域名的 IP 地址，减少 DNS 查询延迟
  /// 注意：不再限制 HTTP/2 模式，为所有网络模式提供 DNS 优化
  Future<void> preResolveDns() async {
    // 加载持久化的 DNS 缓存
    _loadDnsCacheFromStorage();

    // 并发解析所有域名
    final futures = _mainApiHosts.map(resolveDnsWithOptimisticCache).toList();
    
    await Future.wait(futures);
  }

  /// 从持久化存储加载 DNS 缓存
  void _loadDnsCacheFromStorage() {
    try {
      final cachedData = Pref.dnsCacheData;
      if (cachedData != null) {
        for (final entry in cachedData) {
          final host = entry['host'] as String;
          final addresses = (entry['addresses'] as List)
              .map((addr) => InternetAddress(addr as String))
              .toList();
          final cachedAt = DateTime.fromMillisecondsSinceEpoch(
            entry['cachedAt'] as int,
          );
          // 只加载未过期的缓存
          final cacheEntry = _DnsCacheEntry(addresses, cachedAt);
          if (!cacheEntry.isExpired(ttl: _dnsCacheTtl)) {
            _dnsCache[host] = cacheEntry;
          }
        }
        if (kDebugMode && _dnsCache.isNotEmpty) {
          debugPrint('从持久化加载 ${_dnsCache.length} 个 DNS 缓存');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('加载 DNS 缓存失败: $e');
      }
    }
  }

  /// 保存 DNS 缓存到持久化存储
  Future<void> _saveDnsCacheToStorage() async {
    try {
      final cacheData = _dnsCache.entries.map((entry) => {
        'host': entry.key,
        'addresses': entry.value.addresses.map((a) => a.address).toList(),
        'cachedAt': entry.value.cachedAt.millisecondsSinceEpoch,
      }).toList();
      
      await Pref.setDnsCacheData(cacheData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('保存 DNS 缓存失败: $e');
      }
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
    return _refreshDnsInBackground(host);
  }
  
  /// 后台刷新 DNS（带防重复请求机制）
  Future<List<InternetAddress>?> _refreshDnsInBackground(String host) async {
    // 检查是否已有正在进行的查询
    if (_pendingDnsLookups.containsKey(host)) {
      return _pendingDnsLookups[host];
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
        // 更新内存缓存
        _dnsCache[host] = _DnsCacheEntry(addresses, DateTime.now());
        // 保存到持久化存储
        await _saveDnsCacheToStorage();
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
  /// 注意：不再限制 HTTP/2 模式，为所有网络模式提供优化
  Future<void> warmupConnections() async {
    final warmupFutures = <Future<void>>[];

    // 预热主要 API 端点
    for (final endpoint in _getWarmupEndpoints()) {
      if (_warmedUpHosts.contains(endpoint)) continue;

      // 每个端点独立的超时控制
      warmupFutures.add(
        _warmupEndpoint(endpoint).timeout(
          _singleEndpointTimeout,
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('连接预热单个端点超时: $endpoint');
            }
          },
        ),
      );
    }

    if (warmupFutures.isNotEmpty) {
      // 整体超时控制
      await Future.wait(warmupFutures).timeout(
        _defaultWarmupTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('连接预热整体超时，部分连接可能未建立');
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
  /// 在打开视频页面时调用，预热视频相关 API 和 CDN
  /// 注意：不再限制 HTTP/2 模式
  Future<void> warmupForVideoPage() async {
    final apiEndpoints = [
      HttpString.apiBaseUrl,  // 视频详情、播放地址
      HttpString.tUrl,        // 评论
    ];

    final warmupFutures = <Future<void>>[];

    // 预热 API 端点
    for (final endpoint in apiEndpoints) {
      warmupFutures.add(
        _warmupEndpoint(endpoint).timeout(
          _singleEndpointTimeout,
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('视频页 API 预热超时: $endpoint');
            }
          },
        ),
      );
    }

    // 预热视频 CDN（DNS 预解析）
    for (final cdnHost in _videoCdnHosts) {
      warmupFutures.add(
        _warmupCdnEndpoint(cdnHost).timeout(
          _singleEndpointTimeout,
          onTimeout: () {
            if (kDebugMode) {
              debugPrint('视频 CDN 预热超时: $cdnHost');
            }
          },
        ),
      );
    }

    await Future.wait(warmupFutures).timeout(
      _videoPageWarmupTimeout,
      onTimeout: () => [],
    );
  }

  /// 预热 CDN 端点（发送轻量级请求建立连接）
  Future<void> _warmupCdnEndpoint(String host) async {
    try {
      // CDN 预热使用 GET 请求（OPTIONS 不支持）
      final response = await Request.dio.get(
        'https://$host/crossdomain.xml',
        options: Options(
          extra: {'connection_warmup': true},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != null && response.statusCode! < 500) {
        _warmedUpHosts.add(host);
        if (kDebugMode) {
          debugPrint('CDN 预热成功: $host');
        }
      }
    } catch (e) {
      // 预热失败不影响主流程
      if (kDebugMode) {
        debugPrint('CDN 预热失败: $host, 错误: $e');
      }
    }
  }

  /// 首页连接预热
  /// 注意：不再限制 HTTP/2 模式
  Future<void> warmupForHomePage() async {
    await Future.wait([
      _warmupEndpoint(HttpString.apiBaseUrl).timeout(
        _singleEndpointTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('首页预热超时: ${HttpString.apiBaseUrl}');
          }
        },
      ),
      _warmupEndpoint(HttpString.appBaseUrl).timeout(
        _singleEndpointTimeout,
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('首页预热超时: ${HttpString.appBaseUrl}');
          }
        },
      ),
    ]).timeout(
      _videoPageWarmupTimeout,
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