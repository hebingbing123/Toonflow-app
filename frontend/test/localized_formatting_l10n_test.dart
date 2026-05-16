import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/utils/localized_formatting.dart';

void main() {
  testWidgets('LocalizedFormatting duration uses ARB for zh', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            expect(
              LocalizedFormatting.formatDuration(
                context,
                const Duration(hours: 2, minutes: 3),
              ),
              '2小时3分钟',
            );
            expect(
              LocalizedFormatting.formatFileSize(context, 0),
              '0 B',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
