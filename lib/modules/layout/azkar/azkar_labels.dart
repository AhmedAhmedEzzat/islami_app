import 'package:material_ui/material_ui.dart';

import '../../../core/constants/azkar_titles_en.dart';
import '../../../core/services/azkar_service.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../models/zikr_model.dart';

/// The name to show for a chapter: the app's own for the favourites and the
/// featured chapters; otherwise the book's Arabic title, or for readers in
/// English what the chapter is for.
String azkarTitle(BuildContext context, AzkarChapter chapter) {
  final l10n = context.l10n;
  return switch (chapter.id) {
    AzkarService.favouritesId => l10n.favourites,
    FeaturedAzkar.morningEvening => l10n.azkarMorningEvening,
    FeaturedAzkar.sleep => l10n.azkarSleep,
    FeaturedAzkar.waking => l10n.azkarWaking,
    FeaturedAzkar.afterPrayer => l10n.azkarAfterPrayer,
    FeaturedAzkar.adhan => l10n.azkarAdhan,
    FeaturedAzkar.leavingHome => l10n.azkarLeavingHome,
    FeaturedAzkar.enteringHome => l10n.azkarEnteringHome,
    FeaturedAzkar.enteringMosque => l10n.azkarEnteringMosque,
    FeaturedAzkar.distress => l10n.azkarDistress,
    FeaturedAzkar.istikhara => l10n.azkarIstikhara,
    _ =>
      context.isArabic
          ? chapter.title
          : azkarTitlesEn[chapter.id] ?? chapter.title,
  };
}

IconData azkarIcon(int chapterId) => switch (chapterId) {
  FeaturedAzkar.morningEvening => Icons.wb_twilight,
  FeaturedAzkar.sleep => Icons.bedtime_outlined,
  FeaturedAzkar.waking => Icons.wb_sunny_outlined,
  FeaturedAzkar.afterPrayer => Icons.mosque_outlined,
  FeaturedAzkar.adhan => Icons.campaign_outlined,
  FeaturedAzkar.leavingHome => Icons.logout,
  FeaturedAzkar.enteringHome => Icons.home_outlined,
  FeaturedAzkar.enteringMosque => Icons.door_front_door_outlined,
  FeaturedAzkar.distress => Icons.favorite_border,
  FeaturedAzkar.istikhara => Icons.alt_route,
  AzkarService.favouritesId => Icons.favorite,
  _ => Icons.menu_book_outlined,
};
