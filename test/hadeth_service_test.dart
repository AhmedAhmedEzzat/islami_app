import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakina/core/services/hadeth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HadethService.parse', () {
    test('takes the first line as the title and the rest as content', () {
      final hadeth = HadethService.parse('Title\nline one\nline two')!;
      expect(hadeth.title, 'Title');
      expect(hadeth.content, ['line one', 'line two']);
    });

    test('ignores the BOM and blank separator lines', () {
      final hadeth = HadethService.parse('﻿Title\n\n  \nbody\n')!;
      expect(hadeth.title, 'Title');
      expect(hadeth.content, ['body']);
    });

    test('returns null for an empty file rather than throwing', () {
      expect(HadethService.parse('   \n\n'), isNull);
    });

    test('handles a title-only file without a range error', () {
      final hadeth = HadethService.parse('Only a title')!;
      expect(hadeth.content, isEmpty);
    });
  });

  test('all 50 hadeth assets load and have a title', () async {
    for (var id = 1; id <= HadethService.hadethCount; id++) {
      final raw = await rootBundle.loadString('assets/hadeth/h$id.txt');
      final hadeth = HadethService.parse(raw);
      expect(hadeth, isNotNull, reason: 'h$id.txt parsed to nothing');
      expect(hadeth!.title.trim(), isNotEmpty, reason: 'h$id has no title');
    }
  });
}
