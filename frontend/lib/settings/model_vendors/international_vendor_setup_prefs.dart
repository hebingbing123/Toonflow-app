import 'package:shared_preferences/shared_preferences.dart';

class InternationalVendorSetupPrefs {
  InternationalVendorSetupPrefs._();

  static const _dismissedKey = 'studio_intl_vendor_setup_dismissed_v1';

  static Future<bool> isDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  static Future<void> clearDismissedForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
  }
}
