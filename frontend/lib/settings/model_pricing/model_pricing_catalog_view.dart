import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/components/studio_async_data_view.dart';
import '../../design_system/components/studio_loading_placeholders.dart';
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
        _error = describeUserVisibleApiErrorResolved(context, e);
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
          spacing: StudioSpacing.xs,
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
        StudioAsyncDataView(
          loading: _loading,
          error: _error,
          onRetry: _load,
          loadingPlaceholder: StudioLoadingPlaceholder.list,
          loadingItemCount: 3,
          scrollableLoading: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _models.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final modelEntry = entry.value;
            final p = modelEntry.pricing;
            return studioStaggeredItem(
              index,
              entranceKey: _models.length,
              child: Padding(
              padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
              child: StudioCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${modelEntry.label} · ${modelEntry.name}',
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
            ),
            );
          }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}
