import 'package:flutter/material.dart';

import 'studio_repaint_boundary.dart';
import '../tokens.dart';

/// Simple horizontal bar chart for ranked metrics (17.2).
class StudioBarChart extends StatelessWidget {
  const StudioBarChart({
    super.key,
    required this.entries,
    this.maxBarHeight = 72,
    this.semanticsLabel,
  });

  final List<StudioBarChartEntry> entries;
  final double maxBarHeight;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxValue = entries
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1.0, double.infinity);
    final label =
        semanticsLabel ?? 'Bar chart, ${entries.length} categories';

    return Semantics(
      label: label,
      child: StudioRepaintBoundary(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (var i = 0; i < entries.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: StudioSpacing.xs),
              Expanded(
                child: _BarColumn(
                  entry: entries[i],
                  maxValue: maxValue,
                  maxBarHeight: maxBarHeight,
                  barColor: tokens.primary,
                  mutedColor: tokens.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudioBarChartEntry {
  const StudioBarChartEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.entry,
    required this.maxValue,
    required this.maxBarHeight,
    required this.barColor,
    required this.mutedColor,
  });

  final StudioBarChartEntry entry;
  final double maxValue;
  final double maxBarHeight;
  final Color barColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final height = maxBarHeight * (entry.value / maxValue);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: '${entry.label} ${entry.value.round()}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            ),
          ),
        ),
        const SizedBox(height: StudioSpacing.chromeActionGap),
        Text(
          entry.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: mutedColor,
              ),
        ),
      ],
    );
  }
}
