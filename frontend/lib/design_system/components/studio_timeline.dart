import 'package:flutter/material.dart';

import '../tokens.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// One event on a [StudioTimeline].
class StudioTimelineEntry {
  const StudioTimelineEntry({
    required this.timeLabel,
    required this.title,
    this.subtitle,
    this.body,
    this.icon,
    this.accentColor,
  });

  final String timeLabel;
  final String title;
  final String? subtitle;
  final Widget? body;
  final IconData? icon;
  final Color? accentColor;
}

/// Vertical timeline with time markers and event cards.
class StudioTimeline extends StatelessWidget {
  const StudioTimeline({
    super.key,
    required this.entries,
    this.dense = false,
  });

  final List<StudioTimelineEntry> entries;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            tokens: tokens,
            dense: dense,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.tokens,
    required this.dense,
    required this.isLast,
  });

  final StudioTimelineEntry entry;
  final StudioTokens tokens;
  final bool dense;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final accent = entry.accentColor ?? tokens.primary;
    final gutter = dense ? 48.0 : 56.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: gutter,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.bgSurface, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: tokens.borderSubtle,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : StudioSpacing.md,
              ),
              child: DecoratedBox(
                decoration: studioInsetPanelDecoration(context),
                child: Padding(
                  padding: const EdgeInsets.all(StudioSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (entry.icon != null) ...[
                            Icon(entry.icon, size: 16, color: accent),
                            const SizedBox(width: StudioSpacing.xs),
                          ],
                          Text(
                            entry.timeLabel,
                            style: studioHintStyle(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        entry.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (entry.subtitle != null) ...[
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          entry.subtitle!,
                          style: studioHintStyle(context),
                        ),
                      ],
                      if (entry.body != null) ...[
                        const SizedBox(height: StudioSpacing.xs),
                        entry.body!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
