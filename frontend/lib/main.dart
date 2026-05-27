import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bootstrap/global_error_handling.dart';
import 'config.dart';
import 'design_system/google_fonts_runtime.dart';
import 'design_system/ix/studio_mobile_affordances.dart';
import 'locale/app_locale_notifier.dart';
import 'native_bridge/native_bridge_bootstrap.dart';
import 'product_shell/studio_app.dart';
import 'status_page.dart';

/// Default entry: Studio product shell. Harness: `flutter run -t lib/main_harness.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureGlobalErrorHandling();

  await AppLocaleNotifier.instance.load();
  configureGoogleFontsRuntime();
  await NativeBridgeBootstrap.instance.ensureStarted();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  if (kSupabaseConfigured) {
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: effectiveSupabaseAnonKey,
    );
  }

  if (shouldOpenStatusPageForInitialUri(Uri.base)) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StatusPage(),
        builder: (context, child) {
          return StudioSystemUiSurface(child: child ?? const SizedBox.shrink());
        },
      ),
    );
    return;
  }

  runApp(const StudioProductApp());
}
