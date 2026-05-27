import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rust_api/core.dart';

/// Product-wide demo / guided-tour mode with in-memory mock data (no backend writes).
class ProductDemoMode extends ChangeNotifier {
  ProductDemoMode._();

  static final ProductDemoMode instance = ProductDemoMode._();

  static const guestAccessToken = 'product-demo-guest-v1';
  static const _prefsEnabledKey = 'product_demo_mode_enabled_v1';
  static const _prefsGuestKey = 'product_demo_mode_guest_v1';

  bool _enabled = false;
  bool _guest = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get isActive => _enabled;
  bool get isGuestDemo => _enabled && _guest;

  /// When true, product controllers must not call live Rust/HTTP APIs.
  bool get shouldSkipLiveApi => _enabled;

  static bool isDemoGuestAccessToken(String? token) {
    final trimmed = token?.trim();
    return trimmed != null &&
        trimmed.isNotEmpty &&
        trimmed == guestAccessToken;
  }

  /// Suppress JWT / 401 noise when tour mode uses the guest token.
  static bool shouldSuppressDemoApiError(Object error) {
    if (!instance.shouldSkipLiveApi) {
      return false;
    }
    if (error is RustApiException) {
      if (error.statusCode == 401) {
        return true;
      }
      final code = RustApiErrorDetails.tryParse(error.message)?.code;
      if (code == 'invalid_token' || code == 'unauthorized') {
        return true;
      }
    }
    final text = error.toString().toLowerCase();
    return text.contains('jwt') ||
        text.contains('invalid_token') ||
        text.contains('invalid token');
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nextEnabled = prefs.getBool(_prefsEnabledKey) ?? false;
    final nextGuest = prefs.getBool(_prefsGuestKey) ?? false;
    final changed =
        !_loaded || _enabled != nextEnabled || _guest != nextGuest;
    _enabled = nextEnabled;
    _guest = nextGuest;
    _loaded = true;
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> enable({bool guest = false}) async {
    _enabled = true;
    _guest = guest;
    _loaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, true);
    await prefs.setBool(_prefsGuestKey, guest);
  }

  Future<void> disable() async {
    _enabled = false;
    _guest = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, false);
    await prefs.setBool(_prefsGuestKey, false);
    notifyListeners();
  }
}
