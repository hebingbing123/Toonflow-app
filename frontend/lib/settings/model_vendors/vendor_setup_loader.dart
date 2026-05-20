import '../../rust_api.dart';
import 'domestic_vendors.dart';

/// Cached vendor list + credential hints for setup banners and nudges.
class VendorCredentialSnapshot {
  const VendorCredentialSnapshot({
    required this.vendors,
    required this.credentialConfigured,
  });

  final List<VendorSummaryItemV1> vendors;
  final Map<String, bool> credentialConfigured;
}

Future<VendorCredentialSnapshot?> loadVendorCredentialSnapshot(
  String? accessToken,
) async {
  final token = accessToken?.trim();
  if (token == null || token.isEmpty) {
    return null;
  }
  final summary = await fetchVendorsSummaryV1(token);
  final creds = <String, bool>{};
  for (final vendor in summary.vendors) {
    try {
      final cred = await getSettingsVendorCredentialV1(
        token,
        vendorId: vendor.vendorId,
      );
      creds[vendor.vendorId] =
          cred.keyHint != null && cred.keyHint!.isNotEmpty;
    } catch (_) {
      creds[vendor.vendorId] = false;
    }
  }
  return VendorCredentialSnapshot(
    vendors: sortVendorsDomesticFirst(summary.vendors),
    credentialConfigured: creds,
  );
}
