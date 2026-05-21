import 'package:flutter/material.dart';

import 'studio_toast.dart';
import 'studio_toast_overlay.dart';

/// Root [ScaffoldMessenger] that routes all [SnackBar]s to [StudioToastOverlay].
class StudioScaffoldMessenger extends ScaffoldMessenger {
  const StudioScaffoldMessenger({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => StudioScaffoldMessengerState();
}

class StudioScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final message = studioToastMessageFromSnackBarContent(snackBar.content);
    if (message != null && message.isNotEmpty && mounted) {
      final tone = _toneFromSnackBar(snackBar);
      showStudioToast(
        context,
        message: message,
        tone: tone,
        duration: snackBar.duration,
        actionLabel: snackBar.action?.label,
        onAction: snackBar.action?.onPressed,
      );
    }
    final controller = super.showSnackBar(
      _invisibleSnackBar(snackBar.duration),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
    hideCurrentSnackBar();
    return controller;
  }

  StudioToastTone _toneFromSnackBar(SnackBar snackBar) {
    final bg = snackBar.backgroundColor;
    if (bg != null) {
      if (bg.computeLuminance() < 0.25) {
        return StudioToastTone.error;
      }
    }
    return StudioToastTone.info;
  }

  SnackBar _invisibleSnackBar(Duration duration) {
    return SnackBar(
      content: const SizedBox.shrink(),
      duration: duration,
      behavior: SnackBarBehavior.fixed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
    );
  }
}
