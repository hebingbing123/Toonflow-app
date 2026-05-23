import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/task_center/section.dart';

import '../support/product_shell_test_app.dart';
import '../support/utility_shell_fixtures.dart';

/// Shell wiring for tasks pane (autoload itself needs HTTP mock or device smoke; see inventory).
void main() {
  testWidgets('tasks pane opens from more menu with task center section', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();

    final router = buildProductShellTestRouter();
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      productShellRouterTestApp(router, size: const Size(1440, 900)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.apps_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text(zh.productNavTasks));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskCenterSection), findsOneWidget);
    expect(find.text(zh.productNavTasks), findsWidgets);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/?pane=tasks',
    );
    expectNoBenignQueuedExceptions(tester);
  });
}
