import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/state/now_playing.dart';
import 'package:sakina/core/state/quran_player_state.dart';
import 'package:sakina/core/state/radio_state.dart';

NowPlaying? derive(QuranPlayerState quran, RadioState radio) {
  return deriveNowPlaying(
    quran: quran,
    radio: radio,
    suraTitle: (id) => 'Sura $id',
    stationTitle: (i) => 'Station $i',
  );
}

void main() {
  group('deriveNowPlaying', () {
    test('is null when nothing is loaded', () {
      expect(derive(const QuranPlayerState(), const RadioState()), isNull);
    });

    test('reports the radio station when only radio is loaded', () {
      final playing = derive(
        const QuranPlayerState(),
        const RadioState(currentIndex: 2, isPlaying: true),
      )!;
      expect(playing.source, NowPlayingSource.radio);
      expect(playing.title, 'Station 2');
      expect(playing.isPlaying, isTrue);
      // A live stream has no duration, so there is no progress to show.
      expect(playing.progress, isNull);
    });

    test('reports the sura when only recitation is loaded', () {
      final playing = derive(
        const QuranPlayerState(suraId: '36', isPlaying: true),
        const RadioState(),
      )!;
      expect(playing.source, NowPlayingSource.recitation);
      expect(playing.title, 'Sura 36');
      expect(playing.suraId, '36');
    });

    test('recitation wins when both are somehow loaded', () {
      final playing = derive(
        const QuranPlayerState(suraId: '1'),
        const RadioState(currentIndex: 0),
      )!;
      expect(playing.source, NowPlayingSource.recitation);
    });

    test('progress is how far through the sura recitation has got', () {
      final playing = derive(
        const QuranPlayerState(suraId: '1', ayah: 2, totalAyahs: 8),
        const RadioState(),
      )!;
      expect(playing.progress, closeTo(0.25, 0.0001));
      expect(playing.ayah, 2);
    });

    test('progress is null rather than NaN with no verse count', () {
      final playing = derive(
        const QuranPlayerState(suraId: '1', ayah: 1),
        const RadioState(),
      )!;
      expect(playing.progress, isNull);
    });

    test('progress never exceeds 1', () {
      final playing = derive(
        const QuranPlayerState(suraId: '1', ayah: 9, totalAyahs: 7),
        const RadioState(),
      )!;
      expect(playing.progress, 1.0);
    });

    test('carries the buffering flag through', () {
      final playing = derive(
        const QuranPlayerState(suraId: '1', isBuffering: true),
        const RadioState(),
      )!;
      expect(playing.isBuffering, isTrue);
    });
  });
}
