import '../../rust_api.dart';
import 'package:flutter/material.dart';

typedef ModelsCatalogAccessTokenProvider = String? Function();
typedef ModelsCatalogErrorSink = void Function(String? error);
typedef ModelsCatalogSettingsAndAssetsProbeRunner =
    Future<Map<String, int>> Function(String token);
typedef ModelsCatalogProductionProbeRunner =
    Future<({Map<String, int> statuses, int implementedCount})> Function(
      String token,
    );
typedef ProbeStatusMapFormatter = String Function(Map<String, int> statuses);

class ModelsCatalogController extends ChangeNotifier {
  ModelsCatalogController({
    required ModelsCatalogAccessTokenProvider accessTokenProvider,
    required ModelsCatalogErrorSink onErrorChanged,
    required ModelsCatalogSettingsAndAssetsProbeRunner
    runSettingsAndAssetsProbes,
    required ModelsCatalogProductionProbeRunner runProductionProbes,
    required ProbeStatusMapFormatter formatProbeStatusMap,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _runSettingsAndAssetsProbes = runSettingsAndAssetsProbes,
       _runProductionProbes = runProductionProbes,
       _formatProbeStatusMap = formatProbeStatusMap;

  final ModelsCatalogAccessTokenProvider _accessTokenProvider;
  final ModelsCatalogErrorSink _onErrorChanged;
  final ModelsCatalogSettingsAndAssetsProbeRunner _runSettingsAndAssetsProbes;
  final ModelsCatalogProductionProbeRunner _runProductionProbes;
  final ProbeStatusMapFormatter _formatProbeStatusMap;

  bool loadingModelsCatalog = false;
  String? modelsCatalogBody;

  String? get _accessToken => _accessTokenProvider();

  void reset() {
    loadingModelsCatalog = false;
    modelsCatalogBody = null;
    notifyListeners();
  }

  Future<void> callModelsCatalog() async {
    final token = _accessToken;
    if (token == null) return;
    loadingModelsCatalog = true;
    modelsCatalogBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final models = await fetchModelsCatalog(token, typeFilter: 'all');
      final vendors = await fetchVendorsSummaryV1(token);
      final agentDeployRows = await postAgentDeployListV1(token);
      final settingsSummary = await _runSettingsAndAssetsProbes(token);
      final productionSummary = await _runProductionProbes(token);
      final sample = models
          .take(4)
          .map((model) {
            return '${model.value}(${model.type})';
          })
          .join(', ');
      final modelsLine = models.isEmpty
          ? '(empty)'
          : '${models.length} models${sample.isEmpty ? '' : '; sample: $sample'}';
      final firstVendor = vendors.vendors.isEmpty
          ? null
          : vendors.vendors.first;
      final vendorsBit = firstVendor == null
          ? 'vendors: (empty)'
          : 'vendors: ${vendors.vendors.length} · ${firstVendor.name} kinds=${firstVendor.modelKinds.join(",")} source=${vendors.source}';
      final agentDeployBit =
          'agent-deploy: ${agentDeployRows.length} rows · ${_formatProbeStatusMap(settingsSummary)} · ${_formatProbeStatusMap(productionSummary.statuses)} · prod/implemented ${productionSummary.implementedCount}x(200/404/503)';
      modelsCatalogBody = '$modelsLine · $vendorsBit · $agentDeployBit';
    } on RustApiException catch (error) {
      _onErrorChanged(
        describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
      );
    } catch (error) {
      _onErrorChanged(
        describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error),
      );
    } finally {
      loadingModelsCatalog = false;
      notifyListeners();
    }
  }
}
