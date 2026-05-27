import 'package:flutter/material.dart';

import '../design_system/components/studio_toolbar_button.dart';
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

    return LayoutBuilder(
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
                      if (i > 0) const SizedBox(width: StudioSpacing.sm),
                      Expanded(child: children[i]),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (var i = 0; i < children.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: StudioLayoutSpacing.inlineGap),
                    children[i],
                  ],
                ],
              );
      },
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
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
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
          const SizedBox(height: StudioSpacing.xs),
          Text(
            copy.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          SizedBox(
            width: expanded ? null : double.infinity,
            child: StudioToolbarButton(
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
