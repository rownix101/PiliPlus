import 'package:flutter/material.dart';

/// 共享元素过渡动画类型
enum SharedElementTransitionType {
  /// 缩放过渡
  scale,
  /// 淡入淡出
  fade,
  /// 缩放 + 淡入淡出
  scaleFade,
}

/// 共享元素过渡组件
/// 
/// 用于实现从列表页到详情页的无缝过渡动画
/// 保持 ScaleType 一致，避免拉伸变形
class SharedElementTransition extends StatelessWidget {
  const SharedElementTransition({
    super.key,
    required this.tag,
    required this.child,
    this.transitionType = SharedElementTransitionType.scaleFade,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeInOutCubic,
    this.placeholderBuilder,
  });

  /// Hero 动画的唯一标识
  final String tag;
  
  /// 子组件
  final Widget child;
  
  /// 过渡动画类型
  final SharedElementTransitionType transitionType;
  
  /// 动画持续时间
  final Duration duration;
  
  /// 动画曲线
  final Curve curve;
  
  /// 占位图构建器
  final WidgetBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      placeholderBuilder: placeholderBuilder != null 
          ? (context, size, child) => placeholderBuilder!(context) 
          : null,
      flightShuttleBuilder: _flightShuttleBuilder,
      child: child,
    );
  }

  /// 构建飞行过程中的 Shuttle 组件
  Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final Widget hero = fromHeroContext.widget;
    
    switch (transitionType) {
      case SharedElementTransitionType.scale:
        return _buildScaleTransition(animation, hero);
      case SharedElementTransitionType.fade:
        return _buildFadeTransition(animation, hero);
      case SharedElementTransitionType.scaleFade:
        return _buildScaleFadeTransition(animation, hero);
    }
  }

  /// 缩放过渡
  Widget _buildScaleTransition(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _calculateScale(animation.value),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: child,
    );
  }

  /// 淡入淡出过渡
  Widget _buildFadeTransition(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation.drive(
        Tween<double>(begin: 0.8, end: 1.0).chain(
          CurveTween(curve: curve),
        ),
      ),
      child: child,
    );
  }

  /// 缩放 + 淡入淡出过渡
  Widget _buildScaleFadeTransition(Animation<double> animation, Widget child) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double value = animation.value;
        return Transform.scale(
          scale: _calculateScale(value),
          alignment: Alignment.center,
          child: Opacity(
            opacity: 0.7 + (value * 0.3),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// 计算缩放值，添加阻尼感
  double _calculateScale(double value) {
    // 使用弹性曲线，让动画更有重量感
    final curvedValue = Curves.easeInOutCubic.transform(value);
    return 0.95 + (curvedValue * 0.05);
  }
}

/// 共享元素图片组件
/// 
/// 专门用于视频封面图的共享元素过渡
class SharedElementImage extends StatelessWidget {
  const SharedElementImage({
    super.key,
    required this.tag,
    required this.src,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final String tag;
  final String? src;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    Widget child = _buildImage();
    
    if (borderRadius != null) {
      child = ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return SharedElementTransition(
      tag: tag,
      transitionType: SharedElementTransitionType.scaleFade,
      child: child,
    );
  }

  Widget _buildImage() {
    if (src == null || src!.isEmpty) {
      return placeholder ?? _defaultPlaceholder();
    }

    return Image.network(
      src!,
      width: width,
      height: height,
      fit: fit,
      alignment: Alignment.center,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _defaultPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        return placeholder ?? _defaultPlaceholder();
      },
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }
}

/// 页面转场动画构建器
class SharedElementPageRoute<T> extends PageRouteBuilder<T> {
  SharedElementPageRoute({
    required super.pageBuilder,
    super.settings,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeInOutCubic,
  }) : super(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    opaque: true,
    barrierColor: null,
    barrierDismissible: false,
    barrierLabel: null,
    maintainState: true,
    fullscreenDialog: false,
    allowSnapshotting: true,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(
          Tween<double>(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: curve),
          ),
        ),
        child: child,
      );
    },
  );

  final Duration duration;
  final Curve curve;
}
