import 'package:shared_preferences/shared_preferences.dart';

/// Dismisses the domestic vendor first-run banner on Settings → API & models.
class DomesticVendorSetupPrefs {
  DomesticVendorSetupPrefs._();

  static const _dismissedKey = 'studio_domestic_vendor_setup_dismissed_v1';
  static const _homeNudgeShownKey = 'studio_domestic_vendor_home_nudge_shown_v1';
  static const _aiNudgeShownKey = 'studio_domestic_vendor_ai_nudge_shown_v1';

  static Future<bool> isDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissedKey) ?? false;
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  static Future<bool> wasHomeNudgeShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_homeNudgeShownKey) ?? false;
  }

  static Future<void> markHomeNudgeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeNudgeShownKey, true);
  }

  static Future<bool> wasAiNudgeShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aiNudgeShownKey) ?? false;
  }

  static Future<void> markAiNudgeShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiNudgeShownKey, true);
  }

  static Future<void> clearDismissedForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedKey);
    await prefs.remove(_homeNudgeShownKey);
    await prefs.remove(_aiNudgeShownKey);
  }
}
