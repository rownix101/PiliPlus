/// 字幕条目（从 B站 JSON 解析）
class SubtitleCue {
  /// 开始时间（秒）
  final double from;

  /// 结束时间（秒）
  final double to;

  /// 字幕内容
  final String content;

  const SubtitleCue({
    required this.from,
    required this.to,
    required this.content,
  });

  factory SubtitleCue.fromJson(Map<String, dynamic> json) => SubtitleCue(
    from: (json['from'] as num).toDouble(),
    to: (json['to'] as num).toDouble(),
    content: (json['content'] as String).trim(),
  );
}
