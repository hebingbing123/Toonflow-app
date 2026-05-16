import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Resolves optional [l10n] (e.g. controller callbacks before first frame) to a
/// concrete [AppLocalizations] without embedding English literals in call sites.
AppLocalizations qualityReviewsResolveL10n(AppLocalizations? l10n) =>
    l10n ?? lookupAppLocalizations(const Locale('en'));
