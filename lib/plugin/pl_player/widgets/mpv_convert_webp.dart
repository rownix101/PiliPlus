// 已禁用：此文件依赖于 media_kit，项目已迁移到原生播放器
// 如需实现类似功能，需要使用原生平台通道

import 'package:flutter/foundation.dart' show kDebugMode;

enum WebpPreset {
  none('none', '无', '不使用预设'),
  def('default', '默认', '默认预设'),
  picture('picture', '图片', '数码照片，如人像、室内拍摄'),
  photo('photo', '照片', '户外摄影，自然光环境'),
  drawing('drawing', '绘图', '手绘或线稿，高对比度细节'),
  icon('icon', '图标', '小型彩色图像'),
  text('text', '文本', '文字类');

  final String flag;
  final String name;
  final String desc;

  const WebpPreset(this.flag, this.name, this.desc);
}

class MpvConvertWebp {
  final String url;
  final String outFile;
  final double start;
  final double duration;
  final dynamic progress;
  final WebpPreset preset;

  MpvConvertWebp(
    this.url,
    this.outFile,
    this.start,
    double end, {
    this.progress,
    this.preset = WebpPreset.def,
  }) : duration = end - start;

  Future<bool> convert() async {
    if (kDebugMode) {
      print('MpvConvertWebp.convert() is not implemented');
    }
    return false;
  }

  void dispose() {}
}