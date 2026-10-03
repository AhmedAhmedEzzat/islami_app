import 'sura_data_model.dart';

/// Route argument for opening a sura, optionally at a given verse.
///
/// The details route used to take a bare [SuraDataModel]; both shapes are
/// accepted so older call sites keep working.
class QuranOpenRequest {
  const QuranOpenRequest(this.sura, {this.ayah});

  final SuraDataModel sura;

  /// 1-based verse to open at, or null for the saved reading position.
  final int? ayah;

  static SuraDataModel? suraOf(Object? args) => switch (args) {
    final QuranOpenRequest r => r.sura,
    final SuraDataModel s => s,
    _ => null,
  };

  static int? ayahOf(Object? args) => args is QuranOpenRequest ? args.ayah : null;
}
