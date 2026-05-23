import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

import '../support/studio_collapsible_filter_test_support.dart';
import '../support/product_shell_test_app.dart';
import '../support/utility_shell_fixtures.dart';

/// Platform status pane via dedicated test route (avoids `/?` → projects resync).
void main() {
  testWidgets('platform status pane shows title and refresh action', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();

    final router = buildPlatformStatusTestRouter();
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      productShellRouterTestApp(router, size: const Size(1440, 900)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await expandStudioCollapsibleFilterPanel(tester);

    expect(find.text(zh.platformStatusTitle), findsAtLeastNWidgets(1));
    expect(find.text(zh.platformStatusIntro), findsOneWidget);
    expect(find.text(zh.platformStatusRefreshAction), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
