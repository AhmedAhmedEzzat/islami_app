import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../constants/constants.dart';
import '../constants/reciters.dart';
import '../services/recitation_downloads.dart';
import '../services/sleep_timer.dart';
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
        if (s.processingState == ProcessingState.completed && s.playing) {
          unawaited(_onSuraEnded());
        }
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
        // Repeating the sura wraps from the last verse to the first, so the
        // sura never "completes"; that wrap is where it ended.
        final wrapped = index == 0 &&
            _lastIndex == _ayahAt.length - 1 &&
            _ayahAt.length > 1 &&
            _player.loopMode == LoopMode.all;
        _lastIndex = index;
        if (wrapped && SleepTimer.takeEndOfSura()) unawaited(_player.pause());
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
  int? _lastIndex;
  String _reciterId = Reciters.all.first.id;
  bool _advancing = false;

  /// Bumped by every start, pause and stop, so a load still in flight can
  /// tell it was overtaken and must not start playing.
  int _generation = 0;

  /// Whether to go straight on into the next sura. Set from `main()` to read
  /// the user's setting.
  bool Function() continuous = () => true;

  /// At the end of a sura: stop for the sleep timer, or carry on into the
  /// next sura, as a reciter does in a khatma.
  Future<void> _onSuraEnded() async {
    if (_advancing) return;
    if (SleepTimer.takeEndOfSura()) return;
    final sura = int.tryParse(state.suraId ?? '');
    if (sura == null || sura >= 114 || !continuous() || state.repeat != RecitationRepeat.off) return;
    _advancing = true;
    try {
      final next = Constants.suraDataLists[sura];
      await playFrom(
        suraId: next.suraID,
        fromAyah: 1,
        totalAyahs: int.parse(next.suraVersesNumber),
        reciterId: _reciterId,
        quiet: true,
      );
    } finally {
      _advancing = false;
    }
  }

  /// Builds the playlist for [sura] starting at [fromAyah]. Pure, so the
  /// basmala rules can be tested without audio.
  @visibleForTesting
  static List<int> playlistAyahs(int sura, int fromAyah, int totalAyahs, {int repeatEach = 1}) {
    final start = fromAyah.clamp(1, totalAyahs);
    final needsBasmala = start == 1 && sura != 1 && sura != 9;
    return [
      if (needsBasmala) 0,
      // For memorising: each verse several times before the next.
      for (var a = start; a <= totalAyahs; a++)
        for (var r = 0; r < repeatEach.clamp(1, 20); r++) a,
    ];
  }

  /// How many times each verse is recited, for memorising. Set from `main()`
  /// to read the user's setting.
  int Function() repeatEach = () => 1;

  /// Rebuilds the playlist with a new [repeatEach] at the verse playing,
  /// keeping it paused if it was. When the sura repeats, the whole sura is
  /// rebuilt so the loop still covers it, and play resumes at the same verse.
  Future<void> restartFromCurrentVerse() async {
    final sura = state.suraId;
    final ayah = state.ayah;
    if (sura == null || ayah == null) return;
    final verse = ayah == 0 ? 1 : ayah;
    final wholeSura = state.repeat == RecitationRepeat.sura;
    await playFrom(
      suraId: sura,
      fromAyah: wholeSura ? 1 : verse,
      startAtAyah: wholeSura ? verse : null,
      totalAyahs: state.totalAyahs,
      reciterId: _reciterId,
      autoplay: state.isPlaying,
    );
  }

  /// Starts [suraId] at [fromAyah] (1-based).
  Future<void> playFrom({
    required String suraId,
    required int fromAyah,
    required int totalAyahs,
    required String reciterId,
    bool quiet = false,
    int? startAtAyah,
    bool autoplay = true,
  }) async {
    final sura = int.tryParse(suraId);
    if (sura == null || totalAyahs <= 0) return;
    final generation = ++_generation;

    emit(state.copyWith(clearError: true));
    await _radio.stop();

    final reciter = Reciters.byId(reciterId);
    _reciterId = reciter.id;
    _ayahAt = playlistAyahs(sura, fromAyah, totalAyahs, repeatEach: repeatEach());
    _lastIndex = null;

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
      await RecitationDownloads.ready();
      await _player.setAudioSources([
        for (final a in _ayahAt) _sourceFor(reciter, a == 0 ? 1 : sura, a == 0 ? 1 : a),
      ], preload: true);
      await _applyRepeat(state.repeat);
      // Paused (the sleep timer) or stopped (the radio) while loading.
      if (isClosed || generation != _generation) return;
      final at = startAtAyah == null ? -1 : _ayahAt.indexOf(startAtAyah);
      if (at > 0) await _player.seek(Duration.zero, index: at);
      if (isClosed || generation != _generation || !autoplay) return;
      unawaited(_player.play());
    } catch (e) {
      debugPrint('Recitation failed for sura $suraId: $e');
      if (isClosed || generation != _generation) return;
      // The text must stay readable even when audio fails. Moving on to a
      // sura that is not downloaded, offline, just stops: no error for that.
      emit(state.copyWith(clearSura: true, errorKey: quiet ? null : 'recitation_unavailable'));
    }
  }

  /// The verse's saved file when it has been downloaded, so it plays without
  /// a connection; otherwise its stream.
  static AudioSource _sourceFor(Reciter reciter, int sura, int ayah) {
    final local = RecitationDownloads.localPath(reciter, sura, ayah);
    return local != null
        ? AudioSource.file(local)
        : AudioSource.uri(Uri.parse(reciter.urlForVerse(sura, ayah)));
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

  /// The next verse, skipping the rest of this one's repeats. When the sura
  /// repeats, the last verse leads back to the first.
  Future<void> nextVerse() async {
    final i = _player.currentIndex;
    // A new playlist may still be loading, its index meant for the old one.
    if (i == null || i >= _ayahAt.length) return;
    var next = _ayahAt.indexWhere((a) => a != _ayahAt[i], i);
    if (next == -1 && _player.loopMode == LoopMode.all && _ayahAt.isNotEmpty) next = 0;
    if (next != -1) await _player.seek(Duration.zero, index: next);
  }

  /// The first recitation of the verse before this one. When the sura
  /// repeats, the first verse leads back to the last.
  Future<void> previousVerse() async {
    final i = _player.currentIndex;
    if (i == null || i >= _ayahAt.length) return;
    final current = _ayahAt[i];
    var before = _ayahAt.lastIndexWhere((a) => a != current, i);
    if (before == -1 && _player.loopMode == LoopMode.all) {
      before = _ayahAt.lastIndexWhere((a) => a != current);
    }
    if (before == -1) return;
    var start = before;
    while (start > 0 && _ayahAt[start - 1] == _ayahAt[before]) {
      start--;
    }
    await _player.seek(Duration.zero, index: start);
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

  /// Pauses, for the sleep timer.
  Future<void> pause() {
    _generation++;
    return _player.pause();
  }

  /// Stops recitation entirely. Called when the radio takes over.
  Future<void> stop() async {
    _generation++;
    // "End of sura" belonged to this recitation; it must not linger and stop
    // a later one.
    SleepTimer.takeEndOfSura();
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
