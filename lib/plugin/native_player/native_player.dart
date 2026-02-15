import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 字幕轨道 (从 media_kit 迁移)
class SubtitleTrack {
  final String? id;
  final String? title;
  final String? language;
  final bool uri;
  final bool data;

  const SubtitleTrack._(this.id, this.title, this.language, {this.uri = false, this.data = false});

  /// 无字幕
  factory SubtitleTrack.no() => const SubtitleTrack._('', '', '');

  /// 字幕轨道
  factory SubtitleTrack(String? id, String? title, String? language, {bool uri = false, bool data = false}) =>
      SubtitleTrack._(id, title, language, uri: uri, data: data);
}

/// Events emitted by the native player
class NativePlayerEvent {
  final String type;
  final Duration? position;
  final Duration? duration;
  final Duration? buffered;
  final String? state;
  final bool? isPlaying;
  final String? error;
  final int? errorCode;
  final int? videoWidth;
  final int? videoHeight;

  NativePlayerEvent._({
    required this.type,
    this.position,
    this.duration,
    this.buffered,
    this.state,
    this.isPlaying,
    this.error,
    this.errorCode,
    this.videoWidth,
    this.videoHeight,
  });

  factory NativePlayerEvent.fromMap(Map<dynamic, dynamic> map) {
    final type = map['type'] as String;
    switch (type) {
      case 'position':
        return NativePlayerEvent._(
          type: type,
          position: Duration(milliseconds: (map['position'] as num).toInt()),
          duration: Duration(milliseconds: (map['duration'] as num).toInt()),
          buffered: Duration(milliseconds: (map['buffered'] as num).toInt()),
        );
      case 'playbackState':
        return NativePlayerEvent._(
          type: type,
          state: map['state'] as String,
        );
      case 'isPlaying':
        return NativePlayerEvent._(
          type: type,
          isPlaying: map['value'] as bool,
        );
      case 'error':
        return NativePlayerEvent._(
          type: type,
          error: map['error'] as String?,
          errorCode: map['errorCode'] as int?,
        );
      case 'videoSize':
        return NativePlayerEvent._(
          type: type,
          videoWidth: map['width'] as int?,
          videoHeight: map['height'] as int?,
        );
      default:
        return NativePlayerEvent._(type: type);
    }
  }
}

/// Native video player using Media3 (Android) / AVPlayer (iOS)
class NativePlayer {
  static const _methodChannel = MethodChannel('com.pilipro/native_player');
  static const _eventChannel = EventChannel('com.pilipro/native_player/events');

  int? _textureId;
  StreamSubscription? _eventSubscription;

  /// Current texture ID for rendering
  int? get textureId => _textureId;

  /// Event stream
  Stream<NativePlayerEvent>? _eventStream;
  Stream<NativePlayerEvent> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((data) => NativePlayerEvent.fromMap(data as Map))
        .asBroadcastStream();
    return _eventStream!;
  }

  /// Create a new player instance with video (and optional audio) URL.
  /// Returns the texture ID for rendering.
  Future<int> create({
    required String videoUrl,
    String? audioUrl,
    Map<String, String>? headers,
  }) async {
    final textureId = await _methodChannel.invokeMethod<int>('create', {
      'videoUrl': videoUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (headers != null) 'headers': headers,
    });
    _textureId = textureId!;
    return _textureId!;
  }

  Future<void> play() => _methodChannel.invokeMethod('play');

  Future<void> pause() => _methodChannel.invokeMethod('pause');

  Future<void> seekTo(Duration position) => _methodChannel.invokeMethod(
        'seekTo',
        {'position': position.inMilliseconds},
      );

  Future<void> setSpeed(double speed) => _methodChannel.invokeMethod(
        'setPlaybackSpeed',
        {'speed': speed},
      );

  Future<void> setVolume(double volume) => _methodChannel.invokeMethod(
        'setVolume',
        {'volume': volume},
      );

  Future<void> setLooping(bool looping) => _methodChannel.invokeMethod(
        'setLooping',
        {'looping': looping},
      );

  Future<void> setVideoTrackEnabled(bool enabled) =>
      _methodChannel.invokeMethod(
        'setVideoTrackEnabled',
        {'enabled': enabled},
      );

  /// 播放器状态 (兼容接口，实际状态通过事件流获取)
  NativePlayerState get state => _state;
  NativePlayerState _state = NativePlayerState.none;

  /// 平台接口 (兼容接口，返回自身)
  NativePlayer? get platform => this;

  /// 跳转到指定位置 (兼容旧接口，等同于 seekTo)
  Future<void> seek(Duration position) => seekTo(position);

  /// 播放或暂停切换 (兼容接口)
  Future<void> playOrPause() async {
    // 需要通过外部状态管理实现
  }

  /// 设置字幕轨道
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _methodChannel.invokeMethod('setSubtitleTrack', {
      'id': track.id,
      'title': track.title,
      'language': track.language,
      'uri': track.uri,
      'data': track.data,
    });
  }

  /// 截图 (兼容接口，原生播放器暂未实现)
  Future<Uint8List?> screenshot({String? format}) async {
    // TODO: 实现原生播放器截图
    return null;
  }

  /// 获取播放器属性 (兼容接口，原生播放器暂未实现)
  Future<String?> getProperty(String property) async {
    // TODO: 实现原生播放器属性获取
    return null;
  }

  Future<void> dispose() async {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventStream = null;
    await _methodChannel.invokeMethod('dispose');
    _textureId = null;
  }
}

/// 播放器状态 (兼容 media_kit)
class NativePlayerState {
  final bool playing;
  final bool paused;
  final bool completed;
  final int? width;
  final int? height;
  final Map<String, dynamic>? videoParams;
  final Map<String, dynamic>? audioParams;
  final List<dynamic>? playlist;
  final Tracks? track;
  final double? pitch;
  final double? rate;
  final double? audioBitrate;
  final double? volume;

  const NativePlayerState({
    this.playing = false,
    this.paused = false,
    this.completed = false,
    this.width,
    this.height,
    this.videoParams,
    this.audioParams,
    this.playlist,
    this.track,
    this.pitch,
    this.rate,
    this.audioBitrate,
    this.volume,
  });

  static const none = NativePlayerState();
}

/// 轨道信息 (兼容 media_kit)
class Tracks {
  final AudioTrack? audio;
  final VideoTrack? video;

  const Tracks({this.audio, this.video});
}

class AudioTrack {
  final String? id;
  final String? title;
  final String? language;

  const AudioTrack({this.id, this.title, this.language});

  @override
  String toString() => '$title (${language ?? 'unknown'})';
}

class VideoTrack {
  final String? id;
  final String? title;
  final String? language;

  const VideoTrack({this.id, this.title, this.language});

  @override
  String toString() => '$title (${language ?? 'unknown'})';
}
