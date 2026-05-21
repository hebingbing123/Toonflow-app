import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';
import 'package:openflow_app/settings/model_vendors/domestic_vendor_setup_prefs.dart';
import 'package:openflow_app/settings/model_vendors/domestic_vendors.dart';

import 'support/real_product_shell_gallery_support.dart';

/// Targeted E2E: login → E2E seed project → script studio → settings API & models.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  testWidgets('script workspace and API models settings after login', (
    WidgetTester tester,
  ) async {
    final harness = RealProductShellGalleryHarness(tester);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await DomesticVendorSetupPrefs.markDismissed();
    await harness.bootstrap();
    await harness.login();
    await harness.pumpFrames(count: 48);

    const projectName = 'E2E全量图库-1779160463165';
    var resolvedName = projectName;
    if (!await harness.tryOpenProjectByName(projectName)) {
      final anyE2e = find.textContaining('E2E全量图库');
      expect(anyE2e, findsWidgets, reason: 'No E2E gallery project on home grid');
      resolvedName = (anyE2e.evaluate().first.widget as Text).data!;
      await harness.openProjectByName(resolvedName);
    }

    expect(find.text('剧本'), findsWidgets);
    expect(find.text('进入工作室'), findsNothing);

    await harness.openSettingsTab('工作区');
    await harness.pumpFrames(count: 24);
    expect(find.text('工作区'), findsWidgets);

    await harness.openSettingsTab('API 与模型');
    await harness.pumpFrames(count: 60);
    expect(find.text('API 与模型'), findsWidgets);

    final progress = find.textContaining('核心厂商已就绪');
    if (progress.evaluate().isNotEmpty) {
      final label = (progress.evaluate().first.widget as Text).data ?? '';
      final match = RegExp(r'核心厂商已就绪 (\d+)/(\d+)').firstMatch(label);
      expect(match, isNotNull, reason: 'Expected progress label, got: $label');
      final total = int.parse(match!.group(2)!);
      expect(total, kDomesticVendorPrimaryCatalogIds.length);
    }

    await harness.goProjectsHome();
    await harness.openProjectByName(resolvedName);
    expect(find.text('剧本'), findsWidgets);
    expect(await harness.tryCaptureStudioStep('美术', 'art_step_smoke'), isTrue);

    expect(tester.takeException(), isNull);
  });
}
