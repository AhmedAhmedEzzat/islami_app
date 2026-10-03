// Generates the Sakina brand artwork: launcher icon, adaptive foreground and
// the native splash images.
//
// This lives as a test because painting the Arabic س needs a real Flutter
// engine — the `image` package has no TTF rasteriser, and there is no
// ImageMagick or SVG tooling on this machine. Run it explicitly:
//
//   flutter test tool/generate_brand_assets_test.dart
//
// It sits outside test/ so the normal suite does not run it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/widgets/sakina_mark.dart';

/// Deep green: dark enough for white to sit on it at icon sizes.
const Color kBrandGreen = Color(0xFF1B5E20);
const Color kBrandInk = Color(0xFFFFFFFF);

Future<void> _loadJanna() async {
  final loader = FontLoader('Janna')
    ..addFont(rootBundle.load('assets/fonts/ArbFONTS-Janna-LT-Bold.ttf'));
  await loader.load();
}

/// [artScale] is the fraction of the canvas the mark occupies, so one painter
/// can satisfy the launcher's full bleed, the adaptive icon's 66% safe zone
/// and the Android 12 splash's centred circle.
Future<void> _write(
  String path,
  int size, {
  required bool background,
  required double artScale,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final extent = size.toDouble();

  if (background) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, extent, extent),
      Paint()..color = kBrandGreen,
    );
  }

  final art = extent * artScale;
  canvas.save();
  canvas.translate((extent - art) / 2, (extent - art) / 2);
  const SakinaMark(color: kBrandInk).paint(canvas, Size(art, art));
  canvas.restore();

  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final bytes = data!.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  await File(path).writeAsBytes(Uint8List.fromList(bytes), flush: true);
  // ignore: avoid_print
  print('wrote $path (${size}x$size, ${bytes.length} bytes)');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate brand assets', () async {
    await _loadJanna();

    // Launcher source: full bleed on green.
    await _write('assets/brand/icon.png', 1024,
        background: true, artScale: 0.62);

    // Adaptive foreground: transparent, art inside the centre ~66% that
    // Android guarantees is never masked away by a launcher's shape.
    await _write('assets/brand/icon_foreground.png', 1024,
        background: false, artScale: 0.42);

    // Android 12+ splash: the system clips this to a 768px circle on a
    // 1152px canvas, so the art has to stay well inside that.
    await _write('assets/brand/splash_android12.png', 1152,
        background: false, artScale: 0.40);

    // Pre-Android-12 splash image.
    await _write('assets/brand/splash.png', 512,
        background: false, artScale: 0.70);

    for (final name in [
      'icon',
      'icon_foreground',
      'splash_android12',
      'splash',
    ]) {
      final file = File('assets/brand/$name.png');
      expect(file.existsSync(), isTrue, reason: '$name.png was not written');
      expect(file.lengthSync(), greaterThan(1000), reason: '$name.png is tiny');
    }
  });
}
