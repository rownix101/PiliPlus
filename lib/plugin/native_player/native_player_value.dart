/// Playback state reported by the native player
enum NativePlaybackState {
  idle,
  buffering,
  ready,
  ended;

  static NativePlaybackState fromString(String value) {
    return NativePlaybackState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NativePlaybackState.idle,
    );
  }
}

/// Value holder for native player state
class NativePlayerValue {
  final Duration position;
  final Duration duration;
  final Duration buffered;
  final NativePlaybackState state;
  final bool isPlaying;
  final String? error;
  final int? videoWidth;
  final int? videoHeight;

  const NativePlayerValue({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.state = NativePlaybackState.idle,
    this.isPlaying = false,
    this.error,
    this.videoWidth,
    this.videoHeight,
  });

  NativePlayerValue copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    NativePlaybackState? state,
    bool? isPlaying,
    String? error,
    int? videoWidth,
    int? videoHeight,
  }) {
    return NativePlayerValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffered: buffered ?? this.buffered,
      state: state ?? this.state,
      isPlaying: isPlaying ?? this.isPlaying,
      error: error ?? this.error,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
    );
  }
}
