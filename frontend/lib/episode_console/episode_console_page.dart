import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';

/// Compact episode deliver console (preview): assembly embed only.
class EpisodeConsolePage extends StatelessWidget {
  const EpisodeConsolePage({
    super.key,
    required this.projectNumericId,
    required this.scriptNumericId,
    required this.deliverChild,
    required this.onOpenFullStudio,
  });

  final int projectNumericId;
  final int scriptNumericId;
  final Widget deliverChild;
  final VoidCallback onOpenFullStudio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: tokens.bgBase,
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/$projectNumericId/deliver');
            }
          },
        ),
        title: Text(
          l10n.studioEpisodeConsoleTitle(scriptNumericId),
          style: studioProjectTitleStyle(context),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: StudioSpacing.xs),
            child: StudioChip(
              label: Text(l10n.studioEpisodeConsoleBetaLabel),
            ),
          ),
          TextButton(
            onPressed: onOpenFullStudio,
            child: Text(l10n.studioOpenFullStudio),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: tokens.bgSurface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.radiusComfort, StudioSpacing.sm, StudioSpacing.radiusComfort),
              child: Text(
                l10n.studioEpisodeConsoleBetaBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: StudioTokens.of(context).textSecondary,
                ),
              ),
            ),
          ),
          Expanded(child: deliverChild),
        ],
      ),
    );
  }
}
