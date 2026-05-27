import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// Numbered checklist for first-run empty states (projects home, etc.).
class StudioGettingStartedSteps extends StatelessWidget {
  const StudioGettingStartedSteps({
    super.key,
    this.title,
    required this.steps,
    this.maxWidth = 420,
  });

  final String? title;
  final List<String> steps;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final stepTotal = steps.length;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: DecoratedBox(
            decoration: studioInsetPanelDecoration(
              context,
              backgroundColor: tokens.bgSurface.withValues(alpha: 0.92),
            ),
            child: Padding(
              padding: const EdgeInsets.all(
                StudioLayoutSpacing.insetComfortable,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (title != null && title!.isNotEmpty) ...<Widget>[
                    Text(title!, style: studioPaneTitleStyle(context)),
                    const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                  ],
                  for (var i = 0; i < steps.length; i++) ...<Widget>[
                    Semantics(
                      label: l10n.studioGettingStartedStepSemantics(
                        i + 1,
                        stepTotal,
                        steps[i],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ExcludeSemantics(
                            child: Column(
                              children: <Widget>[
                                Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: StudioLayoutSize.wizardStepBadge,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tokens.primarySoft,
                                    border: Border.all(
                                      color: tokens.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      '${i + 1}',
                                      style: theme.labelLarge?.copyWith(
                                        color: tokens.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                if (i != steps.length - 1)
                                  Container(
                                    width: 1,
                                    height: 22,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: StudioLayoutSpacing.microGap,
                                    ),
                                    color: tokens.borderSubtle,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: StudioLayoutSpacing.stackMedium),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
                              child: ExcludeSemantics(
                                child: Text(
                                  steps[i],
                                  style: studioSectionIntroStyle(context)
                                      ?.copyWith(
                                        color: tokens.textPrimary,
                                        height: 1.45,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i != steps.length - 1)
                      const SizedBox(height: StudioSpacing.xs),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
