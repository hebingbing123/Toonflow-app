/// One-shot settings hub tab index when opening account/settings from deep routes.
class StudioSettingsHubNavigation {
  StudioSettingsHubNavigation._();

  static int? _pendingTabIndex;

  static void requestTab(int index) {
    _pendingTabIndex = index.clamp(0, 3);
  }

  /// API & models tab in [SettingsHubPage].
  static void requestApiModelsTab() => requestTab(2);

  static int consumePending({required int fallback}) {
    final pending = _pendingTabIndex;
    _pendingTabIndex = null;
    return pending ?? fallback;
  }
}
