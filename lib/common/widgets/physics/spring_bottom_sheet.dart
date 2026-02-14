import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 弹簧物理底部面板
/// 使用弹簧物理模型（质量、刚度、阻尼）实现自然的过冲和回弹效果
class SpringBottomSheet extends StatefulWidget {
  final Widget child;
  final double minHeight;
  final double maxHeight;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;
  final bool snap;
  final List<double>? snapSizes;
  final SpringDescription? springDescription;
  final VoidCallback? onClose;
  final VoidCallback? onOpen;

  const SpringBottomSheet({
    super.key,
    required this.child,
    this.minHeight = 100,
    this.maxHeight = 600,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.95,
    this.expand = false,
    this.snap = false,
    this.snapSizes,
    this.springDescription,
    this.onClose,
    this.onOpen,
  });

  @override
  State<SpringBottomSheet> createState() => _SpringBottomSheetState();
}

class _SpringBottomSheetState extends State<SpringBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late SpringSimulation _springSimulation;

  // 默认弹簧物理参数
  late final SpringDescription _spring = widget.springDescription ??
      const SpringDescription(
        mass: 1.0, // 质量
        stiffness: 180.0, // 刚度
        damping: 25.0, // 阻尼
      );

  double _currentExtent = 0.5;
  double _minExtent = 0.25;
  double _maxExtent = 0.95;

  @override
  void initState() {
    super.initState();
    _currentExtent = widget.initialChildSize;
    _minExtent = widget.minChildSize;
    _maxExtent = widget.maxChildSize;

    _controller = AnimationController.unbounded(vsync: this);
    _controller.value = _currentExtent;

    _controller.addListener(_onAnimationUpdate);
  }

  void _onAnimationUpdate() {
    setState(() {
      _currentExtent = _controller.value.clamp(_minExtent, _maxExtent);
    });

    // 触发回调
    if (_currentExtent >= _maxExtent * 0.95 && widget.onOpen != null) {
      widget.onOpen!();
    } else if (_currentExtent <= _minExtent * 1.1 && widget.onClose != null) {
      widget.onClose!();
    }
  }

  /// 使用弹簧物理动画到目标位置
  void _animateWithSpring(double target, {double velocity = 0}) {
    _springSimulation = SpringSimulation(
      _spring,
      _controller.value,
      target.clamp(_minExtent, _maxExtent),
      velocity,
    );

    _controller.animateWith(_springSimulation);
  }

  /// 处理拖拽更新
  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta!;
    final screenHeight = MediaQuery.of(context).size.height;
    final extentDelta = -delta / screenHeight;

    setState(() {
      _currentExtent = (_currentExtent + extentDelta).clamp(
        _minExtent - 0.1, // 允许轻微过拉
        _maxExtent + 0.05,
      );
    });

    _controller.value = _currentExtent;
  }

  /// 处理拖拽结束
  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final screenHeight = MediaQuery.of(context).size.height;
    final velocityScale = velocity / screenHeight;

    double targetExtent;

    if (widget.snap && widget.snapSizes != null && widget.snapSizes!.isNotEmpty) {
      // 吸附到最近的 snap 点
      targetExtent = _getNearestSnapExtent(_currentExtent, velocityScale);
    } else {
      // 根据速度和位置决定目标
      if (velocityScale.abs() > 0.5) {
        // 快速滑动 - 根据方向展开或收起
        targetExtent = velocityScale > 0 ? _maxExtent : _minExtent;
      } else {
        // 慢速滑动 - 根据当前位置决定
        final midpoint = (_minExtent + _maxExtent) / 2;
        targetExtent = _currentExtent > midpoint ? _maxExtent : _minExtent;
      }
    }

    _animateWithSpring(targetExtent, velocity: velocityScale);
  }

  double _getNearestSnapExtent(double current, double velocity) {
    final snaps = widget.snapSizes!;

    // 考虑速度的吸附
    if (velocity.abs() > 0.3) {
      if (velocity > 0) {
        // 向上滑动 - 找下一个更大的 snap
        for (final snap in snaps) {
          if (snap > current) return snap;
        }
        return _maxExtent;
      } else {
        // 向下滑动 - 找下一个更小的 snap
        for (final snap in snaps.reversed) {
          if (snap < current) return snap;
        }
        return _minExtent;
      }
    }

    // 无速度或低速 - 找最近的 snap
    double nearest = snaps.first;
    double minDistance = (snaps.first - current).abs();

    for (final snap in snaps.skip(1)) {
      final distance = (snap - current).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearest = snap;
      }
    }

    return nearest;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onAnimationUpdate)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final currentHeight = screenHeight * _currentExtent;

    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        height: currentHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1 + (_currentExtent * 0.1)),
              blurRadius: 10 + (_currentExtent * 20),
              spreadRadius: _currentExtent * 4,
              offset: Offset(0, -_currentExtent * 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // 拖拽指示条
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 内容区域
            Expanded(
              child: widget.child,
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹簧 DraggableScrollableSheet 包装器
class SpringDraggableSheet extends StatefulWidget {
  final Widget Function(BuildContext, ScrollController) builder;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final bool expand;
  final bool snap;
  final List<double>? snapSizes;
  final SpringDescription? springDescription;

  const SpringDraggableSheet({
    super.key,
    required this.builder,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.95,
    this.expand = false,
    this.snap = false,
    this.snapSizes,
    this.springDescription,
  });

  @override
  State<SpringDraggableSheet> createState() => _SpringDraggableSheetState();
}

class _SpringDraggableSheetState extends State<SpringDraggableSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      expand: widget.expand,
      snap: widget.snap,
      snapSizes: widget.snapSizes,
      builder: widget.builder,
    );
  }
}
