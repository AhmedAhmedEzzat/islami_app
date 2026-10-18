import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/prefs_keys.dart';
import '../services/quran_meta.dart';
import '../services/shared_prefs_helper.dart';

/// The highlighter colours a verse can be marked with.
enum HighlightColor {
  yellow(Color(0xFFF6C744)),
  green(Color(0xFF5DBB63)),
  blue(Color(0xFF4FA3E0)),
  pink(Color(0xFFE57399)),
  purple(Color(0xFF9C7BD8));

  const HighlightColor(this.color);

  final Color color;
}

/// What the reader has added to one verse: a note, a highlight, or both.
@immutable
class VerseNote {
  const VerseNote(this.verse, {this.text = '', this.color, required this.updatedAt});

  final VerseRef verse;
  final String text;
  final HighlightColor? color;
  final DateTime updatedAt;

  bool get isEmpty => text.isEmpty && color == null;

  Map<String, dynamic> toJson() => {
    'v': verse.key,
    if (text.isNotEmpty) 'n': text,
    if (color != null) 'c': color!.name,
    't': updatedAt.millisecondsSinceEpoch,
  };

  static VerseNote? fromJson(Map<String, dynamic> json) {
    final verse = VerseRef.parse(json['v'] as String? ?? '');
    final t = json['t'] as int?;
    if (verse == null || t == null) return null;
    final note = VerseNote(
      verse,
      text: json['n'] as String? ?? '',
      color: HighlightColor.values.asNameMap()[json['c']],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(t),
    );
    return note.isEmpty ? null : note;
  }
}

/// The reader's notes and highlights, most recently changed first, persisted
/// as one JSON list. A verse with neither is simply not in the list.
class VerseNotesCubit extends Cubit<List<VerseNote>> {
  VerseNotesCubit() : super(const []);

  void load() {
    final raw = LocalStorageServices.getString(PrefsKeys.verseNotes);
    if (raw == null || raw.isEmpty) return;
    try {
      emit([
        for (final e in jsonDecode(raw) as List)
          if (VerseNote.fromJson(e as Map<String, dynamic>) case final note?) note,
      ]);
    } catch (e) {
      // A corrupt value must not take the Quran screen down with it.
      debugPrint('Ignoring unreadable notes: $e');
    }
  }

  VerseNote? noteFor(VerseRef verse) {
    for (final n in state) {
      if (n.verse == verse) return n;
    }
    return null;
  }

  /// Sets the note's text; empty removes it, keeping any highlight.
  Future<void> setText(VerseRef verse, String text, {DateTime? now}) {
    final old = noteFor(verse);
    return _put(VerseNote(verse, text: text.trim(), color: old?.color, updatedAt: now ?? DateTime.now()));
  }

  /// Sets the highlight; null removes it, keeping any note.
  Future<void> setColor(VerseRef verse, HighlightColor? color, {DateTime? now}) {
    final old = noteFor(verse);
    return _put(VerseNote(verse, text: old?.text ?? '', color: color, updatedAt: now ?? DateTime.now()));
  }

  Future<void> remove(VerseRef verse) =>
      _put(VerseNote(verse, updatedAt: DateTime.now()));

  /// The highlight colour of each highlighted verse of [sura], by verse.
  Map<int, Color> tintsIn(int sura) => {
    for (final n in state)
      if (n.verse.sura == sura && n.color != null) n.verse.ayah: n.color!.color,
  };

  Future<void> _put(VerseNote note) async {
    final next = [
      if (!note.isEmpty) note,
      ...state.where((n) => n.verse != note.verse),
    ];
    emit(next);
    await LocalStorageServices.setString(
      PrefsKeys.verseNotes,
      jsonEncode([for (final n in next) n.toJson()]),
    );
  }
}
