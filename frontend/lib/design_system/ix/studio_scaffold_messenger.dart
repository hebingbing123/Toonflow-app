import 'package:flutter/material.dart';

import 'studio_toast.dart';
import 'studio_toast_overlay.dart';
import '../tokens.dart';

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
    clearSnackBars();

    final message = studioToastMessageFromSnackBarContent(snackBar.content);
    final duration = snackBar.duration;
    if (message != null && message.isNotEmpty && mounted) {
      showStudioToast(
        context,
        message: message,
        tone: _toneFromSnackBar(snackBar),
        duration: duration,
        actionLabel: snackBar.action?.label,
        onAction: snackBar.action?.onPressed,
      );
    }

    // Never paint a bottom [SnackBar] bar — satisfy the messenger API off-screen only.
    return super.showSnackBar(
      SnackBar(
        content: const SizedBox.shrink(),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        width: 1,
        margin: const EdgeInsets.only(left: 100000, bottom: 100000),
        padding: EdgeInsets.zero,
        backgroundColor: StudioPrimitives.transparent,
        elevation: 0,
        clipBehavior: Clip.none,
      ),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
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
}
