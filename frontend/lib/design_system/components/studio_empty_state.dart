import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
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
    final theme = Theme.of(context).textTheme;
    final glowAlpha = _quiet ? 0.08 : 0.14;
    final ringAlpha = _quiet ? 0.05 : 0.10;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
                            tokens.primary.withValues(alpha: glowAlpha * 0.35),
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
                          color: _quiet ? tokens.primary : Colors.white,
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
              style: theme.titleLarge?.copyWith(letterSpacing: 0),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: studioHintStyle(context)?.copyWith(height: 1.55),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: StudioLayoutSpacing.section),
              StudioPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
            if (secondaryActionLabel != null &&
                onSecondaryAction != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              TextButton(
                onPressed: onSecondaryAction,
                child: Text(secondaryActionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
