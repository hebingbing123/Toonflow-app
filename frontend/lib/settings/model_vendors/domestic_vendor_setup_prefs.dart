import 'package:shared_preferences/shared_preferences.dart';

/// Dismisses the domestic vendor first-run banner on Settings → API & models.
class DomesticVendorSetupPrefs {
  DomesticVendorSetupPrefs._();

  static const _dismissedKey = 'studio_domestic_vendor_setup_dismissed_v1';

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
