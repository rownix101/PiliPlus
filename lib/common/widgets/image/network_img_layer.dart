import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    required this.src,
    required this.width,
    required this.height,
    this.type = .def,
    this.fadeOutDuration = const Duration(milliseconds: 120),
    this.fadeInDuration = const Duration(milliseconds: 120),
    this.quality = 1,
    this.borderRadius = StyleString.mdRadius,
    this.getPlaceHolder,
    this.fit = .cover,
    this.alignment = .center,
    this.cacheWidth,
  });

  final String? src;
  final double width;
  final double height;
  final ImageType type;
  final Duration fadeOutDuration;
  final Duration fadeInDuration;
  final int quality;
  final BorderRadius borderRadius;
  final ValueGetter<Widget>? getPlaceHolder;
  final BoxFit fit;
  final Alignment alignment;
  final bool? cacheWidth;

  static Color? reduceLuxColor = Pref.reduceLuxColor;
  static bool reduce = false;

  @override
  Widget build(BuildContext context) {
    final isEmote = type == ImageType.emote;
    final isAvatar = type == ImageType.avatar;
    // 一次性获取主题颜色，避免重复调用 Theme.of
    final placeholderColor = Theme.of(context)
        .colorScheme
        .onInverseSurface
        .withValues(alpha: 0.4);
    if (src?.isNotEmpty == true) {
      Widget child = _buildImage(
        context,
        isEmote: isEmote,
        isAvatar: isAvatar,
        placeholderColor: placeholderColor,
      );
      if (isEmote) {
        return child;
      } else if (isAvatar) {
        return ClipOval(child: child);
      } else {
        return ClipRRect(borderRadius: borderRadius, child: child);
      }
    } else {
      return getPlaceHolder?.call() ??
          _placeholder(
            context,
            isEmote: isEmote,
            isAvatar: isAvatar,
            placeholderColor: placeholderColor,
          );
    }
  }

  Widget _buildImage(
    BuildContext context, {
    required bool isEmote,
    required bool isAvatar,
    required Color placeholderColor,
  }) {
    int? memCacheWidth, memCacheHeight;
    if (cacheWidth ?? width <= height) {
      memCacheWidth = width.cacheSize(context);
    } else {
      memCacheHeight = height.cacheSize(context);
    }
    return CachedNetworkImage(
      imageUrl: ImageUtils.thumbnailUrl(src, quality),
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fit: fit,
      alignment: alignment,
      fadeOutDuration: fadeOutDuration,
      fadeInDuration: fadeInDuration,
      placeholderFadeInDuration: fadeInDuration,
      filterQuality: FilterQuality.low,
      placeholder: (_, _) =>
          getPlaceHolder?.call() ??
          _placeholder(
            context,
            isEmote: isEmote,
            isAvatar: isAvatar,
            placeholderColor: placeholderColor,
          ),
      errorWidget: (_, _, _) => _placeholder(
        context,
        isEmote: isEmote,
        isAvatar: isAvatar,
        placeholderColor: placeholderColor,
      ),
      colorBlendMode: reduce ? BlendMode.modulate : null,
      color: reduce ? reduceLuxColor : null,
    );
  }

  Widget _placeholder(
    BuildContext context, {
    required bool isEmote,
    required bool isAvatar,
    required Color placeholderColor,
  }) {
    return Container(
      width: width,
      height: height,
      clipBehavior: isEmote ? Clip.none : Clip.antiAlias,
      decoration: BoxDecoration(
        shape: isAvatar ? BoxShape.circle : BoxShape.rectangle,
        color: placeholderColor,
        borderRadius: isEmote || isAvatar ? null : borderRadius,
      ),
      child: Center(
        child: Image.asset(
          isAvatar ? 'assets/images/noface.jpeg' : 'assets/images/loading.png',
          width: width,
          height: height,
          cacheWidth: width.cacheSize(context),
          colorBlendMode: reduce ? BlendMode.modulate : null,
          color: reduce ? reduceLuxColor : null,
        ),
      ),
    );
  }
}
