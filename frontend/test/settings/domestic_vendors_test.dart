import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/shared_kernel/models.dart';
import 'package:openflow_app/settings/model_vendors/domestic_vendors.dart';

VendorSummaryItemV1 _vendor(int catalogId, String name) {
  return VendorSummaryItemV1(
    catalog: VendorCatalogSummaryV1(
      id: catalogId,
      name: name,
      modelCount: 1,
      modelKinds: const <String>['text'],
    ),
  );
}

void main() {
  test('sortVendorsDomesticFirst puts Qwen before OpenAI', () {
    final sorted = sortVendorsDomesticFirst(<VendorSummaryItemV1>[
      _vendor(1, 'OpenAI'),
      _vendor(7, 'Qwen'),
      _vendor(8, 'DeepSeek'),
    ]);
    expect(sorted.map((v) => v.catalog.id).toList(), <int>[7, 8, 1]);
  });

  test('isDomesticPrimarySetupComplete requires all primary credentials', () {
    final vendors = <VendorSummaryItemV1>[
      _vendor(7, 'Qwen'),
      _vendor(8, 'DeepSeek'),
    ];
    expect(
      isDomesticPrimarySetupComplete(vendors, <String, bool>{}),
      isFalse,
    );
    expect(
      isDomesticPrimarySetupComplete(
        vendors,
        <String, bool>{'7': true, '8': true},
      ),
      isTrue,
    );
  });

  test('isDomesticVendorReadyForAiGeneration needs at least one primary', () {
    final vendors = <VendorSummaryItemV1>[
      _vendor(7, 'Qwen'),
      _vendor(8, 'DeepSeek'),
    ];
    expect(
      isDomesticVendorReadyForAiGeneration(vendors, <String, bool>{}),
      isFalse,
    );
    expect(
      isDomesticVendorReadyForAiGeneration(
        vendors,
        <String, bool>{'7': true},
      ),
      isTrue,
    );
  });

  test('filterDomesticVendorsForSetup primaryOnly excludes Kling', () {
    final vendors = <VendorSummaryItemV1>[
      _vendor(7, 'Qwen'),
      _vendor(4, 'Kling'),
    ];
    final primary = filterDomesticVendorsForSetup(vendors, primaryOnly: true);
    expect(primary.map((v) => v.catalog.id).toList(), <int>[7]);
  });
}
