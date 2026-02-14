import 'package:flutter/material.dart';

/// 错落动画 (Staggered Animation) 组件
/// 
/// 让多个 UI 元素按时间差依次出现，引导用户视线
/// 
/// 使用示例:
/// ```dart
/// StaggeredAnimationGroup(
///   children: [
///     StaggeredAnimationItem(
///       delay: Duration.zero,  // T0
///       child: CoverImage(),
///     ),
///     StaggeredAnimationItem(
///       delay: Duration(milliseconds: 100),  // T+100ms
///       child: TitleAndAuthor(),
///     ),
///     StaggeredAnimationItem(
///       delay: Duration(milliseconds: 200),  // T+200ms
///       child: CommentsList(),
///     ),
///   ],
/// )
/// ```
class StaggeredAnimationGroup extends StatefulWidget {
  const StaggeredAnimationGroup({
    super.key,
    required this.children,
    this.onAnimationComplete,
  });

  final List<StaggeredAnimationItem> children;
  final VoidCallback? onAnimationComplete;

  @override
  State<StaggeredAnimationGroup> createState() => _StaggeredAnimationGroupState();
}

class _StaggeredAnimationGroupState extends State<StaggeredAnimationGroup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _calculateTotalDuration(),
      vsync: this,
    );

    // 等待 widget 构建完成后开始动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward().then((_) {
          widget.onAnimationComplete?.call();
        });
      }
    });
  }

  Duration _calculateTotalDuration() {
    if (widget.children.isEmpty) return const Duration(milliseconds: 300);
    
    final maxDelay = widget.children
        .map((item) => item.delay.inMilliseconds)
        .reduce((a, b) => a > b ? a : b);
    
    return Duration(milliseconds: maxDelay + 400);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.children.map((item) {
        return _AnimatedItem(
          controller: _controller,
          delay: item.delay,
          duration: item.duration,
          curve: item.curve,
          animationType: item.animationType,
          child: item.child,
        );
      }).toList(),
    );
  }
}

/// 错落动画项
class StaggeredAnimationItem {
  const StaggeredAnimationItem({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
    this.animationType = StaggeredAnimationType.slideUpFade,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final StaggeredAnimationType animationType;
}

/// 错落动画类型
enum StaggeredAnimationType {
  /// 从下方滑入并淡现
  slideUpFade,
  /// 从上方滑入并淡现
  slideDownFade,
  /// 从左侧滑入并淡现
  slideLeftFade,
  /// 从右侧滑入并淡现
  slideRightFade,
  /// 仅淡现
  fade,
  /// 缩放并淡现
  scaleFade,
  /// 从中心放大
  scale,
}

/// 内部使用的动画项组件
class _AnimatedItem extends StatelessWidget {
  const _AnimatedItem({
    required this.controller,
    required this.delay,
    required this.duration,
    required this.curve,
    required this.animationType,
    required this.child,
  });

  final AnimationController controller;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final StaggeredAnimationType animationType;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delayMilliseconds = delay.inMilliseconds;
    final totalMilliseconds = controller.duration!.inMilliseconds;
    
    final start = delayMilliseconds / totalMilliseconds;
    final end = (delayMilliseconds + duration.inMilliseconds) / totalMilliseconds;
    
    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: curve,
      ),
    );

    switch (animationType) {
      case StaggeredAnimationType.slideUpFade:
        return _buildSlideFade(animation, const Offset(0, 30));
      case StaggeredAnimationType.slideDownFade:
        return _buildSlideFade(animation, const Offset(0, -30));
      case StaggeredAnimationType.slideLeftFade:
        return _buildSlideFade(animation, const Offset(-30, 0));
      case StaggeredAnimationType.slideRightFade:
        return _buildSlideFade(animation, const Offset(30, 0));
      case StaggeredAnimationType.fade:
        return _buildFade(animation);
      case StaggeredAnimationType.scaleFade:
        return _buildScaleFade(animation, beginScale: 0.95);
      case StaggeredAnimationType.scale:
        return _buildScaleFade(animation, beginScale: 0.9, fade: false);
    }
  }

  Widget _buildSlideFade(Animation<double> animation, Offset offset) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: offset * (1 - animation.value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildFade(Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  Widget _buildScaleFade(Animation<double> animation, {
    required double beginScale,
    bool fade = true,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final scale = beginScale + (1 - beginScale) * animation.value;
        Widget result = Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: child,
        );
        
        if (fade) {
          result = Opacity(
            opacity: animation.value,
            child: result,
          );
        }
        
        return result;
      },
      child: child,
    );
  }
}

/// 简化的错落动画包装器
/// 
/// 用于快速给单个组件添加错落动画效果
class StaggeredFadeIn extends StatelessWidget {
  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
    this.animationType = StaggeredAnimationType.slideUpFade,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final StaggeredAnimationType animationType;

  @override
  Widget build(BuildContext context) {
    return _StaggeredFadeInWrapper(
      delay: delay,
      duration: duration,
      curve: curve,
      animationType: animationType,
      child: child,
    );
  }
}

class _StaggeredFadeInWrapper extends StatefulWidget {
  const _StaggeredFadeInWrapper({
    required this.child,
    required this.delay,
    required this.duration,
    required this.curve,
    required this.animationType,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final StaggeredAnimationType animationType;

  @override
  State<_StaggeredFadeInWrapper> createState() => _StaggeredFadeInWrapperState();
}

class _StaggeredFadeInWrapperState extends State<_StaggeredFadeInWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    // 延迟后开始动画
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = StaggeredAnimationItem(
      child: widget.child,
      delay: Duration.zero,
      duration: widget.duration,
      curve: widget.curve,
      animationType: widget.animationType,
    );

    return _AnimatedItem(
      controller: _controller,
      delay: Duration.zero,
      duration: widget.duration,
      curve: widget.curve,
      animationType: widget.animationType,
      child: widget.child,
    );
  }
}

/// 视频详情页专用错落动画布局
/// 
/// 预定义了视频详情页各部分的动画时间:
/// - T0: 封面图/播放器 (delay: 0ms)
/// - T+100ms: 标题和作者信息 (delay: 100ms)
/// - T+200ms: 评论区和推荐列表 (delay: 200ms)
class VideoDetailStaggeredLayout extends StatelessWidget {
  const VideoDetailStaggeredLayout({
    super.key,
    required this.player,
    required this.titleSection,
    required this.commentsSection,
    this.relatedVideosSection,
    this.onAnimationComplete,
  });

  final Widget player;
  final Widget titleSection;
  final Widget commentsSection;
  final Widget? relatedVideosSection;
  final VoidCallback? onAnimationComplete;

  @override
  Widget build(BuildContext context) {
    return StaggeredAnimationGroup(
      onAnimationComplete: onAnimationComplete,
      children: [
        // T0: 封面图/播放器
        StaggeredAnimationItem(
          delay: Duration.zero,
          duration: const Duration(milliseconds: 300),
          animationType: StaggeredAnimationType.fade,
          child: player,
        ),
        
        // T+100ms: 标题和作者信息
        StaggeredAnimationItem(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 350),
          animationType: StaggeredAnimationType.slideUpFade,
          child: titleSection,
        ),
        
        // T+200ms: 评论区
        StaggeredAnimationItem(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 350),
          animationType: StaggeredAnimationType.slideUpFade,
          child: commentsSection,
        ),
        
        // T+250ms: 推荐列表 (可选)
        if (relatedVideosSection != null)
          StaggeredAnimationItem(
            delay: const Duration(milliseconds: 250),
            duration: const Duration(milliseconds: 350),
            animationType: StaggeredAnimationType.slideUpFade,
            child: relatedVideosSection!,
          ),
      ],
    );
  }
}
