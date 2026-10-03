/// Helpers for cleaning the bundled Arabic text assets.
abstract class ArabicText {
  /// [value] in Arabic-Indic digits: 12 → ١٢.
  static String digits(int value) => value
      .toString()
      .split('')
      .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
      .join();

  /// Code points that carry no glyph but do reach the text layout engine:
  /// the UTF-8 BOM (present at the start of all 114 sura files), zero-width
  /// spaces/joiners, and the bidirectional override marks. Left in place they
  /// render as stray boxes or silently flip the direction of a line.
  static bool _isInvisible(int codeUnit) {
    return codeUnit == 0xFEFF || // BOM / zero-width no-break space
        (codeUnit >= 0x200B && codeUnit <= 0x200F) || // ZWSP..RLM
        (codeUnit >= 0x202A && codeUnit <= 0x202E); // bidi embedding/override
  }

  static String stripInvisible(String input) {
    return String.fromCharCodes(
      input.codeUnits.where((unit) => !_isInvisible(unit)),
    );
  }

  /// Splits [raw] into trimmed, non-empty lines with newlines normalised.
  ///
  /// This is the single place that decides what counts as a line of content,
  /// so verse splitting and hadeth splitting cannot drift apart.
  static List<String> toLines(String raw) {
    return stripInvisible(raw)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Folds Arabic so a plain typed query matches Uthmani text.
  ///
  /// A reader types `الرحمن`; the mushaf has `ٱلرَّحْمَٰنِ`. Removed: harakat
  /// and tanween, the dagger alef, tatweel, and the small Quranic annotation
  /// marks (U+06D6–U+06ED). Folded: every alef form to bare alef (including
  /// alef wasla ٱ, which a phone keyboard cannot type), ى to ي, ة to ه, and
  /// hamza carriers to their base letter.
  static String normalizeForSearch(String input) {
    final out = StringBuffer();
    for (final unit in stripInvisible(input).runes) {
      if ((unit >= 0x064B && unit <= 0x065F) || // harakat, tanween, sukun
          unit == 0x0670 || // dagger alef
          unit == 0x0640 || // tatweel
          (unit >= 0x06D6 && unit <= 0x06ED)) {
        continue;
      }
      out.writeCharCode(switch (unit) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 || 0x0672 || 0x0673 => 0x0627,
        0x0649 => 0x064A, // alef maqsura -> ya
        0x0629 => 0x0647, // ta marbuta -> ha
        0x0624 => 0x0648, // waw with hamza -> waw
        0x0626 => 0x064A, // ya with hamza -> ya
        _ => unit,
      });
    }
    // Collapse the runs of spaces the removed marks can leave behind.
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
