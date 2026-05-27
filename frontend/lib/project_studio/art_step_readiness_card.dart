import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

/// Readiness score, next step, and onboarding checklist for the Art step.
class ArtStepReadinessCard extends StatelessWidget {
  const ArtStepReadinessCard({
    super.key,
    required this.home,
    required this.l10n,
    this.onChecklistItemTap,
  });

  final ProjectHome home;
  final AppLocalizations l10n;
  final ValueChanged<String>? onChecklistItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final score = home.readinessScore.clamp(0, 100);

    return DecoratedBox(
      key: const Key('studio_art_step_readiness'),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.radiusCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.projectEditorBasicsHomeSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: StudioSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      StudioSpacing.radiusDense,
                    ),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 6,
                      backgroundColor: tokens.borderSubtle,
                    ),
                  ),
                ),
                const SizedBox(width: StudioSpacing.radiusComfort),
                Text(
                  '$score%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.projectEditorBasicsHomeReadinessLine(
                home.readinessScore,
                home.readinessSummary,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            if (home.onboarding.nextStep != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.projectEditorBasicsHomeNextStep(home.onboarding.nextStep!),
                style: studioHintStyle(context),
              ),
            ],
            const SizedBox(height: StudioSpacing.sm),
            ...studioStaggeredChildren(
              home.onboarding.checklist.map(
                (item) => _ChecklistRow(
                  item: item,
                  l10n: l10n,
                  onTap: item.done || onChecklistItemTap == null
                      ? null
                      : () => onChecklistItemTap!(item.key),
                ),
              ),
              entranceKey: home.onboarding.checklist.length,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.l10n,
    this.onTap,
  });

  final ProjectHomeChecklistItem item;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final detail = item.detail?.trim();
    final tappable = onTap != null;

    final content = Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            item.done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: item.done ? tokens.success : tokens.textSecondary,
          ),
          const SizedBox(width: StudioSpacing.radiusComfort),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: item.done
                        ? tokens.textSecondary
                        : tokens.textPrimary,
                    decoration: item.done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (!item.done && detail != null && detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudioLayoutSpacing.titleTight),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tappable)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: tokens.textSecondary,
            ),
        ],
      ),
    );

    if (!tappable) {
      return content;
    }

    return Material(
      color: StudioPrimitives.transparent,
      child: InkWell(
        key: Key('studio_art_checklist_${item.key}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        child: content,
      ),
    );
  }
}
