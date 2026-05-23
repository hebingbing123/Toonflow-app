import 'package:flutter/material.dart';

import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/rust_api_error_format.dart';
import '../../rust_api/core.dart';

bool studioApiErrorShouldOfferRetry(Object error) {
  if (error is RustApiException) {
    final status = error.statusCode;
    if (status == 408 || status == 429 || (status != null && status >= 500)) {
      return true;
    }
    final parsed = RustApiErrorDetails.tryParse(error.message)?.code;
    return parsed == 'timeout' || parsed == 'database_error';
  }
  return true;
}

enum StudioApiErrorCalloutEmphasis { prominent, subtle }

/// Inline error with human-readable message and optional retry (Studio product path).
class StudioApiErrorCallout extends StatelessWidget {
  const StudioApiErrorCallout({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showDiagnostic = false,
    this.emphasis = StudioApiErrorCalloutEmphasis.prominent,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDiagnostic;
  final StudioApiErrorCalloutEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final errorColor = theme.colorScheme.error;
    final message = error is String
        ? compactUserVisibleApiErrorText(l10n, error as String)
        : describeUserVisibleApiErrorResolved(context, error);
    final canRetry = onRetry != null && studioApiErrorShouldOfferRetry(error);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final subtle = emphasis == StudioApiErrorCalloutEmphasis.subtle;
        final dismissButton = IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 18),
          color: tokens.textSecondary,
          tooltip: l10n.studioDismiss,
          visualDensity: VisualDensity.standard,
          constraints: const BoxConstraints(
            minWidth: StudioSpacing.iconTouchTarget,
            minHeight: StudioSpacing.iconTouchTarget,
          ),
        );
        final retryButton = TextButton.icon(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: errorColor,
            minimumSize: const Size(
              StudioSpacing.iconTouchTarget,
              StudioSpacing.iconTouchTarget,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: subtle ? 10 : 12,
              vertical: subtle ? 8 : 10,
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 14),
          label: Text(l10n.studioRetry),
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: errorColor.withValues(alpha: subtle ? 0.18 : 0.28),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                (subtle ? tokens.bgInset : tokens.bgSurface).withValues(
                  alpha: subtle ? 0.98 : 0.97,
                ),
                Color.lerp(
                  subtle ? tokens.bgInset : tokens.bgElevated,
                  errorColor,
                  subtle ? 0.04 : 0.08,
                )!.withValues(alpha: 0.96),
              ],
            ),
            boxShadow: subtle
                ? const <BoxShadow>[]
                : <BoxShadow>[
                    BoxShadow(
                      color: errorColor.withValues(alpha: 0.09),
                      blurRadius: 18,
                      spreadRadius: -14,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: subtle ? 10 : 12,
                bottom: subtle ? 10 : 12,
                child: Container(
                  width: subtle ? 1.5 : 2,
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: subtle ? 0.76 : 0.88),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  subtle ? 10 : 12,
                  subtle ? 10 : 12,
                  10,
                  subtle ? 10 : 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    subtle
                        ? Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.error_outline,
                              size: 16,
                              color: errorColor.withValues(alpha: 0.9),
                            ),
                          )
                        : Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: errorColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: errorColor.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Icon(
                              Icons.error_outline,
                              size: 16,
                              color: errorColor,
                            ),
                          ),
                    const SizedBox(width: StudioLayoutSpacing.inlineGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  l10n.studioApiErrorCalloutTitle,
                                  style:
                                      (subtle
                                              ? theme.textTheme.labelMedium
                                              : theme.textTheme.labelLarge)
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                ),
                              ),
                              if (compact && onDismiss != null) dismissButton,
                              if (!compact && (canRetry || onDismiss != null))
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (canRetry) retryButton,
                                    if (onDismiss != null) dismissButton,
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: showDiagnostic
                                ? null
                                : (compact ? (subtle ? 2 : 3) : 2),
                            overflow: showDiagnostic
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style:
                                (subtle
                                        ? theme.textTheme.labelMedium
                                        : theme.textTheme.bodySmall)
                                    ?.copyWith(
                                      color: subtle
                                          ? tokens.textSecondary
                                          : tokens.textPrimary,
                                      height: subtle ? 1.3 : 1.35,
                                    ),
                          ),
                          if (showDiagnostic) ...<Widget>[
                            const SizedBox(height: 8),
                            SelectableText(
                              error.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: tokens.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ],
                          if (compact && canRetry) ...<Widget>[
                            const SizedBox(height: 8),
                            retryButton,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
