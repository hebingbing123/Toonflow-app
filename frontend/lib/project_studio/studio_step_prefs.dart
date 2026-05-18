import 'package:shared_preferences/shared_preferences.dart';

import 'studio_step.dart';

abstract final class StudioStepPrefs {
  static String _key(int projectNumericId) =>
      'studio_last_step_$projectNumericId';

  static Future<StudioStep> loadLastStep(int projectNumericId) async {
    final prefs = await SharedPreferences.getInstance();
    return StudioStep.fromSlug(prefs.getString(_key(projectNumericId)));
  }

  static Future<void> saveLastStep(
    int projectNumericId,
    StudioStep step,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectNumericId), step.slug);
  }
}
