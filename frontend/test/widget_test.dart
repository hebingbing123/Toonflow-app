import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/main.dart';

void main() {
  testWidgets('App renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const OpenFlowApp());
    expect(find.text('OpenFlow'), findsOneWidget);
  });
}
