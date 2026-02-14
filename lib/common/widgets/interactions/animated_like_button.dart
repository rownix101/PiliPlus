import 'package:flutter/material.dart';
import 'package:PiliPro/services/haptic_service.dart';

/// 带动画和触觉反馈的点赞按钮
/// 在动画最高点触发触觉反馈，提供"按下实体开关"的心理暗示
class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;
  final int count;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    required this.count,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _wasLiked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // 三段式动画：压缩 -> 弹起（最高点触觉） -> 回弹稳定
    _scaleAnimation = TweenSequence<double>([
      // 第一阶段：按下压缩（0-15%）
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.75)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 15,
      ),
      // 第二阶段：弹起过冲（15-45%） - 最高点触发触觉！
      TweenSequenceItem(
        tween: Tween(begin: 0.75, end: 1.35)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
      // 第三阶段：回弹稳定（45-100%）
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticIn)),
        weight: 55,
      ),
    ]).animate(_controller);

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 0.2,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    _wasLiked = widget.isLiked;
  }

  @override
  void didUpdateWidget(covariant AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked) {
      if (widget.isLiked && !_wasLiked) {
        // 触发完整动画
        _controller.forward(from: 0);
        // 在动画最高点（约 30% 处，150ms）触发触觉
        Future.delayed(const Duration(milliseconds: 150), () {
          HapticService.to.likeWithHaptic();
        });
      }
      _wasLiked = widget.isLiked;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _activeColor => widget.activeColor ?? Colors.red;
  Color get _inactiveColor => widget.inactiveColor ?? Colors.grey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: child,
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked ? _activeColor : _inactiveColor,
              size: widget.size,
            ),
            if (widget.count > 0)
              Text(
                _formatCount(widget.count),
                style: TextStyle(
                  fontSize: widget.size * 0.45,
                  color: widget.isLiked ? _activeColor : _inactiveColor,
                  fontWeight:
                      widget.isLiked ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    }
    return count.toString();
  }
}
