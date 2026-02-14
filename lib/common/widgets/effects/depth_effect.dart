import 'dart:ui';
import 'package:flutter/material.dart';

/// 深度效果组件
/// 当底部面板弹出时，背景页面轻微向后缩放并增加高斯模糊
/// 阴影随高度动态变化，营造"升起"的视觉错觉
class DepthEffect extends StatelessWidget {
  final Widget child;
  final double elevation;
  final bool enableBlur;
  final bool enableScale;
  final Widget? background;
  final double blurSigma;
  final double scaleFactor;

  const DepthEffect({
    super.key,
    required this.child,
    this.elevation = 0,
    this.enableBlur = true,
    this.enableScale = true,
    this.background,
    this.blurSigma = 3.0,
    this.scaleFactor = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景层（带缩放和模糊）
        if (background != null)
          AnimatedScale(
            scale: enableScale ? 1.0 - (elevation * scaleFactor) : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: enableBlur && elevation > 0
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: elevation * blurSigma,
                      sigmaY: elevation * blurSigma,
                    ),
                    child: background,
                  )
                : background,
          ),

        // 前景层（带动态阴影）
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2 * elevation.clamp(0.0, 1.0)),
                blurRadius: elevation * 20,
                spreadRadius: elevation * 4,
                offset: Offset(0, elevation * 8),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

/// 渐进式深度效果包装器
/// 根据滚动位置自动计算深度
class ProgressiveDepth extends StatefulWidget {
  final Widget child;
  final Widget background;
  final ScrollController? scrollController;
  final double maxElevation;
  final double triggerOffset;

  const ProgressiveDepth({
    super.key,
    required this.child,
    required this.background,
    this.scrollController,
    this.maxElevation = 1.0,
    this.triggerOffset = 100,
  });

  @override
  State<ProgressiveDepth> createState() => _ProgressiveDepthState();
}

class _ProgressiveDepthState extends State<ProgressiveDepth> {
  double _elevation = 0;
  ScrollController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollController ?? ScrollController();
    _controller?.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _controller?.offset ?? 0;
    final newElevation = (offset / widget.triggerOffset).clamp(0.0, widget.maxElevation);

    if (newElevation != _elevation) {
      setState(() {
        _elevation = newElevation;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DepthEffect(
      elevation: _elevation,
      background: widget.background,
      child: widget.child,
    );
  }
}

/// 模态深度效果
/// 用于底部弹出面板等场景
class ModalDepthEffect extends StatelessWidget {
  final Widget child;
  final bool isOpen;
  final Widget? background;
  final VoidCallback? onTapBackground;

  const ModalDepthEffect({
    super.key,
    required this.child,
    this.isOpen = false,
    this.background,
    this.onTapBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景层
        if (background != null)
          GestureDetector(
            onTap: onTapBackground,
            child: AnimatedScale(
              scale: isOpen ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: isOpen ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: isOpen
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: background,
                      )
                    : background,
              ),
            ),
          ),

        // 前景内容
        AnimatedAlign(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            offset: isOpen ? Offset.zero : const Offset(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: isOpen
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                          offset: const Offset(0, -5),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
