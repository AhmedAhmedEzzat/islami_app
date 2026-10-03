import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum Tafsir {
  muyassar('ar.muyassar'),
  jalalayn('ar.jalalayn');

  const Tafsir(this.edition);

  /// The api.alquran.cloud edition identifier.
  final String edition;
}

/// Arabic tafsir, fetched per sura on first use and cached on disk.
///
/// Tafsir is several megabytes for the whole Quran, so it is not bundled. Each
/// sura is downloaded once, the first time any of its verses is opened, and is
/// then available offline.
abstract final class TafsirService {
  static final Map<String, List<String>> _memory = {};

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/tafsir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Tafsir for every verse of [sura], or null if it is not cached and cannot
  /// be downloaded right now.
  static Future<List<String>?> forSura(Tafsir tafsir, int sura) async {
    final key = '${tafsir.edition}-$sura';
    final cached = _memory[key];
    if (cached != null) return cached;

    final file = File('${(await _dir()).path}/$key.json');
    if (file.existsSync()) {
      try {
        final list = List<String>.from(jsonDecode(await file.readAsString()) as List);
        return _memory[key] = list;
      } catch (_) {
        // Corrupt cache; fall through and re-download.
      }
    }

    try {
      final response = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$sura/${tafsir.edition}'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final list = parseResponse(utf8.decode(response.bodyBytes));
      if (list == null) return null;
      await file.writeAsString(jsonEncode(list));
      return _memory[key] = list;
    } catch (e) {
      debugPrint('Tafsir $key unavailable: $e');
      return null;
    }
  }

  /// Extracts the per-verse texts from an api.alquran.cloud surah response.
  @visibleForTesting
  static List<String>? parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['code'] != 200) return null;
      final ayahs = (json['data'] as Map<String, dynamic>)['ayahs'] as List;
      return [for (final a in ayahs) (a['text'] as String).trim()];
    } catch (_) {
      return null;
    }
  }
}
