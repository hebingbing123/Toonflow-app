part of '../../../home_page.dart';

extension _HomePageSystemProbesModelsCatalogSettingsProbe on _HomePageState {
  Future<Map<String, int>> _runModelsCatalogSettingsAndAssetsProbes(
    String token,
  ) async {
    final statuses = <String, int>{};
    final vendorAdd = await _runSettingsBaselineProbes(
      token: token,
      statuses: statuses,
    );

    await _runSettingsVendorAndCredentialProbes(
      token: token,
      statuses: statuses,
      vendorId: vendorAdd.body?.vendorId ?? 'probe-vendor',
      credentialVendorId: vendorAdd.body?.vendorId ?? 'probe-vendor-credential',
    );

    await _runSettingsScriptAgentWriteProbes(token: token, statuses: statuses);

    await _runSettingsAssetGenerateProbes(token: token, statuses: statuses);

    return statuses;
  }

  Future<({int status, VendorMutationResponseV1? body})> _vendorMutationProbe(
    Future<VendorMutationResponseV1> Function() run,
  ) async {
    try {
      final body = await run();
      return (status: 200, body: body);
    } on RustApiException catch (e) {
      return (status: e.statusCode ?? -1, body: null);
    }
  }

  Future<({int status, VendorCredentialResponseV1? body})>
  _vendorCredentialProbe(
    Future<VendorCredentialResponseV1> Function() run,
  ) async {
    try {
      final body = await run();
      return (status: 200, body: body);
    } on RustApiException catch (e) {
      return (status: e.statusCode ?? -1, body: null);
    }
  }

  void _expectProbeStatus({
    required String label,
    required int status,
    required List<int> accepted,
  }) {
    if (accepted.contains(status)) return;
    final expected = accepted.join('/');
    throw StateError('$label expected $expected, got $status');
  }
}
