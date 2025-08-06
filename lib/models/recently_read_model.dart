class RecentlyReadModel {
  final String suraId;
  final String suraNameEn;
  final String suraNameAr;
  final int verseCount;

  RecentlyReadModel({
    required this.suraId,
    required this.suraNameEn,
    required this.suraNameAr,
    required this.verseCount,
  });

  Map<String, dynamic> toJson() => {
    'suraId': suraId,
    'suraNameEn': suraNameEn,
    'suraNameAr': suraNameAr,
    'verseCount': verseCount,
  };

  factory RecentlyReadModel.fromJson(Map<String, dynamic> json) {
    return RecentlyReadModel(
      suraId: json['suraId'],
      suraNameEn: json['suraNameEn'],
      suraNameAr: json['suraNameAr'],
      verseCount: json['verseCount'],
    );
  }
}
