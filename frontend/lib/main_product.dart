import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'design_system/google_fonts_runtime.dart';
import 'locale/app_locale_notifier.dart';
import 'product_shell/studio_app.dart';
import 'status_page.dart';

/// Studio product entry (alias of [main.dart]).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppLocaleNotifier.instance.load();
  configureGoogleFontsRuntime();

  if (kSupabaseConfigured) {
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: effectiveSupabaseAnonKey,
    );
  }

  if (shouldOpenStatusPageForInitialUri(Uri.base)) {
    runApp(MaterialApp(home: StatusPage()));
    return;
  }

  runApp(const StudioProductApp());
}
