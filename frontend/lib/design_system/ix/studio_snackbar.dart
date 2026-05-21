import 'package:flutter/material.dart';

import '../studio_typography.dart';
import '../tokens.dart';

/// Themed floating snackbar aligned with studio dark chrome (avoids default M3 light bar).
void showStudioSnackBar(
  BuildContext context, {
  required String message,
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final tokens = StudioTokens.of(context);
  final typography = StudioTypography.of(context);
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.bgElevated,
      elevation: 12,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioLayoutSpacing.stackMedium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.borderDefault),
      ),
      duration: duration,
      showCloseIcon: true,
      closeIconColor: tokens.textMuted,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: tokens.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: typography.body,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              onPressed: onAction,
              textColor: tokens.accent,
            )
          : null,
    ),
  );
}
