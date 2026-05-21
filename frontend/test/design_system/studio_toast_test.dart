import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_scaffold_messenger.dart';
import 'package:openflow_app/design_system/ix/studio_toast.dart';
import 'package:openflow_app/design_system/ix/studio_toast_overlay.dart'
    show StudioToastHost, StudioToastOverlay;
import 'package:openflow_app/product_shell/studio_theme.dart';

void main() {
  tearDown(StudioToastOverlay.hide);

  testWidgets('showStudioToast renders message in overlay', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.build(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    showStudioToast(context, message: '右上角提示');
                  },
                  child: const Text('toast'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('toast'));
    await tester.pump();
    expect(find.text('右上角提示'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('StudioScaffoldMessenger bridges SnackBar to toast', (tester) async {
    await tester.pumpWidget(
      StudioScaffoldMessenger(
        child: MaterialApp(
          theme: StudioTheme.build(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('桥接提示')),
                      );
                    },
                    child: const Text('snack'),
                  ),
                ),
              );
            },
          ),
          builder: (context, child) =>
              StudioToastHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.tap(find.text('snack'));
    await tester.pump();
    expect(find.text('桥接提示'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('toast is cleared when product login page is shown', (tester) async {
    await tester.pumpWidget(
      StudioScaffoldMessenger(
        child: MaterialApp(
          theme: StudioTheme.build(),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showStudioToast(context, message: '应被登录页清掉');
                    },
                    child: const Text('show'),
                  ),
                ),
              );
            },
          ),
          builder: (context, child) =>
              StudioToastHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    expect(find.text('应被登录页清掉'), findsOneWidget);

    StudioToastOverlay.hide();
    await tester.pump();
    expect(find.text('应被登录页清掉'), findsNothing);
  });

  test('studioToastMessageFromSnackBarContent reads Text', () {
    expect(
      studioToastMessageFromSnackBarContent(const Text('保存成功')),
      '保存成功',
    );
  });
}
