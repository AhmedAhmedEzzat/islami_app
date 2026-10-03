/// A single dhikr from Hisn al-Muslim.
class ZikrModel {
  const ZikrModel({required this.id, required this.text, required this.count});

  final int id;
  final String text;

  /// How many times it is repeated.
  final int count;

  factory ZikrModel.fromJson(Map<String, dynamic> json) {
    return ZikrModel(
      id: json['id'] as int,
      text: json['text'] as String,
      // A missing or zero count would make the counter unusable.
      count: ((json['repeat'] ?? json['count']) as int?)?.clamp(1, 1000) ?? 1,
    );
  }
}

/// One chapter of Hisn al-Muslim, e.g. "أذكار النوم".
class AzkarChapter {
  const AzkarChapter({required this.id, required this.title, required this.items});

  final int id;
  final String title;
  final List<ZikrModel> items;

  factory AzkarChapter.fromJson(Map<String, dynamic> json) {
    return AzkarChapter(
      id: json['id'] as int,
      title: (json['title'] as String).trim(),
      items: [
        for (final i in json['items'] as List)
          ZikrModel.fromJson(i as Map<String, dynamic>),
      ].where((z) => z.text.trim().isNotEmpty).toList(),
    );
  }
}

/// Chapter ids in Hisn al-Muslim that the app puts up front.
abstract final class FeaturedAzkar {
  static const int morningEvening = 27;
  static const int sleep = 28;
  static const int waking = 1;
  static const int afterPrayer = 25;
  static const int adhan = 15;
  static const int leavingHome = 10;
  static const int enteringHome = 11;
  static const int enteringMosque = 13;
  static const int distress = 34;
  static const int istikhara = 26;

  static const List<int> all = [
    morningEvening,
    sleep,
    waking,
    afterPrayer,
    adhan,
    leavingHome,
    enteringHome,
    enteringMosque,
    distress,
    istikhara,
  ];
}
