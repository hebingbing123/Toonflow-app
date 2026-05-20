import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

/// Numbered checklist for first-run empty states (projects home, etc.).
class StudioGettingStartedSteps extends StatelessWidget {
  const StudioGettingStartedSteps({
    super.key,
    required this.steps,
    this.maxWidth = 420,
  });

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var i = 0; i < steps.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 12),
                Semantics(
                  label: l10n.studioGettingStartedStepSemantics(
                    i + 1,
                    stepTotal,
                    steps[i],
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.bgInset.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ExcludeSemantics(
                            child: Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tokens.primarySoft,
                                border: Border.all(
                                  color: tokens.primary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: theme.labelLarge?.copyWith(
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ExcludeSemantics(
                              child: Text(
                                steps[i],
                                style: studioSectionIntroStyle(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
