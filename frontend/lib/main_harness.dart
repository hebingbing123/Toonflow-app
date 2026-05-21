import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'design_system/ix/studio_scaffold_messenger.dart';
import 'design_system/ix/studio_toast_overlay.dart';
import 'design_system/google_fonts_runtime.dart';
import 'home_page.dart';
import 'l10n/app_localizations.dart';
import 'locale/app_locale_notifier.dart';
import 'native_bridge/native_bridge_bootstrap.dart';
import 'platform/rust_api_feedback.dart';
import 'shell/home_shell_mode.dart';
import 'status_page.dart';
import 'global_search/search_results_page.dart';

/// QA / developer Harness entry (probe panels, debug navigation).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocaleNotifier.instance.load();
  configureGoogleFontsRuntime();
  await NativeBridgeBootstrap.instance.ensureStarted();

  if (kSupabaseConfigured) {
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: effectiveSupabaseAnonKey,
    );
  }

  runApp(const OpenFlowHarnessApp());
}

class OpenFlowHarnessApp extends StatelessWidget {
  const OpenFlowHarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final home = shouldOpenStatusPageForInitialUri(Uri.base)
        ? StatusPage()
        : const HomePage(shellMode: HomeShellMode.harness);
    return ListenableBuilder(
      listenable: AppLocaleNotifier.instance,
      builder: (context, _) {
        return StudioScaffoldMessenger(
          key: kRustApiRootScaffoldMessengerKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
              useMaterial3: true,
            ),
            builder: (context, child) =>
                StudioToastHost(child: child ?? const SizedBox.shrink()),
            home: home,
            routes: {
              '/search': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                final query = args?['query'] as String? ?? '';
                final accessToken = kSupabaseConfigured
                    ? Supabase.instance.client.auth.currentSession?.accessToken
                    : null;
                return SearchResultsPage(
                  query: query,
                  accessToken: accessToken,
                );
              },
            },
          ),
        );
      },
    );
  }
}
