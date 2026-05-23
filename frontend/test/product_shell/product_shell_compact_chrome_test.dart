import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/global_search/global_search_bar.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/design_system/components/openflow_brand.dart';

import '../support/product_shell_overlay_harness.dart';

void main() {
  testWidgets('compact product chrome keeps title and search visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = productShellStoryboardOverlayRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      productShellOverlayTestApp(router, size: const Size(390, 844)),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizationsEn();
    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.text(l10n.studioStoryboardStudioTitle), findsOneWidget);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expect(find.byType(OpenFlowBrandMark), findsWidgets);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('stacked product chrome keeps title and search visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = productShellStoryboardOverlayRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      productShellOverlayTestApp(router, size: const Size(1180, 900)),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizationsEn();
    expect(find.text(l10n.appTitle), findsOneWidget);
    expect(find.text(l10n.studioStoryboardStudioTitle), findsOneWidget);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
