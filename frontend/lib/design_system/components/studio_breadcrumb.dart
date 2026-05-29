import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

/// One segment in [StudioBreadcrumb].
class StudioBreadcrumbSegment {
  const StudioBreadcrumbSegment({
    required this.label,
    this.onTap,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final String? semanticLabel;
}

/// Horizontal breadcrumb trail with optional navigation.
class StudioBreadcrumb extends StatelessWidget {
  const StudioBreadcrumb({
    super.key,
    required this.segments,
    this.separator = '/',
    this.maxVisible = 5,
  });

  final List<StudioBreadcrumbSegment> segments;
  final String separator;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final visible = _collapseSegments(segments, maxVisible);
    return Semantics(
      container: true,
      label: l10n.studioDesignBreadcrumbSemanticsLabel,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: StudioSpacing.xs,
        runSpacing: StudioSpacing.xs,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Text(
                separator,
                style: studioHintStyle(context)?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            _SegmentChip(segment: visible[i], isLast: i == visible.length - 1),
          ],
        ],
      ),
    );
  }

  static List<StudioBreadcrumbSegment> _collapseSegments(
    List<StudioBreadcrumbSegment> segments,
    int maxVisible,
  ) {
    if (segments.length <= maxVisible) {
      return segments;
    }
    return [
      segments.first,
      const StudioBreadcrumbSegment(label: '…'),
      ...segments.sublist(segments.length - (maxVisible - 2)),
    ];
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.segment,
    required this.isLast,
  });

  final StudioBreadcrumbSegment segment;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final style = isLast
        ? Theme.of(context).textTheme.labelLarge?.copyWith(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w600,
          )
        : studioHintStyle(context)?.copyWith(color: tokens.textSecondary);
    final child = Text(segment.label, style: style, maxLines: 1);
    if (segment.onTap == null || isLast || segment.label == '…') {
      return Semantics(
        label: segment.semanticLabel ?? segment.label,
        child: child,
      );
    }
    return Semantics(
      label: segment.semanticLabel ?? segment.label,
      button: true,
      child: InkWell(
        onTap: segment.onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: child,
        ),
      ),
    );
  }
}
