import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sakina/core/services/tafsir_service.dart';

/// An api.alquran.cloud surah response with one verse naming the request.
http.Response _ok(http.Request request) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'code': 200,
      'data': {
        'ayahs': [
          {'text': request.url.path},
        ],
      },
    }),
  ),
  200,
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('tafsir'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('downloadAll saves every sura of both tafsirs', () async {
    var requests = 0;
    TafsirService.configure(
      dir: dir,
      client: MockClient((r) async {
        requests++;
        return _ok(r);
      }),
    );
    expect(await TafsirService.savedSuras(), 0);

    final progress = <double>[];
    void listen() {
      if (TafsirService.downloadProgress.value case final p?) progress.add(p);
    }

    TafsirService.downloadProgress.addListener(listen);
    expect(await TafsirService.downloadAll(), isTrue);
    TafsirService.downloadProgress.removeListener(listen);

    expect(requests, TafsirService.suraCount * Tafsir.values.length);
    expect(await TafsirService.savedSuras(), TafsirService.suraCount);
    expect(progress.last, 1);
    expect(TafsirService.downloadProgress.value, isNull);
    expect(await TafsirService.forSura(Tafsir.jalalayn, 2), ['/v1/surah/2/ar.jalalayn']);

    // Nothing left to fetch the second time.
    expect(await TafsirService.downloadAll(), isTrue);
    expect(requests, TafsirService.suraCount * Tafsir.values.length);
  });

  test('downloadAll gives up quickly when offline and keeps what it saved', () async {
    var requests = 0;
    TafsirService.configure(
      dir: dir,
      client: MockClient((r) async {
        requests++;
        if (requests > 10) throw const SocketException('offline');
        return _ok(r);
      }),
    );
    expect(await TafsirService.downloadAll(), isFalse);
    // Three failures stop it, plus at most the ones already under way.
    expect(requests, lessThan(20));
    expect(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')), hasLength(10));
    expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
  });

  test('the same sura asked for twice at once is fetched once, for both', () async {
    var requests = 0;
    TafsirService.configure(
      dir: dir,
      client: MockClient((r) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _ok(r);
      }),
    );
    final results = await Future.wait([
      for (var i = 0; i < 6; i++) TafsirService.forSura(Tafsir.muyassar, 2),
    ]);
    expect(results, everyElement(['/v1/surah/2/ar.muyassar']));
    expect(requests, 1);
    expect(dir.listSync().where((f) => f.path.endsWith('.part')), isEmpty);
  });

  test('cancel stops the run and deleteAll clears the cache', () async {
    TafsirService.configure(
      dir: dir,
      client: MockClient((r) async {
        TafsirService.cancel();
        return _ok(r);
      }),
    );
    expect(await TafsirService.downloadAll(), isNull);
    expect(await TafsirService.savedSuras(), lessThan(TafsirService.suraCount));
    expect(dir.listSync(), isNotEmpty);

    await TafsirService.deleteAll();
    expect(dir.listSync(), isEmpty);
    expect(await TafsirService.savedSuras(), 0);
  });
}
