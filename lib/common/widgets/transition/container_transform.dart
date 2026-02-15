import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 容器变换过渡动画
///
/// 实现 Material Design 的容器变换效果：
/// 一个卡片/按钮平滑展开为完整页面，返回时页面缩回原始元素
///
/// 与简单的 Hero 动画不同，容器变换是整个容器 bounds 在变形，
/// 同时内容交叉淡入淡出，圆角和阴影跟随进度插值

// ============================================================
// 0. 全局容器变换辅助 — 搭配 PageUtils / Get.toNamed 使用
// ============================================================

/// 源容器位置信息
class ContainerTransformSource {
  const ContainerTransformSource({
    required this.rect,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Rect rect;
  final BorderRadius borderRadius;
}

/// 容器变换辅助单例
///
/// 使用流程：
/// 1. 在卡片的 onTap 中调用 [setSource] 记下当前位置
/// 2. 随后调用 PageUtils.toVideoPage / toLiveRoom 等
/// 3. PageUtils 内部检测到源位置后，使用 ContainerTransformRoute
/// 4. 源位置在消费后自动清除
///
/// ```dart
/// // 视频卡片
/// InkWell(
///   onTap: () {
///     ContainerTransformHelper.setSourceFromContext(context);
///     PageUtils.toVideoPage(bvid: bvid, cid: cid, ...);
///   },
///   child: ...
/// )
/// ```
class ContainerTransformHelper {
  ContainerTransformHelper._();

  static ContainerTransformSource? _pendingSource;
  
  /// 防抖时间戳，防止快速连续点击
  static DateTime? _lastSetTime;
  static const _debounceDuration = Duration(milliseconds: 300);
  
  /// 动画是否正在进行中
  static bool _isAnimating = false;

  /// 从 BuildContext 获取源容器的屏幕位置并暂存
  /// 
  /// 带有防抖机制：300ms 内多次调用只保留第一次
  static void setSourceFromContext(
    BuildContext context, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    // 如果动画正在进行中，忽略新的设置请求
    if (_isAnimating) return;
    
    // 防抖检查：300ms 内多次调用只保留第一次
    final now = DateTime.now();
    if (_lastSetTime != null && 
        now.difference(_lastSetTime!) < _debounceDuration) {
      return;
    }
    _lastSetTime = now;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      _pendingSource = ContainerTransformSource(
        rect: offset & renderBox.size,
        borderRadius: borderRadius,
      );
    }
  }

  /// 从 GlobalKey 获取源容器的屏幕位置并暂存
  /// 
  /// 带有防抖机制：300ms 内多次调用只保留第一次
  static void setSourceFromKey(
    GlobalKey key, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    // 如果动画正在进行中，忽略新的设置请求
    if (_isAnimating) return;
    
    // 防抖检查
    final now = DateTime.now();
    if (_lastSetTime != null && 
        now.difference(_lastSetTime!) < _debounceDuration) {
      return;
    }
    _lastSetTime = now;
    
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      _pendingSource = ContainerTransformSource(
        rect: offset & renderBox.size,
        borderRadius: borderRadius,
      );
    }
  }

  /// 直接设置源矩形
  /// 
  /// 带有防抖机制：300ms 内多次调用只保留第一次
  static void setSourceRect(
    Rect rect, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    // 如果动画正在进行中，忽略新的设置请求
    if (_isAnimating) return;
    
    // 防抖检查
    final now = DateTime.now();
    if (_lastSetTime != null && 
        now.difference(_lastSetTime!) < _debounceDuration) {
      return;
    }
    _lastSetTime = now;
    
    _pendingSource = ContainerTransformSource(
      rect: rect,
      borderRadius: borderRadius,
    );
  }

  /// 消费暂存的源位置（取出后自动清除）
  static ContainerTransformSource? consumeSource() {
    final source = _pendingSource;
    _pendingSource = null;
    // 标记动画开始
    if (source != null) {
      _isAnimating = true;
    }
    return source;
  }
  
  /// 标记动画结束，允许新的动画开始
  static void markAnimationComplete() {
    _isAnimating = false;
    _lastSetTime = null;
  }

  /// 是否有暂存的源位置
  static bool get hasSource => _pendingSource != null;

  /// 清除暂存
  static void clear() {
    _pendingSource = null;
    _isAnimating = false;
    _lastSetTime = null;
  }
}

// ============================================================
// 1. 命令式 API
// ============================================================

/// 打开容器变换过渡
///
/// 通过 [sourceKey] 获取源容器的屏幕位置，然后将其展开为全屏页面。
///
/// ```dart
/// openContainerTransform(
///   context: context,
///   sourceKey: _cardKey,
///   pageBuilder: (context) => VideoDetailPage(bvid: bvid),
/// );
/// ```
Future<T?> openContainerTransform<T>({
  required BuildContext context,
  required GlobalKey sourceKey,
  required WidgetBuilder pageBuilder,
  WidgetBuilder? sourceBuilder,
  BorderRadius closedBorderRadius = const BorderRadius.all(Radius.circular(12)),
  double closedElevation = 1.0,
  double openElevation = 0.0,
  Color? closedColor,
  Color? scrimColor,
  Duration transitionDuration = const Duration(milliseconds: 400),
  Curve curve = Curves.fastOutSlowIn,
  bool useRootNavigator = false,
}) {
  // 获取源容器的屏幕坐标和尺寸
  final renderBox = sourceKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null || !renderBox.hasSize) {
    // fallback：如果无法获取源容器信息，使用普通 push
    return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
      MaterialPageRoute(builder: pageBuilder),
    );
  }

  final sourceOffset = renderBox.localToGlobal(Offset.zero);
  final sourceSize = renderBox.size;
  final sourceRect = sourceOffset & sourceSize;

  return Navigator.of(context, rootNavigator: useRootNavigator).push<T>(
    ContainerTransformRoute<T>(
      sourceRect: sourceRect,
      pageBuilder: pageBuilder,
      sourceBuilder: sourceBuilder,
      closedBorderRadius: closedBorderRadius,
      closedElevation: closedElevation,
      openElevation: openElevation,
      closedColor: closedColor,
      scrimColor: scrimColor,
      transitionDuration: transitionDuration,
      curve: curve,
    ),
  );
}

// ============================================================
// 2. Widget 式 API
// ============================================================

/// 容器变换包装盒
///
/// 包裹源内容（卡片），点击时展开为目标页面。
///
/// ```dart
/// ContainerTransformBox(
///   closedBuilder: (context, openContainer) {
///     return VideoCardContent(onTap: openContainer);
///   },
///   openBuilder: (context, closeContainer) {
///     return VideoDetailPage(bvid: bvid);
///   },
/// )
/// ```
class ContainerTransformBox extends StatefulWidget {
  const ContainerTransformBox({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    this.closedBorderRadius = const BorderRadius.all(Radius.circular(12)),
    this.closedElevation = 1.0,
    this.openElevation = 0.0,
    this.closedColor,
    this.scrimColor,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.curve = Curves.fastOutSlowIn,
    this.onClosed,
    this.useRootNavigator = false,
  });

  /// 构建关闭状态的内容（卡片）
  /// [openContainer] 回调用于触发展开
  final Widget Function(BuildContext context, VoidCallback openContainer)
  closedBuilder;

  /// 构建打开状态的内容（页面）
  /// [closeContainer] 回调用于关闭返回
  final Widget Function(BuildContext context, VoidCallback closeContainer)
  openBuilder;

  /// 关闭状态的圆角
  final BorderRadius closedBorderRadius;

  /// 关闭状态的阴影高度
  final double closedElevation;

  /// 打开状态的阴影高度
  final double openElevation;

  /// 关闭状态的背景色
  final Color? closedColor;

  /// 遮罩颜色
  final Color? scrimColor;

  /// 过渡动画持续时间
  final Duration transitionDuration;

  /// 动画曲线
  final Curve curve;

  /// 容器关闭时的回调
  final ValueChanged<dynamic>? onClosed;

  /// 是否使用根 Navigator
  final bool useRootNavigator;

  @override
  State<ContainerTransformBox> createState() => _ContainerTransformBoxState();
}

class _ContainerTransformBoxState extends State<ContainerTransformBox> {
  final GlobalKey _key = GlobalKey();

  Future<void> _openContainer() async {
    final result = await openContainerTransform(
      context: context,
      sourceKey: _key,
      pageBuilder: (context) => widget.openBuilder(
        context,
        () => Navigator.of(context).pop(),
      ),
      sourceBuilder: (context) => widget.closedBuilder(context, () {}),
      closedBorderRadius: widget.closedBorderRadius,
      closedElevation: widget.closedElevation,
      openElevation: widget.openElevation,
      closedColor: widget.closedColor,
      scrimColor: widget.scrimColor,
      transitionDuration: widget.transitionDuration,
      curve: widget.curve,
      useRootNavigator: widget.useRootNavigator,
    );
    widget.onClosed?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: _key,
      elevation: widget.closedElevation,
      borderRadius: widget.closedBorderRadius,
      clipBehavior: Clip.antiAlias,
      color: widget.closedColor ?? Theme.of(context).cardColor,
      child: widget.closedBuilder(context, _openContainer),
    );
  }
}

// ============================================================
// 3. 路由实现
// ============================================================

/// 容器变换路由
///
/// 自定义 [PageRoute]，在页面切换时渲染从源 bounds 到全屏的变形动画
class ContainerTransformRoute<T> extends PageRoute<T> {
  ContainerTransformRoute({
    required this.sourceRect,
    required this.pageBuilder,
    this.sourceBuilder,
    this.closedBorderRadius = const BorderRadius.all(Radius.circular(12)),
    this.closedElevation = 1.0,
    this.openElevation = 0.0,
    this.closedColor,
    this.scrimColor,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.curve = Curves.fastOutSlowIn,
    super.settings,
  });

  /// 源容器在屏幕上的位置和大小
  final Rect sourceRect;

  /// 目标页面构建器
  final WidgetBuilder pageBuilder;

  /// 源内容构建器（用于动画过程中显示源内容的快照）
  final WidgetBuilder? sourceBuilder;

  /// 关闭状态的圆角
  final BorderRadius closedBorderRadius;

  /// 关闭状态的阴影高度
  final double closedElevation;

  /// 打开状态的阴影高度
  final double openElevation;

  /// 关闭状态的背景色
  final Color? closedColor;

  /// 遮罩颜色
  final Color? scrimColor;

  /// 动画曲线
  final Curve curve;

  @override
  final Duration transitionDuration;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return pageBuilder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _ContainerTransformTransition(
      animation: animation,
      sourceRect: sourceRect,
      sourceBuilder: sourceBuilder,
      closedBorderRadius: closedBorderRadius,
      closedElevation: closedElevation,
      openElevation: openElevation,
      closedColor: closedColor,
      scrimColor: scrimColor,
      curve: curve,
      child: child,
    );
  }
}

// ============================================================
// 4. 变形动画 Widget
// ============================================================

class _ContainerTransformTransition extends StatelessWidget {
  const _ContainerTransformTransition({
    required this.animation,
    required this.sourceRect,
    required this.child,
    this.sourceBuilder,
    this.closedBorderRadius = const BorderRadius.all(Radius.circular(12)),
    this.closedElevation = 1.0,
    this.openElevation = 0.0,
    this.closedColor,
    this.scrimColor,
    this.curve = Curves.fastOutSlowIn,
  });

  final Animation<double> animation;
  final Rect sourceRect;
  final Widget child;
  final WidgetBuilder? sourceBuilder;
  final BorderRadius closedBorderRadius;
  final double closedElevation;
  final double openElevation;
  final Color? closedColor;
  final Color? scrimColor;
  final Curve curve;

  // 源内容开始淡出的阈值（动画值 0 ~ fadeOutEnd）
  static const double _fadeOutEnd = 0.3;
  // 目标内容开始淡入的阈值（动画值 fadeInStart ~ 1.0）
  static const double _fadeInStart = 0.25;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final fullScreenRect = Offset.zero & screenSize;
    final effectiveScrimColor =
        scrimColor ?? Colors.black.withValues(alpha: 0.4);
    final effectiveClosedColor = closedColor ?? Theme.of(context).cardColor;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double t = animation.value;
        final double curvedT = curve.transform(t);

        // 插值当前 rect
        final currentRect = Rect.lerp(sourceRect, fullScreenRect, curvedT)!;

        // 插值圆角
        final currentRadius = BorderRadius.lerp(
          closedBorderRadius,
          BorderRadius.zero,
          curvedT,
        )!;

        // 插值阴影
        final currentElevation = lerpDouble(
          closedElevation,
          openElevation,
          curvedT,
        )!;

        // 插值背景色
        final currentColor = Color.lerp(
          effectiveClosedColor,
          Theme.of(context).scaffoldBackgroundColor,
          curvedT,
        )!;

        // 源内容淡出进度 (0 ~ fadeOutEnd 区间 → 1.0 ~ 0.0)
        final double sourceOpacity = t <= _fadeOutEnd
            ? 1.0 - (t / _fadeOutEnd)
            : 0.0;

        // 目标内容淡入进度 (fadeInStart ~ 1.0 区间 → 0.0 ~ 1.0)
        final double destOpacity = t >= _fadeInStart
            ? ((t - _fadeInStart) / (1.0 - _fadeInStart)).clamp(0.0, 1.0)
            : 0.0;

        // 遮罩透明度
        final double scrimOpacity = curvedT;

        return Stack(
          children: [
            // 半透明遮罩
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: effectiveScrimColor.withValues(
                      alpha: effectiveScrimColor.a * scrimOpacity,
                    ),
                  ),
                ),
              ),
            ),

            // 变形容器
            Positioned(
              left: currentRect.left,
              top: currentRect.top,
              width: currentRect.width,
              height: currentRect.height,
              child: RepaintBoundary(
                child: PhysicalModel(
                  elevation: currentElevation,
                  borderRadius: currentRadius,
                  color: currentColor,
                  shadowColor: Colors.black54,
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 目标内容 (全屏页面)
                      if (destOpacity > 0)
                        Opacity(
                          opacity: destOpacity,
                          child: RepaintBoundary(
                            child: child,
                          ),
                        ),

                      // 源内容 (卡片快照)
                      if (sourceOpacity > 0 && sourceBuilder != null)
                        Opacity(
                          opacity: sourceOpacity,
                          child: RepaintBoundary(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: sourceRect.width,
                                height: sourceRect.height,
                                child: sourceBuilder!(context),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
