import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

/// Batch file / export transfer progress row.
class StudioTransferProgress extends StatelessWidget {
  const StudioTransferProgress({
    super.key,
    required this.label,
    required this.progress,
    this.detail,
    this.onCancel,
    this.cancelLabel,
    this.indeterminate = false,
  });

  final String label;
  final double progress;
  final String? detail;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final bool indeterminate;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final cancel = cancelLabel ?? l10n.studioDesignTransferCancel;
    final clamped = progress.clamp(0.0, 1.0);
    final percentLabel = indeterminate
        ? '…'
        : '${(clamped * 100).round()}%';

    return Semantics(
      label: '$label $percentLabel',
      value: indeterminate ? null : '${(clamped * 100).round()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: studioControlLabelStyle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                percentLabel,
                style: studioHintStyle(context),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: StudioSpacing.xs),
                TextButton(
                  onPressed: onCancel,
                  child: Text(cancel),
                ),
              ],
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
          indeterminate
              ? const LinearProgressIndicator(minHeight: 2)
              : LinearProgressIndicator(
                  minHeight: 2,
                  value: clamped,
                  color: tokens.primary,
                  backgroundColor: tokens.bgInset,
                ),
          if (detail != null) ...[
            const SizedBox(height: StudioSpacing.xs),
            Text(detail!, style: studioHintStyle(context)),
          ],
        ],
      ),
    );
  }
}

/// Stack of [StudioTransferProgress] rows for multi-file uploads.
class StudioTransferProgressList extends StatelessWidget {
  const StudioTransferProgressList({
    super.key,
    required this.items,
  });

  final List<StudioTransferProgressItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          StudioTransferProgress(
            label: items[i].label,
            progress: items[i].progress,
            detail: items[i].detail,
            indeterminate: items[i].indeterminate,
            onCancel: items[i].onCancel,
            cancelLabel: items[i].cancelLabel,
          ),
          if (i < items.length - 1)
            const SizedBox(height: StudioSpacing.sm),
        ],
      ],
    );
  }
}

class StudioTransferProgressItem {
  const StudioTransferProgressItem({
    required this.label,
    required this.progress,
    this.detail,
    this.onCancel,
    this.cancelLabel,
    this.indeterminate = false,
  });

  final String label;
  final double progress;
  final String? detail;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final bool indeterminate;
}
