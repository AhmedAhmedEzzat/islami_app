/// Which book a bundled hadeth belongs to.
enum HadethCollection { nawawi, ibnRajab, qudsi }

class HadethDataModel {
  HadethDataModel({
    required this.title,
    required this.content,
    this.number = 0,
    this.english,
    this.collection = HadethCollection.nawawi,
  });

  /// One entry of `assets/hadeth/hadeth.json` (see tool/build_content_assets.py).
  factory HadethDataModel.fromJson(Map<String, dynamic> json) =>
      HadethDataModel(
        number: json['n'] as int,
        title: json['title'] as String,
        content: [for (final p in json['ar'] as List) p as String],
        english: json['en'] as String?,
        collection: switch (json['c']) {
          'ibn_rajab' => HadethCollection.ibnRajab,
          'qudsi' => HadethCollection.qudsi,
          _ => HadethCollection.nawawi,
        },
      );

  final String title;

  /// The Arabic text, one entry per paragraph.
  final List<String> content;

  /// The English translation, where the source has one.
  final String? english;

  final HadethCollection collection;

  /// Its number in the book (1..42 An-Nawawi, 43..50 Ibn Rajab), a stable id
  /// for favourites.
  final int number;

  String get fullText => [
    title,
    '',
    ...content,
    if (english != null) ...['', english!],
  ].join('\n');
}
