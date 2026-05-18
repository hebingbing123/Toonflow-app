import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';

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
      return Chip(
        label: Text(l10n.studioCostEstimateLoading),
        visualDensity: VisualDensity.compact,
      );
    }
    if (error != null) {
      return Chip(
        label: Text(error!, maxLines: 2),
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.errorContainer,
      );
    }
    final est = estimate;
    if (est == null) return const SizedBox.shrink();

    final cny = formatCnyFromCents(est.cnyCents);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        Chip(
          label: Text(l10n.studioCostEstimateLine(est.credits, cny)),
          visualDensity: VisualDensity.compact,
        ),
        if (est.quotaImpactJobs > 0)
          Chip(
            label: Text(l10n.studioCostEstimateQuota(est.quotaImpactJobs)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
