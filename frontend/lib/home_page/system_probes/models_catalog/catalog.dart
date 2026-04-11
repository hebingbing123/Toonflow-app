// ignore_for_file: invalid_use_of_protected_member

part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalog on _HomePageState {
  Future<void> _callModelsCatalog() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingModelsCatalog = true;
      _error = null;
      _modelsCatalogBody = null;
    });
    try {
      final list = await fetchModelsCatalog(token, typeFilter: 'all');
      final vs = await fetchVendorsSummaryV1(token);
      final ad = await postAgentDeployListV1(token);
      final settingsSummary = await _runModelsCatalogSettingsAndAssetsProbes(
        token,
      );
      final productionSummary = await _runModelsCatalogProductionProbes(token);
      if (!mounted) return;
      setState(() {
        final sample = list
            .take(4)
            .map((m) => '${m.value}(${m.type})')
            .join(', ');
        final modelsLine = list.isEmpty
            ? '(empty)'
            : '${list.length} models${sample.isEmpty ? '' : '; sample: $sample'}';
        final v0 = vs.vendors.isEmpty ? null : vs.vendors.first;
        final vendorsBit = v0 == null
            ? 'vendors: (empty)'
            : 'vendors: ${vs.vendors.length} · ${v0.name} kinds=${v0.modelKinds.join(",")} source=${vs.source}';
        final adBit =
            'agent-deploy: ${ad.length} rows · ${_formatProbeStatusMap(settingsSummary)} · ${_formatProbeStatusMap(productionSummary.statuses)} · prod/implemented ${productionSummary.implementedCount}x(200/404/503)';
        _modelsCatalogBody = '$modelsLine · $vendorsBit · $adBit';
        _loadingModelsCatalog = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelsCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingModelsCatalog = false;
      });
    }
  }

  String _formatProbeStatusMap(Map<String, int> statuses) {
    return statuses.entries.map((e) => '${e.key}->${e.value}').join(' · ');
  }
}
