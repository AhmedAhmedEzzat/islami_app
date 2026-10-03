import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/prefs_keys.dart';
import '../services/quran_meta.dart';
import '../services/shared_prefs_helper.dart';

@immutable
class Bookmark {
  const Bookmark(this.verse, this.savedAt);

  final VerseRef verse;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'v': verse.key,
    't': savedAt.millisecondsSinceEpoch,
  };

  static Bookmark? fromJson(Map<String, dynamic> json) {
    final verse = VerseRef.parse(json['v'] as String? ?? '');
    final t = json['t'] as int?;
    if (verse == null || t == null) return null;
    return Bookmark(verse, DateTime.fromMillisecondsSinceEpoch(t));
  }
}

/// Verse bookmarks, newest first, persisted as one JSON list.
class BookmarksCubit extends Cubit<List<Bookmark>> {
  BookmarksCubit() : super(const []);

  void load() {
    final raw = LocalStorageServices.getString(PrefsKeys.bookmarks);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .whereType<Bookmark>()
          .toList();
      emit(list);
    } catch (e) {
      // A corrupt value must not take the Quran screen down with it.
      debugPrint('Ignoring unreadable bookmarks: $e');
    }
  }

  bool isBookmarked(VerseRef verse) => state.any((b) => b.verse == verse);

  /// Adds the bookmark, or removes it if it exists. Returns true if added.
  Future<bool> toggle(VerseRef verse, {DateTime? now}) async {
    final added = !isBookmarked(verse);
    final next = added
        ? [Bookmark(verse, now ?? DateTime.now()), ...state]
        : state.where((b) => b.verse != verse).toList();
    emit(next);
    await LocalStorageServices.setString(
      PrefsKeys.bookmarks,
      jsonEncode(next.map((b) => b.toJson()).toList()),
    );
    return added;
  }

  Set<int> versesIn(int sura) =>
      {for (final b in state) if (b.verse.sura == sura) b.verse.ayah};
}
