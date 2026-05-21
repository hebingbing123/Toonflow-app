import 'package:flutter/material.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_skeleton.dart';
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
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_loading) {
      return const StudioSkeleton(height: 80);
    }
    if (_error != null) {
      return Text(_error!);
    }
    final rows = _summary?.rows ?? const <ModelSpendRow>[];
    if (rows.isEmpty) {
      return Text(
        l10n.studioValueTierSampleLow,
        style: theme.textTheme.bodySmall,
      );
    }

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
        const SizedBox(height: 8),
        ...rows.map((row) {
          final tier = row.valueTier;
          final showCheaper = row.sampleSufficient &&
              tier != null &&
              tierMinCost[tier] == row.estimatedCostCents &&
              rows.where((r) => r.valueTier == tier && r.sampleSufficient).length > 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                          padding: const EdgeInsets.only(top: 4),
                          child: Chip(
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
          );
        }),
      ],
    );
  }
}
