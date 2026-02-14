import 'package:flutter/material.dart';
import 'package:PiliPro/services/haptic_service.dart';

/// 边界回弹列表
/// 当用户快速滚动撞到底部边缘时，配合"橡皮筋"回弹动画触发触觉反馈
class EdgeBounceList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final ScrollPhysics? physics;
  final VoidCallback? onReachBottom;
  final double velocityThreshold;
  final double bounceDistance;

  const EdgeBounceList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.physics,
    this.onReachBottom,
    this.velocityThreshold = 500,
    this.bounceDistance = 30,
  });

  @override
  State<EdgeBounceList> createState() => _EdgeBounceListState();
}

class _EdgeBounceListState extends State<EdgeBounceList>
    with SingleTickerProviderStateMixin {
  late ScrollController _controller;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _hasBounced = false;
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _controller.addListener(_onScroll);

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_bounceController);
  }

  double _lastScrollPosition = 0;
  DateTime _lastScrollTime = DateTime.now();

  void _onScroll() {
    if (!_controller.hasClients) return;

    final maxScroll = _controller.position.maxScrollExtent;
    final currentScroll = _controller.position.pixels;

    // 计算滚动速度 (pixels per second)
    final now = DateTime.now();
    final timeDelta = now.difference(_lastScrollTime).inMilliseconds;
    if (timeDelta > 0) {
      final positionDelta = currentScroll - _lastScrollPosition;
      final velocity = (positionDelta / timeDelta) * 1000; // 转换为每秒像素

      // 检测是否到达底部
      final wasAtBottom = _isAtBottom;
      _isAtBottom = currentScroll >= maxScroll - 10;

      // 快速滚动撞到底部
      if (_isAtBottom &&
          !wasAtBottom &&
          velocity.abs() > widget.velocityThreshold &&
          !_hasBounced) {
        _triggerBounce();
      }

      // 触发回调
      if (_isAtBottom && !wasAtBottom && widget.onReachBottom != null) {
        widget.onReachBottom!();
      }
    }

    _lastScrollPosition = currentScroll;
    _lastScrollTime = now;
  }

  void _triggerBounce() {
    _hasBounced = true;

    // 触觉反馈 - 沉闷短促的撞击感
    HapticService.to.edgeBounce();

    // 执行回弹动画
    _bounceController.forward(from: 0);

    // 延迟重置，防止连续触发
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _hasBounced = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _bounceController.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value * widget.bounceDistance),
          child: child,
        );
      },
      child: ListView.builder(
        controller: _controller,
        physics: widget.physics ??
            const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
        padding: widget.padding,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}

/// 边界回弹包装器
/// 可为任意可滚动组件添加边界回弹效果
class EdgeBounceWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final double velocityThreshold;

  const EdgeBounceWrapper({
    super.key,
    required this.child,
    this.controller,
    this.velocityThreshold = 500,
  });

  @override
  State<EdgeBounceWrapper> createState() => _EdgeBounceWrapperState();
}

class _EdgeBounceWrapperState extends State<EdgeBounceWrapper> {
  ScrollController? _controller;
  bool _hasBouncedTop = false;
  bool _hasBouncedBottom = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller?.addListener(_onScroll);
  }

  double _lastPosition = 0;
  DateTime _lastTime = DateTime.now();

  void _onScroll() {
    if (_controller == null || !_controller!.hasClients) return;

    final position = _controller!.position;
    final now = DateTime.now();
    final timeDelta = now.difference(_lastTime).inMilliseconds;

    if (timeDelta > 0) {
      final positionDelta = position.pixels - _lastPosition;
      final velocity = (positionDelta / timeDelta) * 1000;

      // 检测顶部回弹
      if (position.pixels <= position.minScrollExtent &&
          velocity < -widget.velocityThreshold &&
          !_hasBouncedTop) {
        _hasBouncedTop = true;
        HapticService.to.edgeBounce();
        Future.delayed(const Duration(milliseconds: 300), () {
          _hasBouncedTop = false;
        });
      }

      // 检测底部回弹
      if (position.pixels >= position.maxScrollExtent &&
          velocity > widget.velocityThreshold &&
          !_hasBouncedBottom) {
        _hasBouncedBottom = true;
        HapticService.to.edgeBounce();
        Future.delayed(const Duration(milliseconds: 300), () {
          _hasBouncedBottom = false;
        });
      }
    }

    _lastPosition = position.pixels;
    _lastTime = now;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
