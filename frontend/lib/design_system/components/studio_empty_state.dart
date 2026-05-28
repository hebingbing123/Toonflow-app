import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/rust_api_error_format.dart';
import '../tokens.dart';
import '../studio_typography.dart';
import 'studio_surfaces.dart';
import 'studio_primary_button.dart';
import 'studio_text_styles.dart';

/// Visual weight for empty-state hero icon treatment.
enum StudioEmptyStateWeight { prominent, quiet }

/// Template for common empty-list scenarios.
enum StudioEmptyStateVariant {
  /// First-time / onboarding — guide the next step.
  firstUse,

  /// Filters or search returned nothing.
  noResults,

  /// Loaded successfully but the collection is empty.
  emptyData,
}

class StudioEmptyState extends StatelessWidget {
  const StudioEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.variant = StudioEmptyStateVariant.emptyData,
    this.weight = StudioEmptyStateWeight.prominent,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final StudioEmptyStateVariant variant;
  final StudioEmptyStateWeight weight;

  /// Onboarding-style empty state with a primary CTA.
  factory StudioEmptyState.firstUse({
    Key? key,
    required String title,
    String? subtitle,
    IconData icon = Icons.rocket_launch_outlined,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return StudioEmptyState(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      variant: StudioEmptyStateVariant.firstUse,
      weight: StudioEmptyStateWeight.prominent,
    );
  }

  /// Search or filter produced no matches.
  factory StudioEmptyState.noResults({
    Key? key,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return StudioEmptyState(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: Icons.search_off_outlined,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      variant: StudioEmptyStateVariant.noResults,
      weight: StudioEmptyStateWeight.quiet,
    );
  }

  /// Network or API failure with a prominent retry action.
  static Widget loadFailed(
    BuildContext context, {
    Object? error,
    required VoidCallback onRetry,
    String? title,
    String? subtitle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final message = error == null
        ? subtitle
        : error is String
        ? compactUserVisibleApiErrorText(l10n, error)
        : describeUserVisibleApiErrorResolved(context, error);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.md,
          vertical: StudioSpacing.lg,
        ),
        child: StudioEmptyState(
          title: title ?? l10n.studioLoadFailedTitle,
          subtitle: subtitle ?? message,
          icon: Icons.cloud_off_outlined,
          actionLabel: l10n.studioRetry,
          onAction: onRetry,
          variant: StudioEmptyStateVariant.emptyData,
          weight: StudioEmptyStateWeight.prominent,
        ),
      ),
    );
  }

  /// Data source is healthy but the list has no rows yet.
  factory StudioEmptyState.emptyData({
    Key? key,
    required String title,
    String? subtitle,
    IconData icon = Icons.inbox_outlined,
    String? actionLabel,
    VoidCallback? onAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return StudioEmptyState(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryAction: onSecondaryAction,
      variant: StudioEmptyStateVariant.emptyData,
      weight: StudioEmptyStateWeight.quiet,
    );
  }

  bool get _quiet =>
      weight == StudioEmptyStateWeight.quiet ||
      variant == StudioEmptyStateVariant.noResults;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final typography = StudioTypography.of(context);
    final glowAlpha = _quiet ? 0.08 : 0.14;
    final ringAlpha = _quiet ? 0.05 : 0.10;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _quiet ? 520 : 560),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actionWidth = constraints.maxWidth < 280
                ? constraints.maxWidth
                : math.min(constraints.maxWidth, 220.0);
            return DecoratedBox(
              decoration:
                  studioInsetPanelDecoration(
                    context,
                    backgroundColor: tokens.bgSurface.withValues(
                      alpha: _quiet ? 0.88 : 0.94,
                    ),
                  ).copyWith(
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: studioShadowColor(
                          context,
                          alpha: _quiet ? 0.16 : 0.22,
                        ),
                        blurRadius: 18,
                        spreadRadius: -12,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth < 420
                      ? StudioSpacing.sm + 4
                      : StudioLayoutSpacing.insetComfortable,
                  vertical: _quiet ? StudioSpacing.md : StudioSpacing.md + 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      width: _quiet ? 76 : 92,
                      height: _quiet ? 76 : 92,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          if (!_quiet)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: <Color>[
                                    tokens.accent.withValues(alpha: glowAlpha),
                                    tokens.primary.withValues(
                                      alpha: glowAlpha * 0.35,
                                    ),
                                    tokens.bgInset.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          Container(
                            width: _quiet ? 60 : 72,
                            height: _quiet ? 60 : 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tokens.surfaceHighlight.withValues(
                                  alpha: _quiet ? 0.65 : 0.9,
                                ),
                              ),
                              color: tokens.bgSurface.withValues(alpha: 0.96),
                              boxShadow: _quiet
                                  ? null
                                  : <BoxShadow>[
                                      BoxShadow(
                                        color: tokens.primary.withValues(
                                          alpha: ringAlpha,
                                        ),
                                        blurRadius: 12,
                                        spreadRadius: -8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: Container(
                                width: _quiet ? 36 : 42,
                                height: _quiet ? 36 : 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _quiet
                                      ? tokens.primarySoft
                                      : tokens.primary,
                                ),
                                child: Icon(
                                  icon,
                                  size: _quiet ? 20 : 22,
                                  color: _quiet
                                      ? tokens.primary
                                      : Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.sm),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style:
                          (subtitle != null || _quiet
                                  ? studioPaneTitleStyle(context)
                                  : studioPageTitleStyle(context))
                              ?.copyWith(letterSpacing: 0),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: studioHintStyle(context)?.copyWith(
                            color: tokens.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                    if ((actionLabel != null && onAction != null) ||
                        (secondaryActionLabel != null &&
                            onSecondaryAction != null)) ...<Widget>[
                      const SizedBox(height: StudioLayoutSpacing.section),
                      Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: StudioSpacing.sm,
                        runSpacing: StudioSpacing.xs,
                        children: <Widget>[
                          if (actionLabel != null && onAction != null)
                            SizedBox(
                              width: actionWidth,
                              child: StudioPrimaryButton(
                                label: actionLabel!,
                                onPressed: onAction,
                              ),
                            ),
                          if (secondaryActionLabel != null &&
                              onSecondaryAction != null)
                            SizedBox(
                              width: actionWidth,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: typography.buttonPadding,
                                  minimumSize: Size(0, typography.buttonHeight),
                                  visualDensity: VisualDensity.standard,
                                ),
                                onPressed: onSecondaryAction,
                                child: Text(
                                  secondaryActionLabel!,
                                  textAlign: TextAlign.center,
                                  softWrap: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
