import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rust_api_error_format.dart';
import '../components/studio_icon_button.dart';
import '../components/studio_surfaces.dart';
import '../components/studio_text_styles.dart';
import '../tokens.dart';

/// Slim top-of-pane hint when the last failure looks like connectivity loss.
class StudioConnectivityBanner extends StatelessWidget {
  const StudioConnectivityBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final message = describeUserVisibleApiErrorResolved(context, error);

    return Material(
      color: tokens.warning.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioLayoutSpacing.insetDense,
          vertical: StudioSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: StudioIconSize.sm,
              color: tokens.warning,
            ),
            const SizedBox(width: StudioSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: studioSectionIntroStyle(context)?.copyWith(
                  color: tokens.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.studioRetry),
              ),
            if (onDismiss != null)
              StudioIconButton(
                icon: Icons.close,
                label: l10n.studioDismiss,
                size: StudioIconSize.sm,
                color: tokens.textSecondary,
                style: studioUtilityIconButtonStyle(context),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
