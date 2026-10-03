import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../constants/reciters.dart';
import 'quran_player_state.dart';
import 'radio_cubit.dart';

/// Verse-by-verse Quran recitation.
///
/// Each verse is its own audio file, played as a playlist. Knowing which file
/// is playing is what lets the mushaf highlight the current verse and turn the
/// page as recitation moves on — something a single whole-sura file cannot do.
///
/// Uses its own [AudioPlayer], separate from the radio's, and stops the radio
/// before starting so the two never play over each other.
class QuranPlayerCubit extends Cubit<QuranPlayerState> {
  QuranPlayerCubit({required RadioCubit radio, AudioPlayer? player})
    : _radio = radio,
      _player = player ?? AudioPlayer(),
      super(const QuranPlayerState()) {
    _subs.addAll([
      _player.playerStateStream.listen((s) {
        if (isClosed) return;
        emit(
          state.copyWith(
            isPlaying: s.playing && s.processingState != ProcessingState.completed,
            isBuffering:
                s.processingState == ProcessingState.loading ||
                s.processingState == ProcessingState.buffering,
          ),
        );
      }),
      _player.currentIndexStream.listen((index) {
        if (isClosed || index == null || index >= _ayahAt.length) return;
        emit(state.copyWith(ayah: _ayahAt[index], position: Duration.zero));
      }),
      _player.positionStream.listen((p) {
        if (isClosed) return;
        emit(state.copyWith(position: p));
      }),
      _player.durationStream.listen((d) {
        if (isClosed || d == null) return;
        emit(state.copyWith(duration: d));
      }),
    ]);
  }

  final RadioCubit _radio;
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Verse number for each playlist index. 0 is the basmala.
  List<int> _ayahAt = const [];

  /// Builds the playlist for [sura] starting at [fromAyah]. Pure, so the
  /// basmala rules can be tested without audio.
  @visibleForTesting
  static List<int> playlistAyahs(int sura, int fromAyah, int totalAyahs) {
    final start = fromAyah.clamp(1, totalAyahs);
    final needsBasmala = start == 1 && sura != 1 && sura != 9;
    return [
      if (needsBasmala) 0,
      for (var a = start; a <= totalAyahs; a++) a,
    ];
  }

  /// Starts [suraId] at [fromAyah] (1-based).
  Future<void> playFrom({
    required String suraId,
    required int fromAyah,
    required int totalAyahs,
    required String reciterId,
  }) async {
    final sura = int.tryParse(suraId);
    if (sura == null || totalAyahs <= 0) return;

    emit(state.copyWith(clearError: true));
    await _radio.stop();

    final reciter = Reciters.byId(reciterId);
    _ayahAt = playlistAyahs(sura, fromAyah, totalAyahs);

    emit(
      state.copyWith(
        suraId: suraId,
        ayah: _ayahAt.first,
        totalAyahs: totalAyahs,
        isBuffering: true,
        position: Duration.zero,
      ),
    );

    try {
      await _player.setAudioSources([
        for (final a in _ayahAt)
          AudioSource.uri(
            Uri.parse(a == 0 ? reciter.basmalaUrl : reciter.urlForVerse(sura, a)),
          ),
      ], preload: true);
      await _applyRepeat(state.repeat);
      if (isClosed) return;
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Recitation failed for sura $suraId: $e');
      if (isClosed) return;
      // The text must stay readable even when audio fails.
      emit(state.copyWith(clearSura: true, errorKey: 'recitation_unavailable'));
    }
  }

  /// Play/pause if [suraId] is loaded, otherwise start it from verse 1.
  Future<void> toggle({
    required String suraId,
    required int totalAyahs,
    required String reciterId,
  }) async {
    if (state.suraId == suraId) return togglePlayPause();
    return playFrom(
      suraId: suraId,
      fromAyah: 1,
      totalAyahs: totalAyahs,
      reciterId: reciterId,
    );
  }

  Future<void> togglePlayPause() async {
    if (state.suraId == null) return;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: 0);
      unawaited(_player.play());
      return;
    }
    _player.playing ? await _player.pause() : unawaited(_player.play());
  }

  Future<void> nextVerse() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  Future<void> previousVerse() async {
    if (_player.hasPrevious) await _player.seekToPrevious();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> cycleRepeat() async {
    final next = RecitationRepeat.values[(state.repeat.index + 1) % RecitationRepeat.values.length];
    await _applyRepeat(next);
    if (isClosed) return;
    emit(state.copyWith(repeat: next));
  }

  Future<void> _applyRepeat(RecitationRepeat mode) => _player.setLoopMode(switch (mode) {
    RecitationRepeat.off => LoopMode.off,
    RecitationRepeat.verse => LoopMode.one,
    RecitationRepeat.sura => LoopMode.all,
  });

  /// Stops recitation entirely. Called when the radio takes over.
  Future<void> stop() async {
    await _player.stop();
    _ayahAt = const [];
    if (isClosed) return;
    emit(state.copyWith(clearSura: true));
  }

  void clearError() => emit(state.copyWith(clearError: true));

  @override
  Future<void> close() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _player.dispose();
    return super.close();
  }
}
