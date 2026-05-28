// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';

import 'support/real_product_shell_gallery_support.dart';
import 'ui_ux_audit_interactions.dart';

/// UI/UX audit: full routes + overlay/interaction PNGs at 1920×1080 and 375×667.
///
/// Run: `bash scripts/run-ui-ux-audit-e2e.sh`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  configureGoogleFontsRuntime();

  const auditViewports = <({String id, Size size})>[
    (id: 'desktop', size: Size(1920, 1080)),
    (id: 'mobile', size: Size(375, 667)),
  ];

  for (final vp in auditViewports) {
    testWidgets(
      'ui ux audit gallery @ ${vp.id} ${vp.size.width}x${vp.size.height}',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(vp.size);
        try {
          final outputDir =
              '${Directory.systemTemp.path}/openflow_ui_ux_audit_${vp.id}';
          final harness = RealProductShellGalleryHarness(
            tester,
            outputDir: outputDir,
            screenshotSize: vp.size,
          );

          await captureFullGalleryRoutes(harness);

          await harness.settleShell(count: 72);
          Object? pendingError;
          for (var i = 0; i < 6; i++) {
            pendingError = tester.takeException();
            if (pendingError == null) {
              break;
            }
            await harness.settleShell(count: 48);
          }
          expect(pendingError, isNull);

          final pngs = harness.listCapturedPngs();
          final routeCount = pngs.where((f) {
            final base = f.uri.pathSegments.last;
            return base.startsWith('regular_');
          }).length;
          final interactionCount = pngs.where((f) {
            final base = f.uri.pathSegments.last;
            return base.startsWith('interaction_');
          }).length;

          expect(
            routeCount,
            greaterThanOrEqualTo(vp.id == 'mobile' ? 15 : 20),
            reason: '${vp.id}: routes $routeCount in $outputDir',
          );
          expect(
            interactionCount,
            greaterThanOrEqualTo(vp.id == 'mobile' ? 6 : 6),
            reason:
                '${vp.id}: interactions $interactionCount (dialogs/sheets/menus/expand)',
          );
          for (final f in pngs) {
            expect(
              f.lengthSync(),
              greaterThan(8 * 1024),
              reason: 'PNG too small: ${f.path}',
            );
          }
          print('E2E_AUDIT_VIEWPORT=${vp.id}');
          print('E2E_AUDIT_DIR=$outputDir');
          print('E2E_AUDIT_COUNT=${pngs.length}');
          print('E2E_AUDIT_ROUTES=$routeCount');
          print('E2E_AUDIT_INTERACTIONS=$interactionCount');
        } finally {
          await tester.binding.setSurfaceSize(null);
        }
      },
      timeout: const Timeout(Duration(minutes: 45)),
    );
  }
}
