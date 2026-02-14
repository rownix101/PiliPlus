import 'package:flutter/material.dart';
import 'package:PiliPro/services/haptic_service.dart';

/// 智能刷新指示器
/// 在拉动达到临界点时触发触觉反馈
/// 刷新成功或失败后提供相应的触觉反馈
class SmartRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerDistance;
  final Color? indicatorColor;
  final Widget? indicator;

  const SmartRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 100,
    this.indicatorColor,
    this.indicator,
  });

  @override
  State<SmartRefreshIndicator> createState() => _SmartRefreshIndicatorState();
}

class _SmartRefreshIndicatorState extends State<SmartRefreshIndicator> {
  bool _hasTriggeredHaptic = false;
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);

    try {
      await widget.onRefresh();
      // 刷新成功触觉
      HapticService.to.refreshSuccess();
    } catch (e) {
      // 刷新失败触觉（三次微振）
      HapticService.to.feedback(HapticType.error);
    } finally {
      setState(() => _isRefreshing = false);
      _hasTriggeredHaptic = false;
    }
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      final distance = notification.overscroll.abs();

      // 到达临界点且未触发过触觉
      if (distance >= widget.triggerDistance &&
          !_hasTriggeredHaptic &&
          !_isRefreshing) {
        HapticService.to.refreshTriggerPoint();
        _hasTriggeredHaptic = true;
      }

      // 重置状态（当拉取距离回落到一定程度）
      if (distance < widget.triggerDistance * 0.5) {
        _hasTriggeredHaptic = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        displacement: widget.triggerDistance,
        color: widget.indicatorColor ?? theme.primaryColor,
        child: widget.child,
      ),
    );
  }
}

/// 带进度指示的刷新组件
class ProgressRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerDistance;

  const ProgressRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerDistance = 100,
  });

  @override
  State<ProgressRefreshIndicator> createState() =>
      _ProgressRefreshIndicatorState();
}

class _ProgressRefreshIndicatorState extends State<ProgressRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  bool _hasTriggeredHaptic = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      final distance = notification.overscroll.abs();
      final progress = (distance / widget.triggerDistance).clamp(0.0, 1.0);

      _progressController.value = progress;

      // 到达临界点触发触觉
      if (progress >= 1.0 && !_hasTriggeredHaptic) {
        HapticService.to.refreshTriggerPoint();
        _hasTriggeredHaptic = true;
      }

      if (progress < 0.5) {
        _hasTriggeredHaptic = false;
      }
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await widget.onRefresh();
      HapticService.to.refreshSuccess();
    } catch (e) {
      HapticService.to.feedback(HapticType.error);
    } finally {
      _hasTriggeredHaptic = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScrollNotification(notification);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        displacement: widget.triggerDistance,
        child: widget.child,
      ),
    );
  }
}
