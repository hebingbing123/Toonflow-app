import '../../rust_api/shared_kernel/models.dart';

/// Catalog ids for China-based providers (`models_catalog.json`), text-first.
const List<int> kDomesticVendorPrimaryCatalogIds = <int>[
  7, // Qwen / DashScope
  8, // DeepSeek
  9, // Zhipu GLM
  10, // Moonshot (Kimi)
  18, // Volcengine Doubao
];

/// Additional domestic vendors (video / more LLM), shown after primary block.
const List<int> kDomesticVendorExtendedCatalogIds = <int>[
  4, // Kling
  19, // Tencent Hunyuan
  13, // MiniMax
  11, // Baichuan
  12, // SiliconFlow
  14, // Yi
  20, // Doubao Video
  21, // Hunyuan Video
  22, // MiniMax Video
];

const List<int> kDomesticVendorCatalogSortOrder = <int>[
  ...kDomesticVendorPrimaryCatalogIds,
  ...kDomesticVendorExtendedCatalogIds,
];

bool isDomesticVendorCatalogId(int catalogId) {
  return kDomesticVendorCatalogSortOrder.contains(catalogId);
}

int domesticVendorCatalogSortIndex(int catalogId) {
  final index = kDomesticVendorCatalogSortOrder.indexOf(catalogId);
  return index >= 0 ? index : 1000 + catalogId;
}

List<VendorSummaryItemV1> sortVendorsDomesticFirst(
  List<VendorSummaryItemV1> vendors,
) {
  final sorted = List<VendorSummaryItemV1>.from(vendors);
  sorted.sort((VendorSummaryItemV1 a, VendorSummaryItemV1 b) {
    final ai = domesticVendorCatalogSortIndex(a.catalog.id);
    final bi = domesticVendorCatalogSortIndex(b.catalog.id);
    if (ai != bi) {
      return ai.compareTo(bi);
    }
    return a.catalog.name.compareTo(b.catalog.name);
  });
  return sorted;
}

List<VendorSummaryItemV1> filterDomesticVendorsForSetup(
  List<VendorSummaryItemV1> vendors, {
  bool primaryOnly = false,
}) {
  final allowed = primaryOnly
      ? kDomesticVendorPrimaryCatalogIds
      : kDomesticVendorCatalogSortOrder;
  final allowedSet = allowed.toSet();
  return sortVendorsDomesticFirst(
    vendors.where((v) => allowedSet.contains(v.catalog.id)).toList(),
  );
}

bool isDomesticVendorCredentialReady(
  VendorSummaryItemV1 vendor,
  bool credentialConfigured,
) {
  if (vendor.catalog.apiKeyOptional) {
    return vendor.isEnabled || credentialConfigured;
  }
  return credentialConfigured;
}

int countDomesticVendorsReady(
  List<VendorSummaryItemV1> vendors,
  Map<String, bool> credentialConfigured, {
  bool primaryOnly = true,
}) {
  final subset = filterDomesticVendorsForSetup(
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

bool isDomesticPrimarySetupComplete(
  List<VendorSummaryItemV1> vendors,
  Map<String, bool> credentialConfigured,
) {
  final primary = filterDomesticVendorsForSetup(vendors, primaryOnly: true);
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

/// At least one core domestic vendor has a key (or optional-key vendor is enabled).
bool isDomesticVendorReadyForAiGeneration(
  List<VendorSummaryItemV1> vendors,
  Map<String, bool> credentialConfigured,
) {
  return countDomesticVendorsReady(
        vendors,
        credentialConfigured,
        primaryOnly: true,
      ) >
      0;
}
