import 'package:flutter/material.dart';

import '../../design_system/components/studio_card.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/studio_typography.dart';
import '../../design_system/components/studio_empty_state.dart';
import '../../design_system/components/studio_async_data_view.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/studio_code_labels.dart';
import '../../rust_api.dart';
import 'domestic_vendors.dart';
import 'domestic_vendors_setup_banner.dart';
import 'international_vendors_setup_banner.dart';
import 'vendor_setup_loader.dart';
import 'vendor_credential_dialog.dart';
import 'vendor_gateway_ui.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Settings UI: enable catalog vendors, store API credentials, pick models.
class ModelVendorsSection extends StatefulWidget {
  const ModelVendorsSection({super.key, required this.accessToken});

  final String? accessToken;

  @override
  State<ModelVendorsSection> createState() => _ModelVendorsSectionState();
}

class _ModelVendorsSectionState extends State<ModelVendorsSection> {
  bool _loading = true;
  String? _error;
  List<VendorSummaryItemV1> _vendors = const <VendorSummaryItemV1>[];
  Map<int, List<ModelListEntry>> _modelsByVendor = const <int, List<ModelListEntry>>{};
  final Map<String, bool> _credentialConfigured = <String, bool>{};
  final Set<String> _busyVendorIds = <String>{};
  int? _expandedCatalogId;

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
        _vendors = const <VendorSummaryItemV1>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await loadVendorCredentialSnapshot(token);
      final catalog = await fetchModelsCatalog(token, includePricing: false);
      final grouped = <int, List<ModelListEntry>>{};
      for (final m in catalog) {
        grouped.putIfAbsent(m.id, () => <ModelListEntry>[]).add(m);
      }
      if (!mounted || snapshot == null) return;
      setState(() {
        _vendors = snapshot.vendors;
        _modelsByVendor = grouped;
        _credentialConfigured
          ..clear()
          ..addAll(snapshot.credentialConfigured);
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

  Future<void> _setBusy(String vendorId, Future<void> Function() action) async {
    setState(() => _busyVendorIds.add(vendorId));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyVendorIds.remove(vendorId));
    }
  }

  Future<void> _toggleEnabled(VendorSummaryItemV1 vendor, bool enabled) async {
    final token = widget.accessToken!.trim();
    await _setBusy(vendor.vendorId, () async {
      await postSettingsVendorsEnableV1(
        token,
        id: vendor.vendorId,
        enable: enabled ? 1 : 0,
      );
      await _load();
    });
  }

  Future<void> _saveSelectedModels(
    VendorSummaryItemV1 vendor,
    List<String> modelNames,
  ) async {
    final token = widget.accessToken!.trim();
    await _setBusy(vendor.vendorId, () async {
      await postSettingsVendorsUpdateV1(
        token,
        id: vendor.vendorId,
        selectedModels: modelNames,
      );
      await _load();
    });
  }

  Future<void> _saveBaseUrl(VendorSummaryItemV1 vendor, String baseUrl) async {
    final token = widget.accessToken!.trim();
    await _setBusy(vendor.vendorId, () async {
      await postSettingsVendorsUpdateV1(
        token,
        id: vendor.vendorId,
        settings: <String, String>{'base_url': baseUrl.trim()},
      );
      await _load();
    });
  }

  Future<void> _openCredentialDialog(VendorSummaryItemV1 vendor) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) return;
    setState(() => _expandedCatalogId = vendor.catalog.id);
    final saved = await showVendorCredentialDialog(
      context: context,
      accessToken: token,
      vendorId: vendor.vendorId,
      vendorName: vendor.catalog.name,
      hasCredential: _credentialConfigured[vendor.vendorId] ?? false,
      apiKeyOptional: vendor.catalog.apiKeyOptional,
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _testModel(
    VendorSummaryItemV1 vendor,
    ModelListEntry model,
  ) async {
    final token = widget.accessToken!.trim();
    final l10n = AppLocalizations.of(context)!;
    await _setBusy(vendor.vendorId, () async {
      final status = await postSettingsVendorModelTestV1(
        token,
        modelName: model.value,
        type: model.type,
        id: vendor.vendorId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 200
                ? l10n.settingsModelVendorsTestQueued
                : l10n.settingsModelVendorsTestFailed(status),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
            decoration:
                studioInsetPanelDecoration(
                  context,
                  backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
                ).copyWith(
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: studioShadowColor(context, alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: -8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
            child: Padding(
              padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.settingsModelVendorsTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                  const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                  Text(
                    l10n.settingsModelVendorsSubtitle,
                    style: studioSectionIntroStyle(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.insetDense),
        if (!_loading && _error == null && _vendors.isNotEmpty) ...<Widget>[
          DomesticVendorsSetupBanner(
            vendors: _vendors,
            credentialConfigured: _credentialConfigured,
            onConfigureVendor: _openCredentialDialog,
          ),
          if (isDomesticPrimarySetupComplete(
            _vendors,
            _credentialConfigured,
          ))
            InternationalVendorsSetupBanner(
              vendors: _vendors,
              credentialConfigured: _credentialConfigured,
              onConfigureVendor: _openCredentialDialog,
            ),
        ],
        StudioAsyncDataView(
          loading: _loading,
          error: _error,
          onRetry: _load,
          isEmpty: _vendors.isEmpty,
          empty: StudioEmptyState.emptyData(
            title: l10n.settingsModelVendorsEmpty,
            icon: Icons.hub_outlined,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: studioStaggeredChildren(
              _vendors.map(
                (vendor) => _VendorCard(
                  vendor: vendor,
                  models: _modelsByVendor[vendor.catalog.id] ??
                      const <ModelListEntry>[],
                  busy: _busyVendorIds.contains(vendor.vendorId),
                  expandInitially: _expandedCatalogId == vendor.catalog.id,
                  credentialConfigured:
                      _credentialConfigured[vendor.vendorId] ?? false,
                  onToggleEnabled: (v) => _toggleEnabled(vendor, v),
                  onSaveModels: (names) => _saveSelectedModels(vendor, names),
                  onSaveBaseUrl: (url) => _saveBaseUrl(vendor, url),
                  onManageCredential: () => _openCredentialDialog(vendor),
                  onTestModel: (m) => _testModel(vendor, m),
                ),
              ),
              entranceKey: _vendors.length,
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _VendorCard extends StatefulWidget {
  const _VendorCard({
    required this.vendor,
    required this.models,
    required this.busy,
    this.expandInitially = false,
    required this.credentialConfigured,
    required this.onToggleEnabled,
    required this.onSaveModels,
    required this.onSaveBaseUrl,
    required this.onManageCredential,
    required this.onTestModel,
  });

  final VendorSummaryItemV1 vendor;
  final List<ModelListEntry> models;
  final bool busy;
  final bool expandInitially;
  final bool credentialConfigured;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<List<String>> onSaveModels;
  final ValueChanged<String> onSaveBaseUrl;
  final VoidCallback onManageCredential;
  final ValueChanged<ModelListEntry> onTestModel;

  @override
  State<_VendorCard> createState() => _VendorCardState();
}

class _VendorCardState extends State<_VendorCard> {
  late Set<String> _selected;
  late final TextEditingController _baseUrlCtrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expandInitially;
    _baseUrlCtrl = TextEditingController(text: _resolvedBaseUrl());
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant _VendorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expandInitially && !oldWidget.expandInitially) {
      _expanded = true;
    }
    if (oldWidget.vendor.selectedModels != widget.vendor.selectedModels) {
      _syncSelection();
    }
    final nextUrl = _resolvedBaseUrl();
    if (_baseUrlCtrl.text != nextUrl) {
      _baseUrlCtrl.text = nextUrl;
    }
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  String _resolvedBaseUrl() {
    return widget.vendor.userConfig?.baseUrl ??
        widget.vendor.catalog.defaultBaseUrl ??
        '';
  }

  void _syncSelection() {
    final configured = widget.vendor.selectedModels;
    if (configured.isEmpty) {
      _selected = widget.models.map((m) => m.value).toSet();
    } else {
      _selected = configured.toSet();
    }
  }

  void _toggleModel(String modelName, bool? checked) {
    setState(() {
      if (checked == true) {
        _selected.add(modelName);
      } else {
        _selected.remove(modelName);
      }
    });
    widget.onSaveModels(_selected.toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final v = widget.vendor;
    final kinds = v.catalog.modelKinds
        .map((k) => studioModelPricingTypeLabel(l10n, k))
        .join(', ');
    final protocolChip =
        vendorProtocolChipLabel(l10n, v.catalog.protocol);
    final aggregationActive = vendorSummaryShowsAggregation(
      v,
      draftBaseUrl: _baseUrlCtrl.text,
    );
    final baseHelper = v.catalog.apiKeyOptional
        ? l10n.settingsModelVendorsBaseUrlLocalHint
        : l10n.settingsModelVendorsBaseUrlCloudHint;
    final baseHelperText = aggregationActive
        ? '$baseHelper · ${l10n.settingsModelVendorsAggregationHint}'
        : baseHelper;

    return Padding(
      padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      child: StudioCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(StudioSpacing.chromeActionGap, StudioSpacing.chromeActionGap, StudioSpacing.chromeActionGap, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  v.catalog.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (protocolChip != null) ...<Widget>[
                                const SizedBox(width: StudioSpacing.xs),
                                _VendorProtocolChip(label: protocolChip),
                              ],
                              if (aggregationActive && !_expanded) ...<Widget>[
                                const SizedBox(width: StudioSpacing.xs),
                                _VendorProtocolChip(
                                  label: l10n.settingsModelVendorsAggregationHint,
                                  emphasized: true,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            l10n.settingsModelVendorsVendorMeta(
                              v.catalog.modelCount,
                              kinds,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: StudioTokens.of(context).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: v.isEnabled,
                        onChanged: widget.onToggleEnabled,
                      ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: StudioTokens.of(context).textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...<Widget>[
              const Divider(height: 16),
              TextField(
                controller: _baseUrlCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.settingsModelVendorsBaseUrlLabel,
                  hintText: v.catalog.defaultBaseUrl,
                  helperText: baseHelperText,
                  helperMaxLines: 2,
                ),
                onSubmitted: widget.busy ? null : widget.onSaveBaseUrl,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.busy
                      ? null
                      : () => widget.onSaveBaseUrl(_baseUrlCtrl.text),
                  child: Text(l10n.settingsModelVendorsSaveBaseUrl),
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              Row(
                children: <Widget>[
                  Icon(
                    widget.credentialConfigured
                        ? Icons.vpn_key
                        : Icons.vpn_key_off_outlined,
                    size: 18,
                    color: widget.credentialConfigured
                        ? theme.colorScheme.primary
                        : studioPanelMutedColor(context),
                  ),
                  const SizedBox(width: StudioSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.credentialConfigured
                          ? l10n.settingsModelVendorsCredentialConfigured
                          : v.catalog.apiKeyOptional
                              ? l10n.settingsModelVendorsCredentialOptionalLocal
                              : l10n.settingsModelVendorsCredentialMissing,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : widget.onManageCredential,
                    child: Text(l10n.settingsModelVendorsManageCredential),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.settingsModelVendorsModelsHeading,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: StudioLayoutSpacing.titleTight),
              ...studioStaggeredChildren(
                widget.models.map(
                  (m) => StudioCheckboxListRow(
                    value: _selected.contains(m.value),
                    onChanged: widget.busy
                        ? null
                        : (checked) => _toggleModel(m.value, checked),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(m.label),
                    subtitle: Text(
                      '${m.value} · ${studioModelPricingTypeLabel(l10n, m.type)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    secondary: IconButton(
                      tooltip: l10n.settingsModelVendorsTestAction,
                      onPressed:
                          widget.busy ? null : () => widget.onTestModel(m),
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                    ),
                  ),
                ),
                entranceKey: widget.models.length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VendorProtocolChip extends StatelessWidget {
  const _VendorProtocolChip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.chromeActionGap),
      decoration: BoxDecoration(
        color: emphasized
            ? StudioTokens.of(context).primarySoft.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: Text(
        label,
        style: studioBadgeTextStyle(context).copyWith(
          fontSize: StudioTypography.of(context).meta,
          color: emphasized
              ? theme.colorScheme.onPrimaryContainer
              : StudioTokens.of(context).textSecondary,
        ),
      ),
    );
  }
}
