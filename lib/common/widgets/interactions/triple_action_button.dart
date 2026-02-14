import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:PiliPro/services/haptic_service.dart';

/// 三连按钮（长按触发三连动画和触觉反馈）
/// 支持普通点击和长按三连两种交互模式
class TripleActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onTripleAction;
  final Widget child;
  final Duration longPressDuration;
  final Duration animationDuration;

  const TripleActionButton({
    super.key,
    required this.onTap,
    required this.onTripleAction,
    required this.child,
    this.longPressDuration = const Duration(milliseconds: 600),
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<TripleActionButton> createState() => _TripleActionButtonState();
}

class _TripleActionButtonState extends State<TripleActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isLongPressTriggered = false;

  // 三连动画控制器
  late AnimationController _tripleController;
  late Animation<double> _bounce1;
  late Animation<double> _bounce2;
  late Animation<double> _bounce3;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    // 三连弹跳动画
    _tripleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _bounce1 = _createBounceAnimation(0.0, 0.33);
    _bounce2 = _createBounceAnimation(0.33, 0.66);
    _bounce3 = _createBounceAnimation(0.66, 1.0);
  }

  /// 创建单次弹跳动画
  Animation<double> _createBounceAnimation(double start, double end) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.7, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _tripleController,
        curve: Interval(start, end, curve: Curves.linear),
      ),
    );
  }

  void _onTapDown(TapDownDetails details) {
    _isLongPressTriggered = false;
    _pressController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (!_isLongPressTriggered) {
      // 普通点击
      widget.onTap();
    }
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  void _onLongPress() {
    _isLongPressTriggered = true;
    _pressController.reverse();

    // 执行三连动画
    _tripleController.forward(from: 0);

    // 三连触觉反馈（咔哒咔哒咔哒）
    HapticService.to.tripleAction();

    // 触发回调
    widget.onTripleAction();
  }

  @override
  void dispose() {
    _pressController.dispose();
    _tripleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: _onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressController, _tripleController]),
        builder: (context, child) {
          double scale = _scaleAnimation.value;

          // 叠加三连动画效果
          if (_tripleController.isAnimating || _tripleController.isCompleted) {
            final tripleScale =
                _bounce1.value * _bounce2.value * _bounce3.value;
            scale *= tripleScale;
          }

          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
