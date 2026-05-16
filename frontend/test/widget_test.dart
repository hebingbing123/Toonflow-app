import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/main.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    final zh = AppLocalizationsZh();
    await tester.pumpWidget(const OpenFlowApp());
    expect(find.text(zh.appTitle), findsOneWidget);
  });
}
