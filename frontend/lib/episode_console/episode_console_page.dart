import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
