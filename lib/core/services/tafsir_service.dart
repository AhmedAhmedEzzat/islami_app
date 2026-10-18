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
/// then available offline. [downloadAll] saves every sura of both tafsirs in
/// one go, for reading without internet.
abstract final class TafsirService {
  static const int suraCount = 114;

  static final Map<String, List<String>> _memory = {};
  static Directory? _cacheDir;
  static http.Client _client = http.Client();

  /// Progress of [downloadAll] from 0 to 1 while it runs, null otherwise.
  static final ValueNotifier<double?> downloadProgress = ValueNotifier(null);
  static bool _cancelled = false;

  /// Bumps when a [downloadAll] run ends, so saved counts can be re-read.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  /// Whether tafsir can be kept on the device. Not on the web, which has no
  /// files; there it is fetched each time.
  static bool get supported => !kIsWeb;

  /// Points the cache at [dir] and the downloads at [client].
  @visibleForTesting
  static void configure({required Directory dir, http.Client? client}) {
    _cacheDir = dir;
    _memory.clear();
    if (client != null) _client = client;
  }

  static Future<Directory> _dir() async {
    if (_cacheDir case final dir?) return dir;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/tafsir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _cacheDir = dir;
  }

  static Future<File?> _file(Tafsir tafsir, int sura) async =>
      supported ? File('${(await _dir()).path}/${tafsir.edition}-$sura.json') : null;

  /// Tafsir for every verse of [sura], or null if it is not cached and cannot
  /// be downloaded right now.
  static Future<List<String>?> forSura(Tafsir tafsir, int sura) async {
    final key = '${tafsir.edition}-$sura';
    final cached = _memory[key];
    if (cached != null) return cached;

    final file = await _file(tafsir, sura);
    if (file != null && file.existsSync()) {
      try {
        final list = List<String>.from(jsonDecode(await file.readAsString()) as List);
        return _memory[key] = list;
      } catch (_) {
        // Corrupt cache; fall through and re-download.
      }
    }

    final list = await _fetch(tafsir, sura, file);
    return list == null ? null : _memory[key] = list;
  }

  /// Downloads [sura] and saves it to [file], if there is one.
  static Future<List<String>?> _fetch(Tafsir tafsir, int sura, File? file) async {
    try {
      final response = await _client
          .get(Uri.parse('https://api.alquran.cloud/v1/surah/$sura/${tafsir.edition}'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final list = parseResponse(utf8.decode(response.bodyBytes));
      if (list == null) return null;
      // Written whole and then renamed, so a cut-off write never looks saved.
      if (file != null) {
        final part = File('${file.path}.part');
        await part.writeAsString(jsonEncode(list));
        await part.rename(file.path);
      }
      return list;
    } catch (e) {
      debugPrint('Tafsir ${tafsir.edition}-$sura unavailable: $e');
      return null;
    }
  }

  /// How many suras have every tafsir saved on the device.
  static Future<int> savedSuras() async {
    if (!supported) return 0;
    var saved = 0;
    for (var sura = 1; sura <= suraCount; sura++) {
      var all = true;
      for (final tafsir in Tafsir.values) {
        if (!(await _file(tafsir, sura))!.existsSync()) {
          all = false;
          break;
        }
      }
      if (all) saved++;
    }
    return saved;
  }

  /// Saves every sura of every tafsir that is not saved yet, a few at a time.
  /// True when all of it is now on the device, false if the connection
  /// failed, and null if it was stopped or a run was already going.
  static Future<bool?> downloadAll() async {
    if (!supported || downloadProgress.value != null) return null;
    _cancelled = false;
    downloadProgress.value = 0;

    final jobs = <(Tafsir, int, File)>[
      for (final tafsir in Tafsir.values)
        for (var sura = 1; sura <= suraCount; sura++)
          if ((await _file(tafsir, sura))! case final file when !file.existsSync()) (tafsir, sura, file),
    ];
    var done = 0;
    var failures = 0;
    final queue = jobs.iterator;
    Future<void> worker() async {
      // Gives up after a few failures rather than waiting out a timeout for
      // every sura when the phone is offline.
      while (!_cancelled && failures < 3 && queue.moveNext()) {
        final (tafsir, sura, file) = queue.current;
        if (await _fetch(tafsir, sura, file) == null) failures++;
        downloadProgress.value = ++done / jobs.length;
      }
    }

    try {
      await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    } finally {
      downloadProgress.value = null;
      changes.value++;
    }
    return _cancelled ? null : failures == 0;
  }

  /// Stops a [downloadAll] run after the suras already under way.
  static void cancel() => _cancelled = true;

  /// Removes every saved tafsir.
  static Future<void> deleteAll() async {
    if (!supported) return;
    _memory.clear();
    final dir = await _dir();
    // Emptied rather than removed, so the next save has somewhere to go.
    if (dir.existsSync()) {
      await for (final file in dir.list()) {
        await file.delete(recursive: true);
      }
    }
    changes.value++;
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
