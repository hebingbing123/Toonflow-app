import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_icon_button.dart';

/// Simple prev/next pagination control.
class StudioPagination extends StatelessWidget {
  const StudioPagination({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
    this.previousLabel,
    this.nextLabel,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;
  final String? previousLabel;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final prevLabel = previousLabel ?? l10n.studioDesignPaginationPrevious;
    final nextLabelText = nextLabel ?? l10n.studioDesignPaginationNext;
    final safePage = page.clamp(0, pageCount > 0 ? pageCount - 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioIconButton(
          icon: Icons.chevron_left_rounded,
          label: prevLabel,
          onPressed: safePage > 0 ? () => onPageChanged(safePage - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
          child: Text(
            '${safePage + 1} / ${pageCount.clamp(1, pageCount)}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ),
        StudioIconButton(
          icon: Icons.chevron_right_rounded,
          label: nextLabelText,
          onPressed: safePage < pageCount - 1
              ? () => onPageChanged(safePage + 1)
              : null,
        ),
      ],
    );
  }
}
