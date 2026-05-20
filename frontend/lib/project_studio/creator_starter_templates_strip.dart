import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'creator_starter_templates.dart';

/// Prominent one-tap creator templates on the script step (T6).
class CreatorStarterTemplatesStrip extends StatelessWidget {
  const CreatorStarterTemplatesStrip({
    super.key,
    required this.starters,
    required this.onApply,
  });

  final List<ProjectHomeStarterTemplate> starters;
  final ValueChanged<ProjectHomeStarterTemplate> onApply;

  @override
  Widget build(BuildContext context) {
    if (starters.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioCreatorStartersTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.studioCreatorStartersSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final useRow = width >= 720 && starters.length > 1;
              final children = starters
                  .map(
                    (starter) => _StarterCard(
                      starter: starter,
                      copy: creatorStarterLocalizedCopy(l10n, starter),
                      applyLabel: l10n.studioCreatorStarterApply,
                      onApply: onApply,
                      expanded: useRow,
                    ),
                  )
                  .toList(growable: false);

              if (useRow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var i = 0; i < children.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: children[i]),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < children.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 10),
                    children[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({
    required this.starter,
    required this.copy,
    required this.applyLabel,
    required this.onApply,
    required this.expanded,
  });

  final ProjectHomeStarterTemplate starter;
  final CreatorStarterCopy copy;
  final String applyLabel;
  final ValueChanged<ProjectHomeStarterTemplate> onApply;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: expanded ? null : double.infinity,
            child: StudioPrimaryButton(
              icon: Icons.bolt_rounded,
              label: applyLabel,
              onPressed: () => onApply(starter),
            ),
          ),
        ],
      ),
    );
  }
}
