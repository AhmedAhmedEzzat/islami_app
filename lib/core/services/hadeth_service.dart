import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sakina/core/utils/arabic_text.dart';
import 'package:sakina/models/hadeth_data_model.dart';

/// Loads the 50 bundled ahadeth.
///
/// Previously these were read one-at-a-time inside the view, and a single
/// unreadable file aborted the whole loop, leaving the user with an empty
/// carousel. Now each file is read independently and in parallel, so one bad
/// file costs one hadeth instead of all of them.
abstract class HadethService {
  static const int hadethCount = 50;

  static List<HadethDataModel> _cache = [];

  static HadethDataModel? parse(String raw, {int number = 0}) {
    final lines = ArabicText.toLines(raw);

    if (lines.isEmpty) return null;

    return HadethDataModel(
      number: number,
      title: lines.first,
      content: lines.sublist(1),
    );
  }

  static Future<List<HadethDataModel>> loadAll() async {
    if (_cache.isNotEmpty) return _cache;

    final results = await Future.wait(
      List.generate(hadethCount, (i) async {
        final id = i + 1;
        try {
          return parse(
            await rootBundle.loadString('assets/hadeth/h$id.txt'),
            number: id,
          );
        } catch (e) {
          debugPrint('Could not load hadeth h$id: $e');
          return null;
        }
      }),
    );

    _cache = results.whereType<HadethDataModel>().toList();
    return _cache;
  }

  static void clearCache() => _cache = [];
}
