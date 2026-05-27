import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';
import '../../design_system/tokens.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/components/studio_async_data_view.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
import 'value_tier_badge.dart';

/// Last 7 days spend by model from `GET /api/v1/billing/spend-summary`.
class SpendSummaryPanel extends StatefulWidget {
  const SpendSummaryPanel({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<SpendSummaryPanel> createState() => _SpendSummaryPanelState();
}

class _SpendSummaryPanelState extends State<SpendSummaryPanel> {
  bool _loading = true;
  BillingSpendSummaryResponse? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await fetchBillingSpendSummaryV1(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rows = _summary?.rows ?? const <ModelSpendRow>[];

    return StudioAsyncDataView(
      loading: _loading,
      error: _error,
      onRetry: _load,
      isEmpty: rows.isEmpty,
      empty: Text(
        l10n.studioValueTierSampleLow,
        style: theme.textTheme.bodySmall,
      ),
      child: _SpendSummaryBody(
        l10n: l10n,
        theme: theme,
        rows: rows,
      ),
    );
  }
}

class _SpendSummaryBody extends StatelessWidget {
  const _SpendSummaryBody({
    required this.l10n,
    required this.theme,
    required this.rows,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final List<ModelSpendRow> rows;

  @override
  Widget build(BuildContext context) {
    final tierMinCost = <String, int>{};
    for (final row in rows.where((r) => r.sampleSufficient)) {
      final tier = row.valueTier ?? '';
      if (tier.isEmpty) continue;
      final cost = row.estimatedCostCents;
      tierMinCost.update(tier, (v) => cost < v ? cost : v, ifAbsent: () => cost);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.studioModelPricingTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: StudioSpacing.xs),
        ...rows.toList().asMap().entries.map((entry) {
          final row = entry.value;
          final tier = row.valueTier;
          final showCheaper = row.sampleSufficient &&
              tier != null &&
              tierMinCost[tier] == row.estimatedCostCents &&
              rows.where((r) => r.valueTier == tier && r.sampleSufficient).length >
                  1;
          return studioStaggeredItem(
            entry.key,
            entranceKey: rows.length,
            child: Padding(
            padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
            child: StudioCard(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(row.modelName, style: theme.textTheme.titleSmall),
                        Text(
                          '¥${formatCnyFromCents(row.estimatedCostCents)} · ${row.callCount} calls',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (row.avgQualityScore != null)
                          Text(
                            'avg ${row.avgQualityScore!.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      ValueTierBadge(
                        valueTier: tier,
                        sampleSufficient: row.sampleSufficient,
                        showSameTierCheaper: showCheaper,
                      ),
                      if (row.tokenEfficiencyRoiBand != null &&
                          (row.tokenEfficiencySampleCount ?? 0) >= 5)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: StudioSpacing.chromeActionGap,
                          ),
                          child: StudioChip(
                            label: Text(
                              tokenEfficiencyRoiLabel(
                                l10n,
                                row.tokenEfficiencyRoiBand,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          );
        }),
      ],
    );
  }
}
