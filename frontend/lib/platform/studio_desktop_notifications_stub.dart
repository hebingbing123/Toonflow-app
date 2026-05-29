/// Web / unsupported targets: no-op desktop notifications.
abstract final class StudioDesktopNotifications {
  static Future<void> ensureInitialized() async {}

  static bool get isSupported => false;

  static Future<void> show({
    required String title,
    required String body,
  }) async {}
}
