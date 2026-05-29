import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/product_shell/studio_shell_branches.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

import '../support/ignore_layout_overflow.dart';
import '../support/product_shell_overflow_harness.dart';
import '../support/product_shell_preview_fixtures.dart';

const _auditWidths = <double>[375, 960, 1920];

void _testWidgetsNoSemantics(
  String description,
  WidgetTesterCallback callback,
) {
  testWidgets(description, callback, semanticsEnabled: false);
}

Future<void> _settleHarness(WidgetTester tester) async {
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    takeBenignLayoutOverflowExceptions(tester);
  }
}

Future<void> _exerciseOverlay(
  WidgetTester tester,
  ProductShellOverflowHarness harness, {
  required Future<void> Function() open,
  required Finder openMarker,
  bool verifyClosed = true,
}) async {
  await open();
  await _settleHarness(tester);
  if (openMarker.evaluate().isEmpty) {
    return;
  }
  expect(openMarker, findsWidgets);
  await _dismissOverlay(tester, harness);
  await _settleHarness(tester);
  if (verifyClosed) {
    expect(openMarker, findsNothing);
  }
}

Future<void> _dismissOverlay(
  WidgetTester tester,
  ProductShellOverflowHarness harness,
) async {
  await harness.closeOverlay();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    takeBenignLayoutOverflowExceptions(tester);
  }
}

void main() {
  group('product shell modal interactions (mock preview)', () {
    // More menu + create wizard: layout-only coverage in
    // product_shell_routes_and_overlays_overflow_test.dart; E2E in ui_ux_audit_interactions.dart.
    for (final width in _auditWidths) {
      _testWidgetsNoSemantics('api keys create dialog @ ${width.round()}px', (
        tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = createProductShellDebugRouter(
          debugPreviewData: buildProductShellOverflowPreviewData(),
        );
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: studioUriForUtilityPane(ProductWorkspacePane.apiKeys),
        );
        await _exerciseOverlay(
          tester,
          harness,
          open: () => harness.tryTapFirstLabel(<String>[
            '创建 API 密钥',
            'Create API key',
            '创建密钥',
          ]),
          openMarker: find.text('签发新密钥'),
          verifyClosed: false,
        );
      });

      _testWidgetsNoSemantics('script setup sheet @ ${width.round()}px', (
        tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = createProductShellDebugRouter(
          debugPreviewData: buildProductShellOverflowPreviewData(),
        );
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: '/projects/7/script',
        );
        await _exerciseOverlay(
          tester,
          harness,
          open: harness.openScriptSetupSheet,
          openMarker: find.text('步骤准备区'),
        );
      });

      _testWidgetsNoSemantics('creator journey workflow @ ${width.round()}px', (
        tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = createProductShellDebugRouter(
          debugPreviewData: buildProductShellOverflowPreviewData(),
        );
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: '/projects/7/script',
        );
        await _exerciseOverlay(
          tester,
          harness,
          open: harness.openCreatorJourneyWorkflowDialog,
          openMarker: find.text('六步工作流'),
        );
      });

      _testWidgetsNoSemantics('art brief sheet @ ${width.round()}px', (
        tester,
      ) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = createProductShellDebugRouter(
          debugPreviewData: buildProductShellOverflowPreviewData(),
        );
        addTearDown(router.dispose);
        final harness = ProductShellOverflowHarness(tester, router);
        await harness.bootstrap(
          size: Size(width, 900),
          location: '/projects/7/art',
        );
        await _exerciseOverlay(
          tester,
          harness,
          open: harness.openArtStepBriefSheet,
          openMarker: find.text('立项与视觉约束'),
        );
      });
    }

    _testWidgetsNoSemantics('creator compact tools sheet @ 720px', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = createProductShellDebugRouter(
        debugPreviewData: buildProductShellOverflowPreviewData(),
      );
      addTearDown(router.dispose);
      final harness = ProductShellOverflowHarness(tester, router);
      await harness.bootstrap(
        size: const Size(720, 900),
        location: '/projects/7/script',
      );
      await _exerciseOverlay(
        tester,
        harness,
        open: harness.openCreatorCompactToolsSheet,
        openMarker: find.text('全流程'),
      );
    });
  });
}
