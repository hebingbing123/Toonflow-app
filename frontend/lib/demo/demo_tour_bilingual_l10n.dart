import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Zh/en [AppLocalizations] pair for building dual-track demo tour stops.
({AppLocalizations zh, AppLocalizations en}) demoTourBilingualL10n() {
  return (
    zh: lookupAppLocalizations(const Locale('zh')),
    en: lookupAppLocalizations(const Locale('en')),
  );
}
