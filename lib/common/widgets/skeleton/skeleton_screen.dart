import 'package:PiliPro/common/constants.dart';
import 'package:flutter/material.dart';

/// 骨架屏组件
/// 
/// 用于在内容加载前显示占位效果，提升用户体验
class SkeletonScreen extends StatelessWidget {
  const SkeletonScreen({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color,
    this.highlightColor,
    this.shimmer = true,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? color;
  final Color? highlightColor;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = color ?? theme.colorScheme.onInverseSurface.withValues(alpha: 0.4);
    final highlight = highlightColor ?? theme.colorScheme.surface.withValues(alpha: 0.6);

    Widget child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? (borderRadius ?? StyleString.mdRadius) : null,
      ),
    );

    if (shimmer) {
      child = _ShimmerEffect(
        baseColor: baseColor,
        highlightColor: highlight,
        child: child,
      );
    }

    return child;
  }
}

/// 视频详情页骨架屏
/// 
/// 包含播放器区域、标题、作者信息、评论区的占位
class VideoDetailSkeleton extends StatelessWidget {
  const VideoDetailSkeleton({
    super.key,
    this.aspectRatio = StyleString.aspectRatio,
    this.hasComments = true,
    this.commentCount = 3,
  });

  final double aspectRatio;
  final bool hasComments;
  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 播放器区域占位
        AspectRatio(
          aspectRatio: aspectRatio,
          child: const SkeletonScreen(shimmer: false),
        ),
        
        // 标题占位
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主标题
              SkeletonScreen(width: double.infinity, height: 24),
              SizedBox(height: 8),
              // 副标题
              SkeletonScreen(width: 200, height: 16),
              SizedBox(height: 16),
              
              // 作者信息占位
              Row(
                children: [
                  // 头像
                  SkeletonScreen(width: 40, height: 40, shape: BoxShape.circle),
                  SizedBox(width: 12),
                  // 作者名
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonScreen(width: 120, height: 16),
                        SizedBox(height: 4),
                        SkeletonScreen(width: 80, height: 12),
                      ],
                    ),
                  ),
                  // 关注按钮
                  SkeletonScreen(width: 80, height: 32, borderRadius: BorderRadius.all(Radius.circular(16))),
                ],
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // 评论区占位
        if (hasComments)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 评论区标题
                const SkeletonScreen(width: 100, height: 18),
                const SizedBox(height: 16),
                // 评论项占位
                ...List.generate(commentCount, (index) => const _CommentSkeletonItem()),
              ],
            ),
          ),
      ],
    );
  }
}

/// 评论骨架屏项
class _CommentSkeletonItem extends StatelessWidget {
  const _CommentSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          SkeletonScreen(width: 36, height: 36, shape: BoxShape.circle),
          SizedBox(width: 12),
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户名
                SkeletonScreen(width: 100, height: 14),
                SizedBox(height: 6),
                // 评论内容
                SkeletonScreen(width: double.infinity, height: 12),
                SizedBox(height: 4),
                SkeletonScreen(width: 200, height: 12),
                SizedBox(height: 8),
                // 时间 + 点赞
                Row(
                  children: [
                    SkeletonScreen(width: 60, height: 10),
                    SizedBox(width: 16),
                    SkeletonScreen(width: 40, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 视频卡片骨架屏
class VideoCardSkeleton extends StatelessWidget {
  const VideoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 封面图占位
        AspectRatio(
          aspectRatio: StyleString.aspectRatio,
          child: const SkeletonScreen(),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              SkeletonScreen(width: double.infinity, height: 16),
              SizedBox(height: 4),
              SkeletonScreen(width: 150, height: 16),
              SizedBox(height: 8),
              // 作者名
              SkeletonScreen(width: 100, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// 闪烁动画效果
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1, 0),
              end: const Alignment(1, 0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * slidePercent,
      0.0,
      0.0,
    );
  }
}

/// 骨架屏装饰器
/// 
/// 用于包装任意组件，在加载时显示骨架屏
class SkeletonDecorator extends StatelessWidget {
  const SkeletonDecorator({
    super.key,
    required this.child,
    required this.isLoading,
    this.skeleton,
  });

  final Widget child;
  final bool isLoading;
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading
          ? (skeleton ?? const SkeletonScreen())
          : child,
    );
  }
}
