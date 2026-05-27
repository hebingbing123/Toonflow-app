import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
import '../../design_system/ix/studio_api_error_callout.dart';
import '../../design_system/tokens.dart';
import 'studio_text_styles.dart';
class StudioCostEstimateChip extends StatelessWidget {
  const StudioCostEstimateChip({
    super.key,
    this.estimate,
    this.loading = false,
    this.error,
  });

  final BillingEstimateResponse? estimate;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (loading) {
      return StudioChip(
        label: Text(l10n.studioCostEstimateLoading),
      );
    }
    if (error != null) {
      return StudioApiErrorCallout(
        error: error!,
        emphasis: StudioApiErrorCalloutEmphasis.subtle,
      );
    }
    final est = estimate;
    if (est == null) return const SizedBox.shrink();

    final cny = formatCnyFromCents(est.cnyCents);
    final pct = est.quotaUsagePercentAfter;
    return Wrap(
      spacing: StudioSpacing.xs,
      runSpacing: StudioSpacing.chromeActionGap,
      children: <Widget>[
        if (est.platformBillingExempt)
          StudioChip(
            label: Text(l10n.studioCostEstimateByok),
            backgroundColor: theme.colorScheme.secondaryContainer,
          )
        else
          StudioChip(
            label: Text(l10n.studioCostEstimateLine(est.credits, cny)),
            labelStyle: theme.chipTheme.labelStyle?.withTabularFigures(),
          ),
        if (est.quotaImpactJobs > 0)
          StudioChip(
            label: Text(l10n.studioCostEstimateQuota(est.quotaImpactJobs)),
            labelStyle: theme.chipTheme.labelStyle?.withTabularFigures(),
          ),
        if (pct != null && est.dailyJobQuota != null)
          StudioChip(
            label: Text(
              l10n.studioCostEstimateQuotaPercent(pct.toStringAsFixed(0)),
            ),
            labelStyle: theme.chipTheme.labelStyle?.withTabularFigures(),
          ),
      ],
    );
  }
}
