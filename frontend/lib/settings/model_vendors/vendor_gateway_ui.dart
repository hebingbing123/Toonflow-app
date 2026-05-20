import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api/shared_kernel/models.dart';

/// Host:port for gateway detection (matches backend `vendor::gateway`).
String? vendorApiHostPort(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final withScheme =
      trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.hasPort) return '${uri.host}:${uri.port}';
  return uri.host;
}

/// User saved or draft `base_url` points at a third-party aggregator (not official host).
bool vendorUsesAggregationGateway({
  required String userOrDraftBaseUrl,
  String? officialApiHost,
  String? catalogDefaultBaseUrl,
}) {
  final user = vendorApiHostPort(userOrDraftBaseUrl);
  if (user == null) return false;
  if (officialApiHost != null && officialApiHost.trim().isNotEmpty) {
    final official = vendorApiHostPort(officialApiHost);
    return official != null && user != official;
  }
  final def = catalogDefaultBaseUrl != null
      ? vendorApiHostPort(catalogDefaultBaseUrl)
      : null;
  if (def == null || def.isEmpty) return false;
  return user != def;
}

String? vendorProtocolChipLabel(AppLocalizations l10n, String protocol) {
  switch (protocol.trim().toLowerCase()) {
    case 'volcengine_ark':
    case 'volcengine':
    case 'ark':
      return l10n.settingsModelVendorsProtocolArk;
    case 'anthropic':
      return l10n.settingsModelVendorsProtocolAnthropic;
    case 'gemini_native':
    case 'gemini':
      return l10n.settingsModelVendorsProtocolGemini;
    case 'azure_openai':
    case 'azure':
      return l10n.settingsModelVendorsProtocolAzure;
    default:
      return null;
  }
}

bool vendorSummaryShowsAggregation(
  VendorSummaryItemV1 vendor, {
  required String draftBaseUrl,
}) {
  final saved = vendor.userConfig?.baseUrl?.trim() ?? '';
  final effective = draftBaseUrl.trim().isNotEmpty ? draftBaseUrl.trim() : saved;
  if (effective.isEmpty) return false;
  return vendorUsesAggregationGateway(
    userOrDraftBaseUrl: effective,
    officialApiHost: vendor.catalog.officialApiHost,
    catalogDefaultBaseUrl: vendor.catalog.defaultBaseUrl,
  );
}
