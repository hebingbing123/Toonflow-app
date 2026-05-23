import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

/// MaterialApp.router wrapper for product-shell utility route tests (no Google Fonts).
Widget productShellRouterTestApp(
  GoRouter router, {
  Size size = const Size(1440, 900),
  Locale locale = const Locale('zh'),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp.router(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildStudioDarkTheme(useBundledFonts: true),
      routerConfig: router,
    ),
  );
}
