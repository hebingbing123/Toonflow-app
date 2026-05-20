import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/shared_kernel/models.dart';
import 'package:openflow_app/settings/model_vendors/international_vendors.dart';

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
  test('sortVendorsInternationalFirst orders OpenAI before Qwen', () {
    final sorted = sortVendorsInternationalFirst(<VendorSummaryItemV1>[
      _vendor(7, 'Qwen'),
      _vendor(1, 'OpenAI'),
    ]);
    expect(sorted.map((v) => v.catalog.id).toList(), <int>[1, 7]);
  });

  test('isInternationalPrimarySetupComplete needs OpenAI Gemini Anthropic', () {
    final vendors = <VendorSummaryItemV1>[
      _vendor(1, 'OpenAI'),
      _vendor(15, 'Gemini'),
      _vendor(16, 'Anthropic'),
    ];
    expect(
      isInternationalPrimarySetupComplete(vendors, <String, bool>{}),
      isFalse,
    );
    expect(
      isInternationalPrimarySetupComplete(
        vendors,
        <String, bool>{'1': true, '15': true, '16': true},
      ),
      isTrue,
    );
  });
}
