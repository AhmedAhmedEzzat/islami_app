import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/state/quran_player_cubit.dart';
import 'package:sakina/core/state/quran_player_state.dart';

void main() {
  group('playlistAyahs', () {
    test('a long passage has its passes cut to keep the queue sane', () {
      final fitted = QuranPlayerCubit.fitRange(const VerseRange(1, 286, 20), 10);
      expect(fitted.passes, 1);
      expect(QuranPlayerCubit.fitRange(const VerseRange(1, 10, 20), 2).passes, 20);
      final big = QuranPlayerCubit.fitRange(const VerseRange(1, 200, 20), 1);
      expect(200 * big.passes, lessThanOrEqualTo(QuranPlayerCubit.maxQueued));
    });

    test('passAt finds the pass a playlist index is in', () {
      const range = VerseRange(5, 7, 3);
      final list = QuranPlayerCubit.playlistAyahs(2, 5, 286, toAyah: 7, passes: 3);
      expect([for (var i = 0; i < list.length; i++) QuranPlayerCubit.passAt(list, i, range, 1)], [0, 0, 0, 1, 1, 1, 2, 2, 2]);
      // With the basmala first and two of each verse.
      final withBasmala = QuranPlayerCubit.playlistAyahs(112, 1, 4, toAyah: 2, passes: 2, repeatEach: 2);
      expect(withBasmala, [0, 1, 1, 2, 2, 1, 1, 2, 2]);
      expect(QuranPlayerCubit.passAt(withBasmala, 6, const VerseRange(1, 2, 2), 2), 1);
    });

    test('a passage plays the given verses the given number of times', () {
      expect(QuranPlayerCubit.playlistAyahs(2, 5, 286, toAyah: 7, passes: 3), [5, 6, 7, 5, 6, 7, 5, 6, 7]);
    });

    test('a passage from verse 1 has the basmala once, before the first pass', () {
      expect(QuranPlayerCubit.playlistAyahs(112, 1, 4, toAyah: 2, passes: 2), [0, 1, 2, 1, 2]);
    });

    test('a passage combines with repeating each verse', () {
      expect(QuranPlayerCubit.playlistAyahs(1, 6, 7, toAyah: 7, passes: 2, repeatEach: 2), [6, 6, 7, 7, 6, 6, 7, 7]);
    });

    test('a passage is kept inside the sura', () {
      expect(QuranPlayerCubit.playlistAyahs(1, 6, 7, toAyah: 40), [6, 7]);
      expect(QuranPlayerCubit.playlistAyahs(1, 6, 7, toAyah: 2), [6]);
    });

    test('a sura started from the top is preceded by the basmala', () {
      expect(QuranPlayerCubit.playlistAyahs(2, 1, 5), [0, 1, 2, 3, 4, 5]);
    });

    test('Al-Fatiha gets no extra basmala: it is already verse 1', () {
      expect(QuranPlayerCubit.playlistAyahs(1, 1, 7), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('At-Tawbah has no basmala', () {
      expect(QuranPlayerCubit.playlistAyahs(9, 1, 3), [1, 2, 3]);
    });

    test('starting mid-sura skips the basmala', () {
      expect(QuranPlayerCubit.playlistAyahs(2, 255, 257), [255, 256, 257]);
    });

    test('an out-of-range start is clamped rather than producing nothing', () {
      expect(QuranPlayerCubit.playlistAyahs(112, 99, 4), [4]);
      expect(QuranPlayerCubit.playlistAyahs(112, 0, 4), [0, 1, 2, 3, 4]);
    });
  });

  test('for memorising, each verse repeats before the next; the basmala once', () {
    expect(QuranPlayerCubit.playlistAyahs(112, 1, 2, repeatEach: 3), [0, 1, 1, 1, 2, 2, 2]);
    expect(QuranPlayerCubit.playlistAyahs(1, 6, 7, repeatEach: 2), [6, 6, 7, 7]);
    expect(QuranPlayerCubit.playlistAyahs(1, 7, 7, repeatEach: 0), [7], reason: 'at least once');
  });
}
