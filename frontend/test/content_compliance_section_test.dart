import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/content_compliance/controller.dart';
import 'package:openflow_app/content_compliance/section.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/content_compliance_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'alert primary action preference persists then resets to default',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_compliance_alert_action_preference_stages_v1':
            'over_capacity',
      });

      final controller = ContentComplianceController(
        accessTokenProvider: () => null,
        onErrorChanged: (_) {},
      )
        ..queueEnabledOverride = true
        ..skipAutoLoadQueueOnMount = true
        ..queue = buildContentComplianceQueueWithAlert('over_capacity');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentComplianceSection(controller: controller),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      FilledButton primaryButton() => tester.widget<FilledButton>(
            find.byKey(const ValueKey('contentComplianceTopAlertPrimary')),
          );

      expect((primaryButton().child as Text).data, '执行自动再平衡');

      await tester.ensureVisible(
        find.byKey(const ValueKey('contentComplianceResetAlertPreferences')),
      );
      await tester.tap(
        find.byKey(const ValueKey('contentComplianceResetAlertPreferences')),
      );
      await tester.pumpAndSettle();

      expect((primaryButton().child as Text).data, '预览自动再平衡');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('content_compliance_alert_action_preference_stages_v1'),
        isNull,
      );
    },
  );

  testWidgets(
    'tapping secondary top action persists stage preference locally',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});

      final controller = ContentComplianceController(
        accessTokenProvider: () => null,
        onErrorChanged: (_) {},
      )
        ..queueEnabledOverride = true
        ..skipAutoLoadQueueOnMount = true
        ..queue = buildContentComplianceQueueWithAlert('critical_unclaimed');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentComplianceSection(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FilledButton primaryButton() => tester.widget<FilledButton>(
            find.byKey(const ValueKey('contentComplianceTopAlertPrimary')),
          );

      expect((primaryButton().child as Text).data, '一键批量 claim');
      expect(find.text('仅选中待处理项'), findsOneWidget);

      await tester.ensureVisible(find.text('仅选中待处理项'));
      await tester.tap(find.text('仅选中待处理项'));
      await tester.pumpAndSettle();

      expect((primaryButton().child as Text).data, '仅选中待处理项');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('content_compliance_alert_action_preference_stages_v1'),
        contains('critical_unclaimed'),
      );
    },
  );

  testWidgets(
    'rebuilt section restores persisted top alert preference',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{
        'content_compliance_alert_action_preference_stages_v1':
            'critical_unclaimed',
      });

      ContentComplianceController buildController() {
        return ContentComplianceController(
          accessTokenProvider: () => null,
          onErrorChanged: (_) {},
        )
          ..queueEnabledOverride = true
          ..skipAutoLoadQueueOnMount = true
          ..queue = buildContentComplianceQueueWithAlert('critical_unclaimed');
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentComplianceSection(controller: buildController()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FilledButton primaryButton() => tester.widget<FilledButton>(
            find.byKey(const ValueKey('contentComplianceTopAlertPrimary')),
          );

      expect((primaryButton().child as Text).data, '仅选中待处理项');

      // Rebuild as if user reopened/returned to this pane.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContentComplianceSection(controller: buildController()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect((primaryButton().child as Text).data, '仅选中待处理项');
    },
  );
}
