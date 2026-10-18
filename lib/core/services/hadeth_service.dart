import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sakina/core/utils/arabic_text.dart';
import 'package:sakina/models/hadeth_data_model.dart';

/// Loads the bundled ahadeth: An-Nawawi's Forty (1..42), Ibn Rajab's
/// additions (43..50) and the Forty Hadith Qudsi (101..140), generated into
/// one file by tool/build_content_assets.py.
abstract class HadethService {
  /// An-Nawawi's and Ibn Rajab's, numbered 1..50.
  static const int hadethCount = 50;
  static const int qudsiFirst = 101;
  static const int qudsiCount = 40;
  static const String asset = 'assets/hadeth/hadeth.json';

  static List<HadethDataModel> _cache = [];

  static List<HadethDataModel> parse(String raw) {
    final json =
        jsonDecode(ArabicText.stripInvisible(raw)) as Map<String, dynamic>;
    return [
      for (final h in json['hadeth'] as List)
        HadethDataModel.fromJson(h as Map<String, dynamic>),
    ];
  }

  static Future<List<HadethDataModel>> loadAll() async {
    if (_cache.isNotEmpty) return _cache;
    _cache = parse(await rootBundle.loadString(asset));
    return _cache;
  }

  static void clearCache() => _cache = [];
}
