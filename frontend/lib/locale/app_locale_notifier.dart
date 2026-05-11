import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocalePrefKey = 'openflow_app_locale';

/// `system` | `en` | `zh`. Persisted for explicit user choice ([I2.9]).
class AppLocaleNotifier extends ChangeNotifier {
  AppLocaleNotifier._();
  static final AppLocaleNotifier instance = AppLocaleNotifier._();

  String _code = 'system';

  String get code => _code;

  /// `null` means defer to device / `localeResolutionCallback`.
  Locale? get localeOrNull {
    switch (_code) {
      case 'en':
        return const Locale('en');
      case 'zh':
        return const Locale('zh');
      default:
        return null;
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLocalePrefKey);
    if (raw == null) {
      _code = 'system';
    } else if (raw == 'en' || raw == 'zh' || raw == 'system') {
      _code = raw;
    } else {
      _code = 'system';
    }
    notifyListeners();
  }

  Future<void> setLocaleCode(String code) async {
    if (code != 'en' && code != 'zh' && code != 'system') {
      return;
    }
    _code = code;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocalePrefKey, code);
  }
}
