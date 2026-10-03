import 'package:flutter/foundation.dart';

@immutable
class RadioState {
  const RadioState({
    this.currentIndex,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isMuted = false,
    this.errorKey,
  });

  /// Index into `RadioChannel.channels`, or null when nothing is loaded.
  final int? currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final bool isMuted;

  /// An error *code*, not a sentence — the view decides the wording so the
  /// message can be localized later without touching this layer.
  final String? errorKey;

  bool isPlayingAt(int index) => currentIndex == index && isPlaying;
  bool isBufferingAt(int index) => currentIndex == index && isBuffering;
  bool isActiveAt(int index) => currentIndex == index;

  RadioState copyWith({
    int? currentIndex,
    bool clearIndex = false,
    bool? isPlaying,
    bool? isBuffering,
    bool? isMuted,
    String? errorKey,
    bool clearError = false,
  }) {
    return RadioState(
      currentIndex: clearIndex ? null : (currentIndex ?? this.currentIndex),
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isMuted: isMuted ?? this.isMuted,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RadioState &&
      other.currentIndex == currentIndex &&
      other.isPlaying == isPlaying &&
      other.isBuffering == isBuffering &&
      other.isMuted == isMuted &&
      other.errorKey == errorKey;

  @override
  int get hashCode =>
      Object.hash(currentIndex, isPlaying, isBuffering, isMuted, errorKey);
}
