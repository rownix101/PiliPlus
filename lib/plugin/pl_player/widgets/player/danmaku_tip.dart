import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const double danmakuTipTriangleHeight = 5.6;

class DanmakuTip extends SingleChildRenderObjectWidget {
  const DanmakuTip({
    super.key,
    this.offset = 0,
    super.child,
  });

  final double offset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderDanmakuTip(offset: offset);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDanmakuTip renderObject,
  ) {
    renderObject.offset = offset;
  }
}

class RenderDanmakuTip extends RenderProxyBox {
  RenderDanmakuTip({
    required double offset,
  }) : _offset = offset;

  double _offset;
  double get offset => _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()
      ..color = const Color(0xB3000000)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0x7EFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    final radius = size.height / 2;
    const triangleBase = danmakuTipTriangleHeight * 2 / 3;

    final triangleCenterX = (size.width / 2 + _offset).clamp(
      radius + triangleBase,
      size.width - radius - triangleBase,
    );
    final path = Path()
      // triangle (exceed)
      ..moveTo(triangleCenterX - triangleBase, 0)
      ..lineTo(triangleCenterX, -danmakuTipTriangleHeight)
      ..lineTo(triangleCenterX + triangleBase, 0)
      // top
      ..lineTo(size.width - radius, 0)
      // right
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: Radius.circular(radius),
      )
      // bottom
      ..lineTo(radius, size.height)
      // left
      ..arcToPoint(
        Offset(radius, 0),
        radius: Radius.circular(radius),
      )
      ..close();

    context.canvas
      ..drawPath(path, paint)
      ..drawPath(path, strokePaint);

    super.paint(context, offset);
  }

  @override
  bool get isRepaintBoundary => true;
}
