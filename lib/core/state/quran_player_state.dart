import 'package:flutter/foundation.dart';

/// Not `RepeatMode`: Flutter already exports one (for animations).
enum RecitationRepeat { off, verse, sura }

@immutable
class QuranPlayerState {
  const QuranPlayerState({
    this.suraId,
    this.ayah,
    this.totalAyahs = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration,
    this.repeat = RecitationRepeat.off,
    this.errorKey,
  });

  final String? suraId;

  /// The verse being recited, 1-based. 0 while the basmala plays; null when
  /// nothing is loaded.
  final int? ayah;

  final int totalAyahs;
  final bool isPlaying;
  final bool isBuffering;

  /// Position within the current verse.
  final Duration position;
  final Duration? duration;
  final RecitationRepeat repeat;
  final String? errorKey;

  bool isLoaded(String id) => suraId == id;

  /// How far through the sura recitation has got, 0..1.
  double? get suraProgress {
    final a = ayah;
    if (a == null || totalAyahs <= 0) return null;
    return (a / totalAyahs).clamp(0.0, 1.0);
  }

  QuranPlayerState copyWith({
    String? suraId,
    bool clearSura = false,
    int? ayah,
    int? totalAyahs,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    RecitationRepeat? repeat,
    String? errorKey,
    bool clearError = false,
  }) {
    if (clearSura) {
      return QuranPlayerState(repeat: repeat ?? this.repeat, errorKey: errorKey);
    }
    return QuranPlayerState(
      suraId: suraId ?? this.suraId,
      ayah: ayah ?? this.ayah,
      totalAyahs: totalAyahs ?? this.totalAyahs,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      repeat: repeat ?? this.repeat,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuranPlayerState &&
      other.suraId == suraId &&
      other.ayah == ayah &&
      other.totalAyahs == totalAyahs &&
      other.isPlaying == isPlaying &&
      other.isBuffering == isBuffering &&
      other.position == position &&
      other.duration == duration &&
      other.repeat == repeat &&
      other.errorKey == errorKey;

  @override
  int get hashCode => Object.hash(
    suraId,
    ayah,
    totalAyahs,
    isPlaying,
    isBuffering,
    position,
    duration,
    repeat,
    errorKey,
  );
}
