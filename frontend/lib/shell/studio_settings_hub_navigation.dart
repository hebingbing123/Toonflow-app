import 'package:flutter/foundation.dart';

/// One-shot settings hub tab index when opening account/settings from deep routes.
class StudioSettingsHubNavigation {
  StudioSettingsHubNavigation._();

  static int? _pendingTabIndex;
  static bool _openSubscribe = false;
  static bool _checkoutSuccess = false;
  static VoidCallback? _openSubscribeHandler;

  /// Product shell registers this to navigate to settings + subscribe UI.
  static void registerOpenSubscribeHandler(VoidCallback? handler) {
    _openSubscribeHandler = handler;
  }

  static void requestTab(int index) {
    _pendingTabIndex = index.clamp(0, 3);
  }

  /// Plan & usage tab in [SettingsHubPage].
  static void requestPlanTab({bool openSubscribe = false, bool checkoutSuccess = false}) {
    requestTab(1);
    _openSubscribe = openSubscribe;
    _checkoutSuccess = checkoutSuccess;
  }

  /// API & models tab in [SettingsHubPage].
  static void requestApiModelsTab() => requestTab(2);

  static void openSubscribe({bool checkoutSuccess = false}) {
    requestPlanTab(openSubscribe: true, checkoutSuccess: checkoutSuccess);
    _openSubscribeHandler?.call();
  }

  static int consumePending({required int fallback}) {
    final pending = _pendingTabIndex;
    _pendingTabIndex = null;
    return pending ?? fallback;
  }

  static bool consumeOpenSubscribe() {
    final v = _openSubscribe;
    _openSubscribe = false;
    return v;
  }

  static bool consumeCheckoutSuccess() {
    final v = _checkoutSuccess;
    _checkoutSuccess = false;
    return v;
  }
}
