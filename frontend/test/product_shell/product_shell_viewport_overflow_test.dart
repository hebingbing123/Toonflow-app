import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/components/studio_pane_header.dart';
import 'package:openflow_app/design_system/components/studio_toolbar_button.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/task_center/previews.dart';

import '../support/product_shell_overlay_harness.dart';
import '../support/product_shell_preview_fixtures.dart';

/// Breakpoints aligned with [layout_breakpoints.dart] gates (+ common device sizes).
const _shellChromeWidths = <double>[
  375,
  520,
  599,
  720,
  861,
  960,
  1000,
  1080,
  1180,
  1241,
  1440,
  1920,
];

const _paneToolbarWidths = <double>[287, 375, 720, 960, 1180, 1920];

void expectNoLayoutExceptions(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

Future<void> pumpShell(
  WidgetTester tester, {
  required GoRouter router,
  required Size size,
  Locale locale = const Locale('zh'),
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    productShellOverlayTestApp(router, size: size, locale: locale),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Widget _paneToolbarTestApp({
  required Size size,
  required Widget toolbar,
  Locale locale = const Locale('zh'),
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, child) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: toolbar,
        ),
      ),
    ),
  );
}

void main() {
  final preview = buildProductShellOverflowPreviewData();

  group('product shell chrome — no overflow', () {
    for (final width in _shellChromeWidths) {
      testWidgets('storyboard overlay @ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = productShellStoryboardOverlayRouter(
          debugPreviewData: preview,
        );
        addTearDown(router.dispose);

        await pumpShell(
          tester,
          router: router,
          size: Size(width, 900),
        );
        expectNoLayoutExceptions(tester);
      });
    }
  });

  group('StudioPaneToolbar — no overflow (tasks-like actions)', () {
    for (final width in _paneToolbarWidths) {
      testWidgets('@ ${width.round()}px zh', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _paneToolbarTestApp(
            size: Size(width, 800),
            toolbar: StudioPaneToolbar(
              title: '任务中心',
              subtitle: '查看导出与后台任务进度',
              showBack: false,
              menu: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert),
              ),
              actions: TaskCenterActionsBar(
                loadingTaskApi: false,
                onOpenWorkbench: () {},
                onLoadTaskApi: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoLayoutExceptions(tester);
      });
    }
  });

  group('StudioPaneToolbar — no overflow (many toolbar buttons)', () {
    for (final width in _paneToolbarWidths) {
      testWidgets('@ ${width.round()}px', (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _paneToolbarTestApp(
            size: Size(width, 800),
            toolbar: StudioPaneToolbar(
              title: 'Quality',
              subtitle: 'Review pass rates and bad cases',
              showBack: false,
              menu: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert),
              ),
              actions: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StudioToolbarButton(
                    label: 'Open workbench',
                    icon: Icons.dashboard_customize_outlined,
                    onPressed: () {},
                    primary: true,
                  ),
                  for (var i = 0; i < 4; i++)
                    OutlinedButton(
                      onPressed: () {},
                      child: Text('Refresh $i'),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expectNoLayoutExceptions(tester);
      });
    }
  });
}
