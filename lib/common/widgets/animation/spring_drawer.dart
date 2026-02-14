import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// 弹簧抽屉组件
/// 使用物理模拟实现自然的弹簧动画效果
/// 替代默认的 showModalBottomSheet 生硬动画
class SpringDrawer extends StatefulWidget {
  final Widget child;
  final double maxHeight;
  final double minHeight;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onDismiss;
  final bool enableDrag;
  final bool showDragHandle;

  const SpringDrawer({
    super.key,
    required this.child,
    this.maxHeight = 0.9,
    this.minHeight = 0.0,
    this.backgroundColor,
    this.borderRadius,
    this.onDismiss,
    this.enableDrag = true,
    this.showDragHandle = true,
  });

  @override
  State<SpringDrawer> createState() => _SpringDrawerState();
}

class _SpringDrawerState extends State<SpringDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late SpringSimulation _springSimulation;
  double _dragStartY = 0.0;
  double _currentHeight = 0.0;

  // 弹簧物理参数
  static const double _springStiffness = 400.0;
  static const double _springDamping = 0.7;
  static const double _springMass = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 初始化弹簧模拟
    _springSimulation = SpringSimulation(
      const SpringDescription(
        mass: _springMass,
        stiffness: _springStiffness,
        damping: _springDamping,
      ),
      0.0, // 起始位置
      1.0, // 目标位置
      0.0, // 初始速度
    );

    // 启动展开动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.animateWith(_springSimulation);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
    _currentHeight = _controller.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enableDrag) return;

    final dragDelta = details.globalPosition.dy - _dragStartY;
    final screenHeight = MediaQuery.of(context).size.height;
    final dragProgress = dragDelta / (screenHeight * widget.maxHeight);

    // 添加阻力系数，让拖动有重量感
    final newValue = (_currentHeight - dragProgress * 0.8).clamp(0.0, 1.0);
    _controller.value = newValue;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enableDrag) return;

    final velocity = details.primaryVelocity ?? 0.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final velocityPerSecond = velocity / screenHeight;

    // 根据当前位置和速度决定是否关闭
    if (_controller.value < 0.3 || velocityPerSecond > 1.5) {
      _close(velocityPerSecond);
    } else {
      _open(velocityPerSecond);
    }
  }

  void _open(double velocity) {
    final spring = SpringSimulation(
      const SpringDescription(
        mass: _springMass,
        stiffness: _springStiffness,
        damping: _springDamping,
      ),
      _controller.value,
      1.0,
      velocity,
    );
    _controller.animateWith(spring);
  }

  void _close(double velocity) {
    final spring = SpringSimulation(
      const SpringDescription(
        mass: _springMass,
        stiffness: _springStiffness * 1.2, // 关闭时稍微更紧的弹簧
        damping: _springDamping,
      ),
      _controller.value,
      0.0,
      velocity,
    );
    _controller.animateWith(spring).then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDrawerHeight = screenHeight * widget.maxHeight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        final drawerHeight = maxDrawerHeight * progress;

        return Stack(
          children: [
            // 背景遮罩
            GestureDetector(
              onTap: () => _close(0.0),
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.5 * progress,
                ),
              ),
            ),
            // 抽屉内容
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: drawerHeight,
              child: GestureDetector(
                onVerticalDragStart: _onDragStart,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? theme.cardColor,
                    borderRadius: widget.borderRadius ??
                        const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // 拖动指示条
                      if (widget.showDragHandle)
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 便捷的弹簧抽屉显示方法
Future<T?> showSpringDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxHeight = 0.9,
  double minHeight = 0.0,
  Color? backgroundColor,
  BorderRadius? borderRadius,
  bool enableDrag = true,
  bool showDragHandle = true,
  bool useRootNavigator = false,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SpringDrawer(
          maxHeight: maxHeight,
          minHeight: minHeight,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          enableDrag: enableDrag,
          showDragHandle: showDragHandle,
          onDismiss: () => Navigator.of(context).pop(),
          child: Builder(builder: builder),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 使用 FadeTransition 让背景平滑过渡
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: Duration.zero, // 由 SpringDrawer 自己处理动画
    ),
  );
}

/// 弹簧评论抽屉
/// 专为评论区设计的弹簧效果抽屉，带有默认配置
class SpringCommentDrawer extends StatelessWidget {
  final Widget child;
  final String? title;
  final VoidCallback? onDismiss;

  const SpringCommentDrawer({
    super.key,
    required this.child,
    this.title,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SpringDrawer(
      maxHeight: 0.85,
      showDragHandle: true,
      onDismiss: onDismiss,
      child: Column(
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
