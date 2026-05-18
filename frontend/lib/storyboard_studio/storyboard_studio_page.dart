import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_studio/grid_storyboard_panel.dart';

/// Full-screen storyboard editing chrome (Wave 4).
class StoryboardStudioPage extends StatelessWidget {
  const StoryboardStudioPage({
    super.key,
    required this.projectNumericId,
    required this.onOpenProductionWorkspace,
  });

  final int projectNumericId;
  final VoidCallback onOpenProductionWorkspace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/$projectNumericId/script');
            }
          },
        ),
        title: Text(
          l10n.studioStoryboardStudioTitle,
          style: studioProjectTitleStyle(context),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              // ignore: avoid_print
            },
            child: Text(l10n.studioKeyboardShortcuts),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: ColoredBox(
              color: tokens.bgInset,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  Text(
                    l10n.studioStoryboardShotList,
                    style: studioPaneTitleStyle(context),
                  ),
                  const SizedBox(height: 8),
                  ...List<Widget>.generate(
                    6,
                    (i) => ListTile(
                      dense: true,
                      title: Text(l10n.studioStoryboardShotLabel(i + 1)),
                      onTap: onOpenProductionWorkspace,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.view_compact_outlined,
                          size: 64,
                          color: tokens.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.studioStoryboardStudioBody,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        StudioPrimaryButton(
                          label: l10n.studioStepOpenProduction,
                          onPressed: onOpenProductionWorkspace,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridStoryboardPanel(
                    onGenerateGrid: onOpenProductionWorkspace,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 280,
            child: ColoredBox(
              color: tokens.bgSurface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    l10n.studioStoryboardProperties,
                    style: studioPaneTitleStyle(context),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.studioStoryboardPropertiesHint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
