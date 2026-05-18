import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/studio_adaptive_theme.dart';
import '../l10n/app_localizations.dart';
import '../locale/app_locale_notifier.dart';
import '../platform/rust_api_feedback.dart';
import 'router.dart';
import 'studio_theme.dart';

/// MaterialApp.router for Studio product shell.
class StudioProductApp extends StatefulWidget {
  const StudioProductApp({super.key});

  @override
  State<StudioProductApp> createState() => _StudioProductAppState();
}

class _StudioProductAppState extends State<StudioProductApp> {
  late final GoRouter _router = createStudioRouter();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocaleNotifier.instance,
      builder: (context, _) {
        return MaterialApp.router(
          onGenerateTitle: (ctx) =>
              AppLocalizations.of(ctx)?.appTitle ??
              lookupAppLocalizations(const Locale('en')).appTitle,
          locale: AppLocaleNotifier.instance.localeOrNull,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) {
              return supportedLocales.first;
            }
            for (final supported in supportedLocales) {
              if (supported.languageCode == locale.languageCode) {
                return supported;
              }
            }
            return supportedLocales.first;
          },
          scaffoldMessengerKey: kRustApiRootScaffoldMessengerKey,
          theme: StudioTheme.build(),
          routerConfig: _router,
          builder: (context, child) {
            final adaptiveTheme = studioAdaptiveDesktopTheme(context);
            return Theme(data: adaptiveTheme, child: child ?? const SizedBox());
          },
        );
      },
    );
  }
}
