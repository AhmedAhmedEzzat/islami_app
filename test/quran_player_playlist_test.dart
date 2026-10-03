import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/state/quran_player_cubit.dart';

void main() {
  group('playlistAyahs', () {
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
}
