import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/constants/assets.dart';

void main() {
  const pictures = [
    Assets.quranBackground,
    Assets.hadethBackground,
    Assets.tasbehBackground,
    Assets.radioBackground,
    Assets.timeBackground,
    Assets.vectorRight,
    Assets.vectorLeft,
    Assets.onBoarding1,
    Assets.onBoarding2,
    Assets.onBoarding3,
    Assets.onBoarding4,
    Assets.onBoarding5,
  ];

  test('every picture the app names ships with it', () {
    for (final path in pictures) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('every picture decodes, at a sensible size', (tester) async {
    await tester.runAsync(() async {
      for (final path in pictures) {
        final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
        final image = (await codec.getNextFrame()).image;
        expect(image.width, inInclusiveRange(200, 1080), reason: path);
        image.dispose();
        codec.dispose();
      }
    });
  });

  test('nothing in assets/images is left unused', () {
    final shipped = Directory('assets/images').listSync().whereType<File>().map((f) => f.path.replaceAll(r'\', '/'));
    for (final path in shipped) {
      expect(pictures, contains(path), reason: '$path is bundled but never shown');
    }
  });
}
