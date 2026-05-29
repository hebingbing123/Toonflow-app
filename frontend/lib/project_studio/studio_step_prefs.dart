import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'studio_step.dart';

abstract final class StudioStepPrefs {
  static final ValueNotifier<int> _changeTick = ValueNotifier<int>(0);

  /// Bumps when any project saves a new last step (projects home can refresh).
  static ValueListenable<int> get changes => _changeTick;

  static String _key(int projectNumericId) =>
      'studio_last_step_$projectNumericId';

  static Future<StudioStep> loadLastStep(int projectNumericId) async {
    final prefs = await SharedPreferences.getInstance();
    return StudioStep.fromSlug(prefs.getString(_key(projectNumericId)));
  }

  static Future<Map<int, StudioStep?>> loadLastSteps(
    Iterable<int> projectNumericIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <int, StudioStep?>{};
    for (final id in projectNumericIds) {
      final slug = prefs.getString(_key(id));
      map[id] = slug == null || slug.isEmpty ? null : StudioStep.fromSlug(slug);
    }
    return map;
  }

  static Future<void> saveLastStep(
    int projectNumericId,
    StudioStep step,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(projectNumericId), step.slug);
    _changeTick.value++;
  }
}
