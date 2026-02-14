import 'dart:math' as dart_math;

import 'package:PiliPro/common/widgets/flutter/page/tabs.dart';
import 'package:PiliPro/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPro/utils/storage_pref.dart';
import 'package:flutter/material.dart' hide TabBarView;
import 'package:flutter/physics.dart';

Widget videoTabBarView({
  required List<Widget> children,
  TabController? controller,
}) => TabBarView<CustomHorizontalDragGestureRecognizer>(
  controller: controller,
  physics: const CustomTabBarViewScrollPhysics(parent: ClampingScrollPhysics()),
  horizontalDragGestureRecognizer: CustomHorizontalDragGestureRecognizer.new,
  children: children,
);

Widget tabBarView({
  required List<Widget> children,
  TabController? controller,
}) => TabBarView<CustomHorizontalDragGestureRecognizer>(
  physics: const CustomTabBarViewScrollPhysics(),
  controller: controller,
  horizontalDragGestureRecognizer: CustomHorizontalDragGestureRecognizer.new,
  children: children,
);

SpringDescription _customSpringDescription() {
  final List<double> springDescription = Pref.springDescription;
  return SpringDescription(
    mass: springDescription[0],
    stiffness: springDescription[1],
    damping: springDescription[2],
  );
}

class CustomTabBarViewScrollPhysics extends ScrollPhysics {
  const CustomTabBarViewScrollPhysics({super.parent});

  @override
  CustomTabBarViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomTabBarViewScrollPhysics(parent: buildParent(ancestor));
  }

  static final _springDescription = _customSpringDescription();

  @override
  SpringDescription get spring => _springDescription;
}

mixin ReloadMixin {
  late bool reload = false;
}

class ReloadScrollPhysics extends AlwaysScrollableScrollPhysics {
  const ReloadScrollPhysics({super.parent, required this.controller});

  final ReloadMixin controller;

  @override
  ReloadScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReloadScrollPhysics(
      parent: buildParent(ancestor),
      controller: controller,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (controller.reload) {
      controller.reload = false;
      return 0;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

/// 评论区滚动物理效果
/// 实现先快后慢的滚动效果，比普通滚动更快衰减
class CommentScrollPhysics extends ScrollPhysics {
  const CommentScrollPhysics({super.parent});

  @override
  CommentScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CommentScrollPhysics(parent: buildParent(ancestor));
  }

  /// 摩擦系数，值越大减速越快
  /// 默认 BouncingScrollPhysics 使用 0.3，ClampingScrollPhysics 使用 0.5
  /// 这里使用 0.65 使滚动更快减速，实现先快后慢的效果
  double get frictionFactor => 0.65;

  /// 最小滑行速度，低于此值立即停止
  double get minFlingVelocity => 50.0;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final Tolerance tolerance = this.tolerance;

    // 速度太小，不创建滑行
    if (velocity.abs() < tolerance.velocity) return null;

    // 创建摩擦减速模拟
    return _CommentFrictionSimulation(
      friction: frictionFactor,
      position: position.pixels,
      velocity: velocity,
      tolerance: tolerance,
      minVelocity: minFlingVelocity,
    );
  }
}

/// 自定义摩擦减速模拟
/// 实现更快的速度衰减
class _CommentFrictionSimulation extends Simulation {
  _CommentFrictionSimulation({
    required this.friction,
    required double position,
    required double velocity,
    required this.tolerance,
    required this.minVelocity,
  })  : _position = position,
        _velocity = velocity;

  /// 摩擦系数
  final double friction;

  /// 当前位置
  double _position;

  /// 当前速度
  double _velocity;

  /// 容差
  final Tolerance tolerance;

  /// 最小速度阈值
  final double minVelocity;

  @override
  double x(double time) {
    // 使用指数衰减模型：v(t) = v0 * e^(-friction * t)
    // 积分得到位置：x(t) = x0 + v0 * (1 - e^(-friction * t)) / friction
    final decay = dart_math.exp(-friction * time);
    return _position + _velocity * (1 - decay) / friction;
  }

  @override
  double dx(double time) {
    // 速度随时间指数衰减
    final decay = dart_math.exp(-friction * time);
    return _velocity * decay;
  }

  @override
  bool isDone(double time) {
    // 当速度低于阈值或位置几乎不变时结束
    final currentVelocity = dx(time).abs();
    return currentVelocity < tolerance.velocity ||
        currentVelocity < minVelocity;
  }
}
