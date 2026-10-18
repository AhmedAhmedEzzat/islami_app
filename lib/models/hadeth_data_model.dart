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

  /// A stable id, kept for favourites: its number in the book for
  /// An-Nawawi (1..42) and Ibn Rajab (43..50), and 101..140 for the Qudsi.
  final int number;

  /// The number to show: the Qudsi count from 1 again, like their titles.
  int get numberInBook => collection == HadethCollection.qudsi ? number - 100 : number;

  String get fullText => [
    title,
    '',
    ...content,
    if (english != null) ...['', english!],
  ].join('\n');
}
