import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/notifications/controller.dart';
import 'package:openflow_app/notifications/section.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('notifications studio presentation shows empty filtered state', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    final controller = NotificationsController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    );
    controller.items = const [];
    controller.loading = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      studioGoldenApp(
        child: NotificationsSection(
          studioPresentation: true,
          controller: controller,
          onOpenNotification: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text(zh.notificationsCenterTitle), findsOneWidget);
    expect(find.text(zh.studioFilterToolbarTitle), findsOneWidget);
    expect(find.text(zh.notificationsEmptyFiltered), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
