import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('create project flow can show inline API error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: StudioApiErrorCallout(
            error: '无法创建项目，请稍后重试。',
          ),
        ),
      ),
    );
    expect(find.text('无法创建项目，请稍后重试。'), findsOneWidget);
  });
}
