import 'dart:async';
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 首帧拦截器
/// 
/// 解决视频跳转时的黑屏/白屏闪烁问题
/// 通过显示封面图作为占位，直到播放器渲染第一帧
class FirstFrameInterceptor extends StatefulWidget {
  const FirstFrameInterceptor({
    super.key,
    required this.child,
    required this.coverUrl,
    this.onFirstFrameRendered,
    this.fadeDuration = const Duration(milliseconds: 200),
    this.placeholderBuilder,
  });

  /// 播放器组件
  final Widget child;
  
  /// 封面图 URL
  final String? coverUrl;
  
  /// 首帧渲染完成回调
  final VoidCallback? onFirstFrameRendered;
  
  /// 淡出动画持续时间
  final Duration fadeDuration;
  
  /// 自定义占位图构建器
  final WidgetBuilder? placeholderBuilder;

  @override
  State<FirstFrameInterceptor> createState() => _FirstFrameInterceptorState();
}

class _FirstFrameInterceptorState extends State<FirstFrameInterceptor>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isFirstFrameRendered = false;
  ui.Image? _capturedFrame;
  bool _showPlaceholder = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: widget.fadeDuration,
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// 标记首帧已渲染
  void onFirstFrameRendered() {
    if (!_isFirstFrameRendered && mounted) {
      setState(() {
        _isFirstFrameRendered = true;
      });
      
      // 开始淡出动画
      _fadeController.forward().then((_) {
        if (mounted) {
          setState(() {
            _showPlaceholder = false;
          });
        }
        widget.onFirstFrameRendered?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 实际的播放器
        widget.child,
        
        // 封面图占位层
        if (_showPlaceholder)
          FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
            child: _buildPlaceholder(),
          ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholderBuilder != null) {
      return widget.placeholderBuilder!(context);
    }

    if (widget.coverUrl?.isNotEmpty == true) {
      return Container(
        color: Colors.black,
        child: Image.network(
          widget.coverUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// 视频播放器首帧监听 mixin
/// 
/// 用于在播放器控制器中集成首帧检测
mixin FirstFrameListenerMixin<T extends StatefulWidget> on State<T> {
  bool _isFirstFrameRendered = false;
  final List<VoidCallback> _firstFrameCallbacks = [];

  /// 是否已渲染首帧
  bool get isFirstFrameRendered => _isFirstFrameRendered;

  /// 注册首帧回调
  void addFirstFrameListener(VoidCallback callback) {
    if (_isFirstFrameRendered) {
      callback();
    } else {
      _firstFrameCallbacks.add(callback);
    }
  }

  /// 移除首帧回调
  void removeFirstFrameListener(VoidCallback callback) {
    _firstFrameCallbacks.remove(callback);
  }

  /// 标记首帧已渲染
  void notifyFirstFrameRendered() {
    if (!_isFirstFrameRendered) {
      _isFirstFrameRendered = true;
      for (final callback in _firstFrameCallbacks) {
        callback();
      }
      _firstFrameCallbacks.clear();
    }
  }

  /// 重置首帧状态（用于切换视频时）
  void resetFirstFrameState() {
    _isFirstFrameRendered = false;
  }
}

/// 无缝视频切换控制器
/// 
/// 管理视频之间的无缝切换，保持当前帧作为占位
class SeamlessVideoSwitcher extends StatefulWidget {
  const SeamlessVideoSwitcher({
    super.key,
    required this.videoPlayer,
    required this.coverUrl,
    this.transitionDuration = const Duration(milliseconds: 300),
  });

  final Widget videoPlayer;
  final String? coverUrl;
  final Duration transitionDuration;

  @override
  State<SeamlessVideoSwitcher> createState() => _SeamlessVideoSwitcherState();
}

class _SeamlessVideoSwitcherState extends State<SeamlessVideoSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );
    
    // 延迟显示视频，先展示封面图
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _showVideo = true;
        });
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(SeamlessVideoSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果视频变化，重置状态
    if (oldWidget.videoPlayer != widget.videoPlayer) {
      _controller.reset();
      setState(() {
        _showVideo = false;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _showVideo = true;
          });
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面图背景
        if (widget.coverUrl?.isNotEmpty == true)
          Image.network(
            widget.coverUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        
        // 视频播放器（淡入）
        if (_showVideo)
          FadeTransition(
            opacity: _controller,
            child: widget.videoPlayer,
          ),
      ],
    );
  }
}

/// 视频缩略图捕获器
/// 
/// 用于从当前播放的视频帧生成缩略图
class VideoThumbnailCapture {
  /// 捕获当前帧（平台特定实现）
  static Future<Uint8List?> captureFrame() async {
    // 注意：这需要平台特定的实现
    // Android: TextureView.getBitmap()
    // iOS: AVAssetImageGenerator
    // 这里提供一个接口，具体实现需要根据平台添加
    return null;
  }
}

/// 首帧占位图组件
/// 
/// 显示封面图或纯色占位，直到视频准备好
class FirstFramePlaceholder extends StatelessWidget {
  const FirstFramePlaceholder({
    super.key,
    this.coverUrl,
    this.fit = BoxFit.cover,
    this.showLoading = true,
  });

  final String? coverUrl;
  final BoxFit fit;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    Widget child;
    
    if (coverUrl?.isNotEmpty == true) {
      child = Image.network(
        coverUrl!,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingIndicator();
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback();
        },
      );
    } else {
      child = _buildFallback();
    }

    return Container(
      color: Colors.black,
      child: child,
    );
  }

  Widget _buildLoadingIndicator() {
    if (!showLoading) return const SizedBox.shrink();
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: Colors.white54,
          size: 64,
        ),
      ),
    );
  }
}
