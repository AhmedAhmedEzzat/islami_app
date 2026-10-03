import 'dart:convert';

import 'package:flutter/services.dart';

import '../../models/zikr_model.dart';

/// Loads Hisn al-Muslim, bundled from the official hisnmuslim.com data by
/// tool/build_content_assets.py — nothing in it is typed by hand.
abstract class AzkarService {
  static List<AzkarChapter>? _cache;

  /// Exposed for testing without a widget tree.
  static List<AzkarChapter> parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    final chapters = decoded['chapters'];
    if (chapters is! List) return const [];
    return chapters
        .whereType<Map<String, dynamic>>()
        .map(AzkarChapter.fromJson)
        .where((c) => c.items.isNotEmpty)
        .toList();
  }

  static Future<List<AzkarChapter>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    return _cache = parse(await rootBundle.loadString('assets/azkar/hisn.json'));
  }

  static Future<AzkarChapter?> chapter(int id) async {
    for (final c in await loadAll()) {
      if (c.id == id) return c;
    }
    return null;
  }

  static void clearCache() => _cache = null;
}
