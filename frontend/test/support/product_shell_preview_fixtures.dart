import 'dart:ui' show Locale;

import 'package:openflow_app/debug/product_shell_debug_preview.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

/// Default mock payload for product-shell overflow / route widget tests.
ProductShellDebugPreviewData buildProductShellOverflowPreviewData() {
  return ProductDemoCatalog.buildDefault(
    lookupAppLocalizations(const Locale('en')),
  );
}
