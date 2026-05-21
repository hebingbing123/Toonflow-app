import 'package:flutter/material.dart';

import 'studio_toast_overlay.dart';

/// Shows a top-right glass toast. Prefer this over [ScaffoldMessenger.showSnackBar].
void showStudioToast(
  BuildContext context, {
  required String message,
  StudioToastTone tone = StudioToastTone.info,
  IconData? icon,
  Color? iconColor,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  VoidCallback? onDismiss,
}) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || !context.mounted) {
    return;
  }
  StudioToastOverlay.show(
    context,
    message: trimmed,
    tone: tone,
    icon: icon,
    iconColor: iconColor,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    onDismiss: onDismiss,
  );
}

/// Best-effort plain text from legacy [SnackBar] content widgets.
String? studioToastMessageFromSnackBarContent(Widget content) {
  if (content is Text) {
    return content.data ?? content.textSpan?.toPlainText();
  }
  if (content is SelectableText) {
    return content.data ?? content.textSpan?.toPlainText();
  }
  if (content is RichText) {
    return content.text.toPlainText();
  }
  if (content is DefaultTextStyle) {
    return studioToastMessageFromSnackBarContent(content.child);
  }
  if (content is Padding && content.child != null) {
    return studioToastMessageFromSnackBarContent(content.child!);
  }
  if (content is Row) {
    final buffer = StringBuffer();
    for (final child in content.children) {
      final t = studioToastMessageFromSnackBarContent(child);
      if (t != null && t.trim().isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(t.trim());
      }
    }
    final out = buffer.toString().trim();
    return out.isEmpty ? null : out;
  }
  if (content is Column) {
    final buffer = StringBuffer();
    for (final child in content.children) {
      final t = studioToastMessageFromSnackBarContent(child);
      if (t != null && t.trim().isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(t.trim());
      }
    }
    final out = buffer.toString().trim();
    return out.isEmpty ? null : out;
  }
  return null;
}
