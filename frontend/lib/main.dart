import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'home_page.dart';
import 'platform/rust_api_feedback.dart';
import 'status_page.dart';

bool shouldOpenStatusPageForInitialUri(Uri uri) {
  final path = uri.path.trim();
  return path == '/status' || path == '/status/';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return MaterialApp(
      title: 'OpenFlow',
      scaffoldMessengerKey: kRustApiRootScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}
