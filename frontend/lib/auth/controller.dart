import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

typedef AuthL10nProvider = AppLocalizations? Function();

class AuthController extends ChangeNotifier {
  AuthController({
    required this.onErrorChanged,
    required this.onSignedOut,
    required AuthL10nProvider l10nProvider,
  }) : _l10nProvider = l10nProvider {
    if (kDebugMode && kSupabaseConfigured) {
      if (emailController.text.trim().isEmpty) {
        emailController.text = kDevAdminEmail;
      }
      if (passwordController.text.isEmpty) {
        passwordController.text = kDevAdminPassword;
      }
    }
  }

  final void Function(String? error) onErrorChanged;
  final Future<void> Function() onSignedOut;
  final AuthL10nProvider _l10nProvider;

  AppLocalizations get _l10nResolved =>
      _l10nProvider() ?? lookupAppLocalizations(const Locale('en'));

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  StreamSubscription<AuthState>? _authSub;

  Session? get session =>
      kSupabaseConfigured ? Supabase.instance.client.auth.currentSession : null;
  bool get signedIn => session != null;

  void attachAuthListener() {
    if (!kSupabaseConfigured) return;
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  Future<void> signIn() async {
    onErrorChanged(null);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on AuthException catch (error) {
      onErrorChanged(error.message);
    } catch (error) {
      onErrorChanged(
        describeUserVisibleApiError(_l10nResolved, error),
      );
    }
  }

  Future<void> signUp() async {
    onErrorChanged(null);
    try {
      await Supabase.instance.client.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on AuthException catch (error) {
      onErrorChanged(error.message);
    } catch (error) {
      onErrorChanged(
        describeUserVisibleApiError(_l10nResolved, error),
      );
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    await onSignedOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
