import 'package:flutter/material.dart';

import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_icon_button.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_entrance_motion.dart';
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
    barrierColor: StudioTokens.of(context).overlay,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim1, anim2) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpacing.md, StudioSpacing.md, StudioSpacing.md, StudioSpacing.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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

    return StudioDialogFrame(
      maxWidth: 400,
      maxHeightFactor: 0.92,
      insetPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StudioAgentDrawerHeader(title: l10n.studioAgentDrawerTitle),
          const Divider(height: StudioControlSize.dividerThickness),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(StudioSpacing.sm),
              itemBuilder: (context, index) {
                final agent = agents[index];
                return studioStaggeredItem(
                  index,
                  entranceKey: agents.length,
                  child: _StudioAgentActionTile(
                    icon: agent.$3,
                    label: agent.$2,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await onRunAgent(agent.$1);
                    },
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(height: StudioSpacing.xs + 2),
              itemCount: agents.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioAgentDrawerHeader extends StatelessWidget {
  const _StudioAgentDrawerHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StudioSpacing.sm,
        StudioSpacing.sm,
        StudioSpacing.xs,
        StudioSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: studioDialogTitleStyle(context)),
          ),
          StudioIconButton(
            icon: Icons.close,
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            size: StudioIconSize.md,
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: tokens.bgSurface.withValues(alpha: 0.78),
              foregroundColor: tokens.textSecondary,
              minimumSize: const Size(
                StudioSpacing.iconTouchTarget,
                StudioSpacing.iconTouchTarget,
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
                side: BorderSide(color: tokens.surfaceHighlight),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioAgentActionTile extends StatelessWidget {
  const _StudioAgentActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Material(
      color: StudioPrimitives.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: tokens.bgInset.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            border: Border.all(color: tokens.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: StudioSpacing.sm,
            vertical: 18,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: tokens.signal, size: 30),
              const SizedBox(width: StudioSpacing.sm),
              Expanded(
                child: Text(label, style: studioPaneTitleStyle(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
