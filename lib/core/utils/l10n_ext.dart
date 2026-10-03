import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// True when the UI is currently in Arabic, used to pick which of a model's
  /// two stored names to show as the primary one.
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}
