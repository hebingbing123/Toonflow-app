import 'package:flutter/material.dart';

import '../platform/studio_desktop_notifications.dart';
import '../design_system/ix/studio_toast_overlay.dart';

/// Queued in-app notifications (wraps [StudioToastOverlay]).
abstract final class StudioNotificationManager {
  static void info(BuildContext context, String message) {
    StudioToastOverlay.show(context, message: message);
  }

  static void success(BuildContext context, String message) {
    StudioToastOverlay.show(
      context,
      message: message,
      tone: StudioToastTone.success,
    );
    _maybeDesktop(message);
  }

  static void warning(BuildContext context, String message) {
    StudioToastOverlay.show(
      context,
      message: message,
      tone: StudioToastTone.warning,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
    String? retryLabel,
    bool desktopAlert = true,
  }) {
    StudioToastOverlay.show(
      context,
      message: message,
      tone: StudioToastTone.error,
      highPriority: true,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
    if (desktopAlert) {
      _maybeDesktop(message);
    }
  }

  static void _maybeDesktop(String message) {
    if (!StudioDesktopNotifications.isSupported) {
      return;
    }
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    StudioDesktopNotifications.show(
      title: 'OpenFlow Studio',
      body: trimmed.length > 180 ? '${trimmed.substring(0, 177)}…' : trimmed,
    );
  }
}
