import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// macOS / Windows / Linux native notification bridge (19.3).
abstract final class StudioDesktopNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get isSupported =>
      !kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static Future<void> ensureInitialized() async {
    if (_ready || !isSupported) {
      return;
    }
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const init = InitializationSettings(
      macOS: darwin,
      linux: linux,
    );
    await _plugin.initialize(init);
    if (Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    }
    _ready = true;
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_ready) {
      await ensureInitialized();
    }
    if (!_ready) {
      return;
    }
    const details = NotificationDetails(
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    await _plugin.show(
      DateTime.now().microsecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      details,
    );
  }
}
