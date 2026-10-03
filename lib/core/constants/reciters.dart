/// A Quran reciter whose recitation can be streamed one verse at a time.
class Reciter {
  const Reciter({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.folder,
  });

  final String id;
  final String nameEn;
  final String nameAr;

  /// Directory on everyayah.com holding `SSSAAA.mp3` for every verse.
  final String folder;

  static const String _host = 'https://everyayah.com/data';

  /// Verse-level audio is what lets the app highlight the verse being recited
  /// and turn the mushaf page as recitation moves on.
  String urlForVerse(int sura, int ayah) {
    final s = sura.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$_host/$folder/$s$a.mp3';
  }

  /// The basmala recited before every sura except Al-Fatiha (where it is the
  /// first verse) and At-Tawbah. everyayah has no separate basmala file, so
  /// the reciter's own Al-Fatiha 1:1 is used, as most apps do.
  String get basmalaUrl => urlForVerse(1, 1);
}

/// Every reciter listed here was checked to serve both 001001.mp3 and
/// 114006.mp3. Add one only after checking the same.
abstract final class Reciters {
  static const List<Reciter> all = [
    // The first two ids are kept from the earlier sura-level reciters so a
    // saved preference still resolves.
    Reciter(
      id: 'alafasy',
      nameEn: 'Mishary Rashid Alafasy',
      nameAr: 'مشاري راشد العفاسي',
      folder: 'Alafasy_128kbps',
    ),
    Reciter(
      id: 'abdulbasit',
      nameEn: 'Abdul Basit Abdul Samad',
      nameAr: 'عبد الباسط عبد الصمد',
      folder: 'Abdul_Basit_Murattal_192kbps',
    ),
    Reciter(
      id: 'husary',
      nameEn: 'Mahmoud Khalil Al-Husary',
      nameAr: 'محمود خليل الحصري',
      folder: 'Husary_128kbps',
    ),
    Reciter(
      id: 'minshawi',
      nameEn: 'Mohamed Siddiq Al-Minshawi',
      nameAr: 'محمد صديق المنشاوي',
      folder: 'Minshawy_Murattal_128kbps',
    ),
    Reciter(
      id: 'muaiqly',
      nameEn: 'Maher Al-Muaiqly',
      nameAr: 'ماهر المعيقلي',
      folder: 'MaherAlMuaiqly128kbps',
    ),
    Reciter(
      id: 'sudais',
      nameEn: 'Abdurrahman As-Sudais',
      nameAr: 'عبد الرحمن السديس',
      folder: 'Abdurrahmaan_As-Sudais_192kbps',
    ),
    Reciter(
      id: 'shuraim',
      nameEn: 'Saud Al-Shuraim',
      nameAr: 'سعود الشريم',
      folder: 'Saood_ash-Shuraym_128kbps',
    ),
    Reciter(
      id: 'ghamdi',
      nameEn: 'Saad Al-Ghamdi',
      nameAr: 'سعد الغامدي',
      folder: 'Ghamadi_40kbps',
    ),
    Reciter(
      id: 'dosari',
      nameEn: 'Yasser Al-Dosari',
      nameAr: 'ياسر الدوسري',
      folder: 'Yasser_Ad-Dussary_128kbps',
    ),
    Reciter(
      id: 'shatri',
      nameEn: 'Abu Bakr Ash-Shatri',
      nameAr: 'أبو بكر الشاطري',
      folder: 'Abu_Bakr_Ash-Shaatree_128kbps',
    ),
    Reciter(
      id: 'qatami',
      nameEn: 'Nasser Al-Qatami',
      nameAr: 'ناصر القطامي',
      folder: 'Nasser_Alqatami_128kbps',
    ),
    Reciter(
      id: 'hudhaifi',
      nameEn: 'Ali Al-Hudhaifi',
      nameAr: 'علي الحذيفي',
      folder: 'Hudhaify_128kbps',
    ),
  ];

  static Reciter byId(String id) {
    return all.firstWhere((r) => r.id == id, orElse: () => all.first);
  }
}
