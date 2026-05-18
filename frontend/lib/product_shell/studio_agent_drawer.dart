import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';

/// Right-side agent drawer (Wave 5).
Future<void> showStudioAgentDrawer(
  BuildContext context, {
  required Future<void> Function(String agentKind) onRunAgent,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'agent-drawer',
    barrierColor: StudioTokens.dark.overlay,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim1, anim2) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: StudioTokens.of(ctx).bgElevated,
          child: SizedBox(
            width: 400,
            child: SafeArea(
              child: _StudioAgentDrawerBody(onRunAgent: onRunAgent),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _StudioAgentDrawerBody extends StatelessWidget {
  const _StudioAgentDrawerBody({required this.onRunAgent});

  final Future<void> Function(String agentKind) onRunAgent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final agents = <(String, String, IconData)>[
      (
        'script_rewriter',
        l10n.studioAgentRewriteScript,
        Icons.edit_note_outlined,
      ),
      ('extractor', l10n.studioAgentExtractEntities, Icons.hub_outlined),
      (
        'storyboard_breaker',
        l10n.studioAgentBreakStoryboard,
        Icons.view_quilt_outlined,
      ),
      (
        'voice_assigner',
        l10n.studioAgentAssignVoices,
        Icons.record_voice_over_outlined,
      ),
      (
        'grid_prompt_generator',
        l10n.studioAgentGridPrompts,
        Icons.grid_on_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Text(
                l10n.studioAgentDrawerTitle,
                style: studioDialogTitleStyle(context),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: agents
                .map(
                  (a) => ListTile(
                    leading: Icon(a.$3),
                    title: Text(a.$2),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await onRunAgent(a.$1);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}
