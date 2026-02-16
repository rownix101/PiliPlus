import 'dart:ui' as ui;

import 'package:PiliPro/common/constants.dart';
import 'package:flutter/services.dart';
import 'package:PiliPro/common/widgets/cropped_image.dart';
import 'package:PiliPro/utils/image_utils.dart';
import 'package:PiliPro/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoShotImage extends StatefulWidget {
  const VideoShotImage({
    super.key,
    required this.imageCache,
    required this.url,
    required this.x,
    required this.y,
    required this.imgXSize,
    required this.imgYSize,
    required this.height,
    required this.onSetSize,
    required this.isMounted,
  });

  final Map<String, ui.Image?> imageCache;
  final String url;
  final int x;
  final int y;
  final double imgXSize;
  final double imgYSize;
  final double height;
  final Function(double imgXSize, double imgYSize) onSetSize;
  final ValueGetter<bool> isMounted;

  @override
  State<VideoShotImage> createState() => _VideoShotImageState();
}

Future<ui.Image?> getVideoShotImg(String url) async {
  final cacheManager = DefaultCacheManager();
  final cacheKey = Utils.getFileName(url, fileExt: false);
  try {
    final fileInfo = await cacheManager.getSingleFile(
      ImageUtils.safeThumbnailUrl(url),
      key: cacheKey,
      headers: Constants.baseHeaders,
    );
    return _loadImg(fileInfo.path);
  } catch (_) {
    return null;
  }
}

Future<ui.Image?> _loadImg(String path) async {
  final codec = await ui.instantiateImageCodecFromBuffer(
    await ImmutableBuffer.fromFilePath(path),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

class _VideoShotImageState extends State<VideoShotImage> {
  late Size _size;
  late Rect _srcRect;
  late Rect _dstRect;
  late RRect _rrect;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _initSize();
    _loadImage();
  }

  void _initSizeIfNeeded() {
    if (_size.width.isNaN) {
      _initSize();
    }
  }

  void _initSize() {
    if (widget.imgXSize == 0) {
      if (_image != null) {
        final imgXSize = _image!.width / 10;
        final imgYSize = _image!.height / 10;
        final height = widget.height;
        final width = height * imgXSize / imgYSize;
        _setRect(width, height);
        _setSrcRect(imgXSize, imgYSize);
        widget.onSetSize(imgXSize, imgYSize);
      } else {
        _setRect(double.nan, double.nan);
        _setSrcRect(widget.imgXSize, widget.imgYSize);
      }
    } else {
      final height = widget.height;
      final width = height * widget.imgXSize / widget.imgYSize;
      _setRect(width, height);
      _setSrcRect(widget.imgXSize, widget.imgYSize);
    }
  }

  void _setRect(double width, double height) {
    _size = Size(width, height);
    _dstRect = Rect.fromLTRB(0, 0, width, height);
    _rrect = RRect.fromRectAndRadius(_dstRect, const Radius.circular(10));
  }

  void _setSrcRect(double imgXSize, double imgYSize) {
    _srcRect = Rect.fromLTWH(
      widget.x * imgXSize,
      widget.y * imgYSize,
      imgXSize,
      imgYSize,
    );
  }

  void _loadImage() {
    final url = widget.url;
    _image = widget.imageCache[url];
    if (_image != null) {
      _initSizeIfNeeded();
    } else if (!widget.imageCache.containsKey(url)) {
      widget.imageCache[url] = null;
      getVideoShotImg(url).then((image) {
        if (image != null) {
          if (widget.isMounted()) {
            widget.imageCache[url] = image;
          }
          if (mounted) {
            _image = image;
            _initSizeIfNeeded();
            setState(() {});
          }
        } else {
          widget.imageCache.remove(url);
        }
      });
    }
  }

  @override
  void didUpdateWidget(VideoShotImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
    if (oldWidget.x != widget.x || oldWidget.y != widget.y) {
      _setSrcRect(widget.imgXSize, widget.imgYSize);
    }
  }

  late final _imgPaint = Paint()..filterQuality = FilterQuality.medium;
  late final _borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    if (_image != null) {
      return CroppedImage(
        size: _size,
        image: _image!,
        srcRect: _srcRect,
        dstRect: _dstRect,
        rrect: _rrect,
        imgPaint: _imgPaint,
        borderPaint: _borderPaint,
      );
    }
    return const SizedBox.shrink();
  }
}
