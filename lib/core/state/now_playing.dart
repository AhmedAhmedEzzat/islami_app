import 'package:flutter/foundation.dart';

import 'quran_player_state.dart';
import 'radio_state.dart';

enum NowPlayingSource { recitation, radio }

/// A flattened view of whatever audio is currently loaded.
///
/// Derived from the two cubits that already own the state rather than being a
/// third copy of it.
@immutable
class NowPlaying {
  const NowPlaying({
    required this.source,
    required this.title,
    required this.isPlaying,
    required this.isBuffering,
    this.suraId,
    this.ayah,
    this.progress,
  });

  final NowPlayingSource source;
  final String title;
  final bool isPlaying;
  final bool isBuffering;

  /// Set only for [NowPlayingSource.recitation].
  final String? suraId;

  /// The verse being recited (0 for the basmala), recitation only.
  final int? ayah;

  /// 0..1, or null for a live stream which has no duration.
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is NowPlaying &&
      other.source == source &&
      other.title == title &&
      other.isPlaying == isPlaying &&
      other.isBuffering == isBuffering &&
      other.suraId == suraId &&
      other.ayah == ayah &&
      other.progress == progress;

  @override
  int get hashCode =>
      Object.hash(source, title, isPlaying, isBuffering, suraId, ayah, progress);
}

/// Collapses the recitation and radio states into one.
///
/// Recitation wins when both are loaded: the player already stops the radio
/// before it starts, so that is the more recent intent.
NowPlaying? deriveNowPlaying({
  required QuranPlayerState quran,
  required RadioState radio,
  required String Function(String suraId) suraTitle,
  required String Function(int index) stationTitle,
}) {
  final suraId = quran.suraId;
  if (suraId != null) {
    return NowPlaying(
      source: NowPlayingSource.recitation,
      title: suraTitle(suraId),
      isPlaying: quran.isPlaying,
      isBuffering: quran.isBuffering,
      suraId: suraId,
      ayah: quran.ayah,
      // Recitation plays one file per verse, so progress through the sura is
      // the meaningful measure, not progress through the current file.
      progress: quran.suraProgress,
    );
  }

  final index = radio.currentIndex;
  if (index != null) {
    return NowPlaying(
      source: NowPlayingSource.radio,
      title: stationTitle(index),
      isPlaying: radio.isPlaying,
      isBuffering: radio.isBuffering,
    );
  }

  return null;
}
