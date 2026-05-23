import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_skeleton.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/studio_code_labels.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
import 'value_tier_badge.dart';

class ModelPricingCatalogView extends StatefulWidget {
  const ModelPricingCatalogView({super.key, required this.accessToken});

  final String? accessToken;

  @override
  State<ModelPricingCatalogView> createState() => _ModelPricingCatalogViewState();
}

class _ModelPricingCatalogViewState extends State<ModelPricingCatalogView> {
  bool _loading = true;
  String? _error;
  List<ModelListEntry> _models = const <ModelListEntry>[];
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _models = const <ModelListEntry>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final models = await fetchModelsCatalog(
        token,
        typeFilter: _typeFilter,
        includePricing: true,
      );
      if (!mounted) return;
      setState(() {
        _models = models;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.studioModelPricingTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.studioModelPricingSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Wrap(
          spacing: 8,
          children: <String>['all', 'text', 'image', 'video'].map((value) {
            final selected = _typeFilter == value;
            final label = studioModelPricingTypeLabel(l10n, value);
            return StudioFilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) {
                setState(() => _typeFilter = value);
                _load();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: StudioSpacing.sm),
        if (_loading) const StudioSkeleton(height: 160),
        if (_error != null) Text(_error!),
        if (!_loading && _error == null)
          ..._models.map((entry) {
            final p = entry.pricing;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: StudioCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${entry.label} · ${entry.name}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (p != null)
                          ValueTierBadge(
                            valueTier: p.valueTier,
                            sampleSufficient: true,
                          ),
                      ],
                    ),
                    if (p != null) ...<Widget>[
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        l10n.studioModelPricingPerUnit(
                          p.creditsPerUnit,
                          formatCnyFromCents(p.cnyCentsPerUnit),
                          pricingUnitLabel(l10n, p.pricingUnit),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        l10n.studioModelPricingBestFor(p.bestFor),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
