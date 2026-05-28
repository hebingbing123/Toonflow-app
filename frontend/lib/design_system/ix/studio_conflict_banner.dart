import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';

/// Shown when server returns a stale [clientDataVersion] conflict.
class StudioConflictBanner extends StatelessWidget {
  const StudioConflictBanner({
    super.key,
    required this.message,
    required this.onRefresh,
    this.onDismiss,
  });

  final String message;
  final VoidCallback onRefresh;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final bodyStyle = Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.textPrimary);
        final actions = <Widget>[
          TextButton(onPressed: onRefresh, child: Text(l10n.studioRetry)),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: StudioIconSize.sm),
              onPressed: onDismiss,
              tooltip: l10n.studioDismiss,
            ),
        ];

        return Material(
          color: tokens.danger.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.sm,
              vertical: StudioSpacing.xs,
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.warning_amber_rounded,
                            color: tokens.danger,
                            size: StudioIconSize.md,
                          ),
                          const SizedBox(width: StudioSpacing.sm),
                          Expanded(child: Text(message, style: bodyStyle)),
                        ],
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Wrap(
                        spacing: StudioSpacing.xs,
                        runSpacing: StudioSpacing.xs,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.warning_amber_rounded,
                        color: tokens.danger,
                        size: StudioIconSize.md,
                      ),
                      const SizedBox(width: StudioSpacing.sm),
                      Expanded(child: Text(message, style: bodyStyle)),
                      const SizedBox(width: StudioSpacing.sm),
                      Wrap(
                        spacing: StudioSpacing.xs,
                        runSpacing: StudioSpacing.xs,
                        alignment: WrapAlignment.end,
                        children: actions,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
