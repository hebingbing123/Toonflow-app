import '../../rust_api/shared_kernel/models.dart';
import 'domestic_vendors.dart';

/// Non–China cloud providers (`models_catalog.json`), shown after domestic setup.
const List<int> kInternationalVendorPrimaryCatalogIds = <int>[
  1, // OpenAI
  15, // Google Gemini
  16, // Anthropic
];

const List<int> kInternationalVendorExtendedCatalogIds = <int>[
  2, // Runway
  3, // Pika
  17, // Azure OpenAI
];

const List<int> kInternationalVendorCatalogSortOrder = <int>[
  ...kInternationalVendorPrimaryCatalogIds,
  ...kInternationalVendorExtendedCatalogIds,
];

int internationalVendorCatalogSortIndex(int catalogId) {
  final index = kInternationalVendorCatalogSortOrder.indexOf(catalogId);
  return index >= 0 ? index : 2000 + catalogId;
}

List<VendorSummaryItemV1> sortVendorsInternationalFirst(
  List<VendorSummaryItemV1> vendors,
) {
  final sorted = List<VendorSummaryItemV1>.from(vendors);
  sorted.sort((VendorSummaryItemV1 a, VendorSummaryItemV1 b) {
    final ai = internationalVendorCatalogSortIndex(a.catalog.id);
    final bi = internationalVendorCatalogSortIndex(b.catalog.id);
    if (ai != bi) {
      return ai.compareTo(bi);
    }
    return a.catalog.name.compareTo(b.catalog.name);
  });
  return sorted;
}

List<VendorSummaryItemV1> filterInternationalVendorsForSetup(
  List<VendorSummaryItemV1> vendors, {
  bool primaryOnly = false,
}) {
  final allowed = primaryOnly
      ? kInternationalVendorPrimaryCatalogIds
      : kInternationalVendorCatalogSortOrder;
  final allowedSet = allowed.toSet();
  return sortVendorsInternationalFirst(
    vendors.where((v) => allowedSet.contains(v.catalog.id)).toList(),
  );
}

int countInternationalVendorsReady(
  List<VendorSummaryItemV1> vendors,
  Map<String, bool> credentialConfigured, {
  bool primaryOnly = true,
}) {
  final subset = filterInternationalVendorsForSetup(
    vendors,
    primaryOnly: primaryOnly,
  );
  var ready = 0;
  for (final vendor in subset) {
    if (isDomesticVendorCredentialReady(
      vendor,
      credentialConfigured[vendor.vendorId] ?? false,
    )) {
      ready++;
    }
  }
  return ready;
}

bool isInternationalPrimarySetupComplete(
  List<VendorSummaryItemV1> vendors,
  Map<String, bool> credentialConfigured,
) {
  final primary = filterInternationalVendorsForSetup(vendors, primaryOnly: true);
  if (primary.isEmpty) {
    return true;
  }
  return primary.every(
    (vendor) => isDomesticVendorCredentialReady(
      vendor,
      credentialConfigured[vendor.vendorId] ?? false,
    ),
  );
}
