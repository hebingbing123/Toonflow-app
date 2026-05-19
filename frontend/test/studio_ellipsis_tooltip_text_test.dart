import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_ellipsis_tooltip_text.dart';

void main() {
  testWidgets('shows tooltip message when text overflows', (tester) async {
    const fullText =
        '优先沿用最近章节结果填充 novelId；拿不准时先别写死。';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: StudioEllipsisTooltipText(text: fullText),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tooltip = find.byType(Tooltip);
    expect(tooltip, findsOneWidget);
    expect(
      (tester.widget<Tooltip>(tooltip).message),
      fullText,
    );
  });

  testWidgets('omits tooltip when text fits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: StudioEllipsisTooltipText(text: '短文本'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Tooltip), findsNothing);
  });
}
