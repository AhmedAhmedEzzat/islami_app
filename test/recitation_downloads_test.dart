import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakina/core/constants/reciters.dart';
import 'package:sakina/core/services/recitation_downloads.dart';
import 'package:sakina/core/services/shared_prefs_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reciter = Reciters.all.first;
  late Directory root;
  late List<String> requested;

  /// Serves a few bytes for every verse, or fails the ones in [broken].
  void serve({Set<String> broken = const {}}) {
    requested = [];
    RecitationDownloads.configure(
      root: root,
      client: MockClient((request) async {
        final name = request.url.pathSegments.last;
        requested.add(name);
        if (broken.contains(name)) return http.Response('', 404);
        return http.Response.bytes(List.filled(16, 7), 200);
      }),
    );
  }

  Future<void> settle() async {
    while (RecitationDownloads.isBusy(reciter.id)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageServices.init();
    root = await Directory.systemTemp.createTemp('recitations');
  });

  tearDown(() => root.delete(recursive: true));

  test('a sura needs its verses and, except Al-Fatiha and At-Tawbah, the basmala', () {
    expect(RecitationDownloads.filesFor(1), [for (var a = 1; a <= 7; a++) (1, a)]);
    expect(RecitationDownloads.filesFor(9).first, (9, 1));
    expect(RecitationDownloads.filesFor(112), [(1, 1), (112, 1), (112, 2), (112, 3), (112, 4)]);
  });

  test('downloading a sura saves every verse and marks it done', () async {
    serve();
    RecitationDownloads.download(reciter, 112);
    await settle();
    expect(RecitationDownloads.isDownloaded(reciter.id, 112), isTrue);
    for (var a = 1; a <= 4; a++) {
      expect(RecitationDownloads.localPath(reciter, 112, a), isNotNull);
    }
    expect(RecitationDownloads.localPath(reciter, 1, 1), isNotNull, reason: 'the basmala');
    expect(root.listSync(recursive: true).where((f) => f.path.endsWith('.part')), isEmpty);
  });

  test('a failed file fails the sura without marking it, and a retry resumes', () async {
    serve(broken: {'112003.mp3'});
    RecitationDownloads.download(reciter, 112);
    await settle();
    expect(RecitationDownloads.isDownloaded(reciter.id, 112), isFalse);
    expect(RecitationDownloads.jobFor(reciter.id, 112)?.status, DownloadStatus.failed);

    final before = RecitationDownloads.localPath(reciter, 112, 1);
    serve();
    RecitationDownloads.download(reciter, 112);
    await settle();
    expect(RecitationDownloads.isDownloaded(reciter.id, 112), isTrue);
    // The broken verse and the batch after it; never the files already saved.
    expect(requested, unorderedEquals(['112003.mp3', '112004.mp3']));
    expect(before, isNotNull);
  });

  test('deleting a sura keeps the basmala another sura still needs', () async {
    serve();
    RecitationDownloads.download(reciter, 112);
    RecitationDownloads.download(reciter, 113);
    await settle();
    await RecitationDownloads.delete(reciter, 112);
    expect(RecitationDownloads.isDownloaded(reciter.id, 112), isFalse);
    expect(RecitationDownloads.localPath(reciter, 112, 1), isNull);
    expect(RecitationDownloads.localPath(reciter, 1, 1), isNotNull);

    await RecitationDownloads.deleteAll(reciter);
    expect(RecitationDownloads.downloaded(reciter.id), isEmpty);
    expect(await RecitationDownloads.bytesOnDisk(reciter), 0);
  });

  test('cancel drops what is still queued', () async {
    serve();
    RecitationDownloads.download(reciter, 112);
    RecitationDownloads.download(reciter, 113);
    RecitationDownloads.download(reciter, 114);
    RecitationDownloads.cancel(reciter.id);
    await settle();
    expect(RecitationDownloads.isDownloaded(reciter.id, 114), isFalse);
  });
}
