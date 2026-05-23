import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

/// Shared MaterialApp wrapper for UI gallery goldens (zh, bundled fonts).
Widget studioGoldenApp({
  required Widget child,
  Size? surfaceSize,
}) {
  Widget body = child;
  if (surfaceSize != null) {
    body = MediaQuery(
      data: MediaQueryData(size: surfaceSize),
      child: body,
    );
  }
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildStudioDarkTheme(useBundledFonts: true),
    home: Scaffold(body: body),
  );
}
