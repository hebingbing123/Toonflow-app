import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../studio_typography.dart';
import '../tokens.dart';
import '../../rust_api.dart';

/// Product banner when dashboard/snapshot data may be stale (quality, panels, etc.).
class StudioFreshnessBanner extends StatelessWidget {
  const StudioFreshnessBanner({
    super.key,
    required this.meta,
    required this.onRefresh,
    this.loading = false,
  });

  final QualityDashboardMeta meta;
  final VoidCallback? onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isStale = meta.stale;
    final ageLabel = _formatAge(l10n, meta.ageSeconds);
    final refreshedLabel = meta.refreshedAt == null
        ? l10n.qualityReviewsFreshnessNever
        : _formatLocalTime(meta.refreshedAt!);

    final tokens = StudioTokens.of(context);
    final Color backgroundColor;
    final Color textColor;
    final IconData icon;
    if (isStale) {
      backgroundColor = tokens.warning.withValues(alpha: 0.14);
      textColor = tokens.warning;
      icon = Icons.warning_amber_outlined;
    } else {
      backgroundColor = tokens.success.withValues(alpha: 0.14);
      textColor = tokens.success;
      icon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: StudioSpacing.xs),
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isStale
                          ? l10n.qualityReviewsFreshnessStaleTitle
                          : l10n.qualityReviewsFreshnessFreshTitle,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.qualityReviewsFreshnessStaleBody(
                        refreshedLabel,
                        ageLabel,
                      ),
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                TextButton(
                  onPressed: loading ? null : onRefresh,
                  child: Text(
                    loading
                        ? l10n.projectsBusyProcessing
                        : l10n.qualityReviewsFreshnessRefresh,
                  ),
                ),
            ],
          ),
          _FreshnessDetails(meta: meta, textColor: textColor),
        ],
      ),
    );
  }

  static String _formatAge(AppLocalizations l10n, int? ageSeconds) {
    if (ageSeconds == null) {
      return l10n.qualityReviewsFreshnessUnknownAgeLabel;
    }
    if (ageSeconds < 60) {
      return l10n.qualityReviewsFreshnessAgeSeconds(ageSeconds);
    }
    final minutes = (ageSeconds / 60).floor();
    return l10n.qualityReviewsFreshnessAgeMinutes(minutes);
  }

  static String _formatLocalTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _FreshnessDetails extends StatefulWidget {
  const _FreshnessDetails({required this.meta, required this.textColor});

  final QualityDashboardMeta meta;
  final Color textColor;

  @override
  State<_FreshnessDetails> createState() => _FreshnessDetailsState();
}

class _FreshnessDetailsState extends State<_FreshnessDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meta = widget.meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(l10n.qualityReviewsFreshnessShowDetails),
        ),
        if (_expanded)
          SelectableText(
            l10n.qualityReviewsFreshnessTechnicalDetails(
              meta.snapshotRowCount,
              meta.sourceReviewCount,
              meta.sourceUsageCount,
              meta.staleReason ?? l10n.qualityReviewsFreshnessNone,
              meta.refreshMode,
            ),
            style: TextStyle(
              color: widget.textColor,
              fontSize: StudioTypography.of(context).meta,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }
}
