import 'package:flutter/material.dart';

import 'studio_toast.dart';
import 'studio_toast_overlay.dart';

/// Top-right glass toast (legacy name kept for call sites).
void showStudioSnackBar(
  BuildContext context, {
  required String message,
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  VoidCallback? onDismiss,
}) {
  showStudioToast(
    context,
    message: message,
    tone: StudioToastTone.info,
    icon: icon,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    onDismiss: onDismiss,
  );
}
