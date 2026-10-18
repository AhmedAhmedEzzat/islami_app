import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/constants.dart';
import '../constants/prefs_keys.dart';
import '../constants/reciters.dart';
import 'shared_prefs_helper.dart';

enum DownloadStatus { queued, downloading, failed }

/// A sura download that is waiting, running or has failed.
@immutable
class SuraDownload {
  const SuraDownload(this.status, {this.done = 0, this.total = 0});

  final DownloadStatus status;

  /// Verse files on disk so far, out of [total].
  final int done;
  final int total;

  double? get progress => total == 0 ? null : done / total;
}

/// Recitations saved on the phone, so they play without a connection.
///
/// Files are the same verse-by-verse mp3s the player streams, saved as
/// `recitations/<reciter folder>/SSSAAA.mp3`, so the player swaps each
/// stream for its file and highlighting and page-following work offline too.
/// A sura is marked downloaded once every one of its files is on disk; files
/// already there are skipped, so a stopped download resumes where it left off.
abstract final class RecitationDownloads {
  /// Bumped on every change, for widgets to rebuild on.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static Directory? _root;
  static http.Client _client = http.Client();

  /// Downloads at once within a sura: enough to hide the latency of many
  /// small files without hammering the server.
  static const int _parallel = 4;

  static final Map<String, SuraDownload> _jobs = {};
  static final List<(Reciter, int)> _queue = [];
  static bool _running = false;

  /// Reciter ids whose queued work should stop.
  static final Set<String> _cancelled = {};

  static String _key(String reciterId, int sura) => '$reciterId:$sura';

  static void _changed() => changes.value++;

  /// Points storage and the network elsewhere, for tests.
  @visibleForTesting
  static void configure({required Directory root, http.Client? client}) {
    _root = root;
    if (client != null) _client = client;
    _jobs.clear();
    _queue.clear();
    _cancelled.clear();
    _running = false;
  }

  /// Resolves the storage folder. Cheap after the first call.
  static Future<void> ready() async {
    if (_root != null || kIsWeb) return;
    try {
      final base = await getApplicationSupportDirectory();
      _root = Directory('${base.path}/recitations');
    } catch (e) {
      // Without storage everything still streams.
      debugPrint('No storage for recitations: $e');
    }
  }

  /// Not on the web, where the browser caches streams itself.
  static bool get supported => !kIsWeb;

  static Directory? _dirOf(Reciter reciter) =>
      _root == null ? null : Directory('${_root!.path}/${reciter.folder}');

  static String _name(int sura, int ayah) =>
      '${sura.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  /// The saved file for a verse, or null if it is not on the phone. Call
  /// [ready] first.
  static String? localPath(Reciter reciter, int sura, int ayah) {
    final dir = _dirOf(reciter);
    if (dir == null) return null;
    final file = File('${dir.path}/${_name(sura, ayah)}');
    return file.existsSync() ? file.path : null;
  }

  /// The verse files a sura needs: its verses, and Al-Fatiha 1:1, which the
  /// player recites as the basmala before every other sura but At-Tawbah.
  @visibleForTesting
  static List<(int, int)> filesFor(int sura) {
    final ayahs = int.parse(Constants.suraDataLists[sura - 1].suraVersesNumber);
    return [
      if (sura != 1 && sura != 9) (1, 1),
      for (var a = 1; a <= ayahs; a++) (sura, a),
    ];
  }

  static Set<int> downloaded(String reciterId) => {
    for (final s in LocalStorageServices.getStringList(PrefsKeys.recitationDownloads(reciterId)) ?? const <String>[])
      ?int.tryParse(s),
  };

  static bool isDownloaded(String reciterId, int sura) => downloaded(reciterId).contains(sura);

  static SuraDownload? jobFor(String reciterId, int sura) => _jobs[_key(reciterId, sura)];

  /// True while anything of [reciterId] is queued or downloading.
  static bool isBusy(String reciterId) => _jobs.entries.any(
    (e) => e.key.startsWith('$reciterId:') && e.value.status != DownloadStatus.failed,
  );

  static Future<void> _mark(String reciterId, int sura, bool on) async {
    final set = downloaded(reciterId);
    on ? set.add(sura) : set.remove(sura);
    await LocalStorageServices.setStringList(
      PrefsKeys.recitationDownloads(reciterId),
      [for (final s in set.toList()..sort()) '$s'],
    );
  }

  /// Queues [sura] of [reciter].
  static void download(Reciter reciter, int sura) {
    final key = _key(reciter.id, sura);
    final job = _jobs[key];
    if (isDownloaded(reciter.id, sura) || (job != null && job.status != DownloadStatus.failed)) return;
    _cancelled.remove(reciter.id);
    _jobs[key] = const SuraDownload(DownloadStatus.queued);
    _queue.add((reciter, sura));
    _changed();
    unawaited(_run());
  }

  /// Queues every sura of [reciter] not already on the phone.
  static void downloadAll(Reciter reciter) {
    for (var s = 1; s <= Constants.suraDataLists.length; s++) {
      download(reciter, s);
    }
  }

  /// Stops [reciterId]'s downloads after the files in flight. What finished
  /// stays, and a later download picks up from there.
  static void cancel(String reciterId) {
    _cancelled.add(reciterId);
    _queue.removeWhere((j) => j.$1.id == reciterId);
    _jobs.removeWhere((k, v) => k.startsWith('$reciterId:') && v.status == DownloadStatus.queued);
    _changed();
  }

  static Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final (reciter, sura) = _queue.removeAt(0);
        await _downloadSura(reciter, sura);
      }
    } finally {
      _running = false;
    }
  }

  static Future<void> _downloadSura(Reciter reciter, int sura) async {
    final key = _key(reciter.id, sura);
    await ready();
    final dir = _dirOf(reciter);
    final files = filesFor(sura);
    var done = 0;
    void report(DownloadStatus status) {
      _jobs[key] = SuraDownload(status, done: done, total: files.length);
      _changed();
    }

    try {
      if (dir == null) throw const FileSystemException('No storage for recitations');
      dir.createSync(recursive: true);
      report(DownloadStatus.downloading);
      final pending = [for (final f in files) if (localPath(reciter, f.$1, f.$2) == null) f];
      done = files.length - pending.length;
      report(DownloadStatus.downloading);

      for (var i = 0; i < pending.length; i += _parallel) {
        if (_cancelled.contains(reciter.id)) {
          _jobs.remove(key);
          _changed();
          return;
        }
        final batch = pending.skip(i).take(_parallel);
        await Future.wait([
          for (final (s, a) in batch) _fetch(reciter.urlForVerse(s, a), File('${dir.path}/${_name(s, a)}')),
        ]);
        done += batch.length;
        report(DownloadStatus.downloading);
      }
      await _mark(reciter.id, sura, true);
      _jobs.remove(key);
      _changed();
    } catch (e) {
      debugPrint('Download of ${reciter.id} sura $sura failed: $e');
      report(DownloadStatus.failed);
    }
  }

  /// Saves [url] to [file], via a temporary name so a cut connection never
  /// leaves a truncated file that would look complete.
  static Future<void> _fetch(String url, File file) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
          throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
        }
        final part = File('${file.path}.part');
        await part.writeAsBytes(response.bodyBytes, flush: true);
        await part.rename(file.path);
        return;
      } catch (e) {
        if (attempt >= 3) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }
  }

  /// Removes [sura] of [reciter], keeping Al-Fatiha 1:1 while another
  /// downloaded sura still needs it for its basmala.
  static Future<void> delete(Reciter reciter, int sura) async {
    await ready();
    final dir = _dirOf(reciter);
    if (dir == null) return;
    await _mark(reciter.id, sura, false);
    final keepBasmala = downloaded(reciter.id).isNotEmpty;
    for (final (s, a) in filesFor(sura)) {
      if (keepBasmala && s == 1 && a == 1) continue;
      final f = File('${dir.path}/${_name(s, a)}');
      if (f.existsSync()) await f.delete();
    }
    _jobs.remove(_key(reciter.id, sura));
    _changed();
  }

  /// Removes every saved file of [reciter].
  static Future<void> deleteAll(Reciter reciter) async {
    cancel(reciter.id);
    await ready();
    final dir = _dirOf(reciter);
    if (dir != null && dir.existsSync()) await dir.delete(recursive: true);
    await LocalStorageServices.setStringList(PrefsKeys.recitationDownloads(reciter.id), const []);
    _jobs.removeWhere((k, _) => k.startsWith('${reciter.id}:'));
    _changed();
  }

  /// Space [reciter]'s files take on the phone, in bytes.
  static Future<int> bytesOnDisk(Reciter reciter) async {
    await ready();
    final dir = _dirOf(reciter);
    if (dir == null || !dir.existsSync()) return 0;
    var total = 0;
    await for (final f in dir.list()) {
      if (f is File) total += await f.length();
    }
    return total;
  }
}
