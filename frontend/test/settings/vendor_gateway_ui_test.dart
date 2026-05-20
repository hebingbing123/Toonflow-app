import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/shared_kernel/models.dart';
import 'package:openflow_app/settings/model_vendors/vendor_gateway_ui.dart';

void main() {
  test('aggregation when user base differs from kling official host', () {
    expect(
      vendorUsesAggregationGateway(
        userOrDraftBaseUrl: 'https://api.oneapi.example/v1',
        officialApiHost: 'https://api.klingai.com',
      ),
      isTrue,
    );
    expect(
      vendorUsesAggregationGateway(
        userOrDraftBaseUrl: 'https://api.klingai.com/v1',
        officialApiHost: 'https://api.klingai.com',
      ),
      isFalse,
    );
  });

  test('vendorSummaryShowsAggregation respects saved override only', () {
    final vendor = VendorSummaryItemV1(
      catalog: const VendorCatalogSummaryV1(
        id: 4,
        name: 'Kling',
        modelCount: 1,
        modelKinds: <String>['video'],
        officialApiHost: 'https://api.klingai.com',
        videoProvider: 'kling',
      ),
      userConfig: VendorConfigEntryV1(
        vendorId: '4',
        settings: <String, String>{
          'base_url': 'https://gateway.example/v1',
        },
      ),
    );
    expect(
      vendorSummaryShowsAggregation(vendor, draftBaseUrl: ''),
      isTrue,
    );
    expect(
      vendorSummaryShowsAggregation(
        VendorSummaryItemV1(
          catalog: vendor.catalog,
        ),
        draftBaseUrl: '',
      ),
      isFalse,
    );
  });
}
