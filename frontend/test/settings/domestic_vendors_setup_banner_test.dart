import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/shared_kernel/models.dart';
import 'package:openflow_app/settings/model_vendors/domestic_vendor_setup_prefs.dart';
import 'package:openflow_app/settings/model_vendors/domestic_vendors_setup_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/studio_golden_app.dart';

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
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DomesticVendorSetupPrefs.clearDismissedForTests();
  });

  testWidgets('shows primary domestic vendors when keys missing', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        child: DomesticVendorsSetupBanner(
          vendors: <VendorSummaryItemV1>[
            _vendor(7, 'Qwen'),
            _vendor(8, 'DeepSeek'),
            _vendor(1, 'OpenAI'),
          ],
          credentialConfigured: const <String, bool>{},
          onConfigureVendor: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('配置国内模型厂商'), findsOneWidget);
    expect(find.text('Qwen'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);
    expect(find.text('OpenAI'), findsNothing);
  });

  testWidgets('hides when all primary vendors configured', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(
        child: DomesticVendorsSetupBanner(
          vendors: <VendorSummaryItemV1>[
            _vendor(7, 'Qwen'),
            _vendor(8, 'DeepSeek'),
            _vendor(9, 'Zhipu GLM'),
            _vendor(10, 'Moonshot'),
            _vendor(18, 'Volcengine Doubao'),
          ],
          credentialConfigured: const <String, bool>{
            '7': true,
            '8': true,
            '9': true,
            '10': true,
            '18': true,
          },
          onConfigureVendor: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('配置国内模型厂商'), findsNothing);
  });
}
