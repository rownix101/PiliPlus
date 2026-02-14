import 'package:PiliPlus/common/widgets/animation/staggered_animation.dart';
import 'package:PiliPlus/common/widgets/skeleton/skeleton_screen.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:flutter/material.dart';

/// 加载状态包装器
/// 
/// 根据加载状态自动显示骨架屏或内容，并支持错落动画
class LoadingWrapper<T> extends StatelessWidget {
  const LoadingWrapper({
    super.key,
    required this.loadingState,
    required this.builder,
    this.skeleton,
    this.errorBuilder,
    this.loadingBuilder,
    this.onRetry,
    this.useStaggeredAnimation = true,
    this.staggeredDelay = Duration.zero,
  });

  final LoadingState<T> loadingState;
  final Widget Function(T data) builder;
  final Widget? skeleton;
  final Widget Function(String? error)? errorBuilder;
  final Widget? loadingBuilder;
  final VoidCallback? onRetry;
  final bool useStaggeredAnimation;
  final Duration staggeredDelay;

  @override
  Widget build(BuildContext context) {
    return switch (loadingState) {
      Loading() => _buildLoading(),
      Success<T>(:final response) => _buildSuccess(response),
      Error(:final errMsg) => _buildError(errMsg),
    };
  }

  Widget _buildLoading() {
    return loadingBuilder ?? 
           skeleton ?? 
           const VideoDetailSkeleton();
  }

  Widget _buildSuccess(T data) {
    final content = builder(data);
    
    if (!useStaggeredAnimation) {
      return content;
    }
    
    // 使用错落动画包装内容
    return StaggeredFadeIn(
      delay: staggeredDelay,
      duration: const Duration(milliseconds: 350),
      animationType: StaggeredAnimationType.slideUpFade,
      child: content,
    );
  }

  Widget _buildError(String? error) {
    if (errorBuilder != null) {
      return errorBuilder!(error);
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.grey,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            error ?? '加载失败',
            style: const TextStyle(color: Colors.grey),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 骨架屏切换动画
/// 
/// 在骨架屏和内容之间平滑过渡
class SkeletonTransition extends StatelessWidget {
  const SkeletonTransition({
    super.key,
    required this.isLoading,
    required this.child,
    this.skeleton,
    this.duration = const Duration(milliseconds: 300),
  });

  final bool isLoading;
  final Widget child;
  final Widget? skeleton;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: isLoading
          ? (skeleton ?? const VideoDetailSkeleton())
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: child,
            ),
    );
  }
}

/// 视频详情页内容加载器
/// 
/// 专为视频详情页设计的加载状态管理组件
class VideoDetailContentLoader extends StatelessWidget {
  const VideoDetailContentLoader({
    super.key,
    required this.isLoading,
    required this.player,
    required this.introduction,
    required this.comments,
    this.relatedVideos,
    this.coverUrl,
    this.onRetry,
  });

  final bool isLoading;
  final Widget player;
  final Widget introduction;
  final Widget comments;
  final Widget? relatedVideos;
  final String? coverUrl;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return VideoDetailSkeleton(
        aspectRatio: 16 / 9,
        hasComments: true,
        commentCount: 3,
      );
    }

    // 使用错落动画布局
    return VideoDetailStaggeredLayout(
      player: player,
      titleSection: introduction,
      commentsSection: comments,
      relatedVideosSection: relatedVideos,
    );
  }
}
