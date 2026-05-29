import 'package:flutter/material.dart';

import '../components/studio_surfaces.dart';
import '../components/studio_text_styles.dart';
import '../tokens.dart';

/// One row in [StudioKeyboardShortcutsPanel].
class StudioKeyboardShortcutEntry {
  const StudioKeyboardShortcutEntry({
    required this.description,
    required this.keys,
  });

  final String description;
  final String keys;
}

/// Read-only shortcut reference (help hub, onboarding, module dialogs).
class StudioKeyboardShortcutsPanel extends StatelessWidget {
  const StudioKeyboardShortcutsPanel({
    super.key,
    required this.title,
    this.intro,
    required this.entries,
  });

  final String title;
  final String? intro;
  final List<StudioKeyboardShortcutEntry> entries;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: studioCardTitleStyle(context)),
            if (intro != null && intro!.isNotEmpty) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(intro!, style: studioSectionIntroStyle(context)),
            ],
            const SizedBox(height: StudioSpacing.sm),
            for (var i = 0; i < entries.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: StudioSpacing.xs),
              _ShortcutRow(
                description: entries[i].description,
                keys: entries[i].keys,
                tokens: tokens,
                theme: theme,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.description,
    required this.keys,
    required this.tokens,
    required this.theme,
  });

  final String description;
  final String keys;
  final StudioTokens tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: StudioSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: StudioSpacing.xs,
            vertical: StudioSpacing.chromeActionGap,
          ),
          decoration: BoxDecoration(
            color: tokens.bgInset,
            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Text(
            keys,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFamily: 'monospace',
              color: tokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
