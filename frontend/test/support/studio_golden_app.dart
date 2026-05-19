import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

/// Shared MaterialApp wrapper for UI gallery goldens (zh, no network fonts).
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
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
    ),
    home: Scaffold(body: body),
  );
}
