import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'home_page.dart';
import 'l10n/app_localizations.dart';
import 'locale/app_locale_notifier.dart';
import 'platform/rust_api_feedback.dart';
import 'status_page.dart';
import 'global_search/search_results_page.dart';

bool shouldOpenStatusPageForInitialUri(Uri uri) {
  final path = uri.path.trim();
  return path == '/status' || path == '/status/';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocaleNotifier.instance.load();

  if (kSupabaseConfigured) {
    await Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey);
  }

  runApp(const OpenFlowApp());
}

class OpenFlowApp extends StatelessWidget {
  const OpenFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final home = shouldOpenStatusPageForInitialUri(Uri.base)
        ? const StatusPage()
        : const HomePage();
    return ListenableBuilder(
      listenable: AppLocaleNotifier.instance,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (ctx) =>
              AppLocalizations.of(ctx)?.appTitle ?? 'OpenFlow',
          locale: AppLocaleNotifier.instance.localeOrNull,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          scaffoldMessengerKey: kRustApiRootScaffoldMessengerKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
          ),
          home: home,
          routes: {
            '/search': (context) {
              // Extract query from route arguments
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              final query = args?['query'] as String? ?? '';

              // Get access token from Supabase session
              final accessToken = kSupabaseConfigured
                  ? Supabase.instance.client.auth.currentSession?.accessToken
                  : null;

              return SearchResultsPage(query: query, accessToken: accessToken);
            },
          },
        );
      },
    );
  }
}
