import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/global_search/global_search_bar.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';

import '../support/product_shell_overlay_harness.dart';

void expectNoLayoutExceptions(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('handset product chrome at 375px has no layout overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = productShellStoryboardOverlayRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      productShellOverlayTestApp(
        router,
        size: const Size(375, 667),
        locale: const Locale('zh'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expectNoLayoutExceptions(tester);
  });

  testWidgets('compact product chrome keeps title and search visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = productShellStoryboardOverlayRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      productShellOverlayTestApp(
        router,
        size: const Size(390, 844),
        locale: const Locale('zh'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.text(l10n.studioStoryboardStudioTitle), findsOneWidget);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expect(find.byType(OpenFlowBrandMark), findsWidgets);
    expectNoLayoutExceptions(tester);
  });

  testWidgets('stacked product chrome keeps title and search visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = productShellStoryboardOverlayRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      productShellOverlayTestApp(
        router,
        size: const Size(1180, 900),
        locale: const Locale('zh'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizationsZh();
    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.text(l10n.studioStoryboardStudioTitle), findsOneWidget);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expectNoLayoutExceptions(tester);
  });
}
