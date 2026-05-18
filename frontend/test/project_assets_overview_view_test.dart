import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/assets/overview.dart';
import 'package:openflow_app/rust_api.dart';

ProjectAssetsOverviewViewModel buildModel({
  List<ScriptBrief>? scriptList,
  List<AssetRow>? visibleAssets,
  List<AssetRow>? assetsForScript,
  int? filterScriptNumericId,
  bool assetsLoading = false,
  bool assetsScriptFilterLoading = false,
  bool assetsBusy = false,
}) {
  return ProjectAssetsOverviewViewModel(
    scriptList:
        scriptList ??
        const <ScriptBrief>[
          ScriptBrief(numericId: 11, name: '第一幕'),
          ScriptBrief(numericId: 12, name: '第二幕'),
        ],
    visibleAssets:
        visibleAssets ??
        const <AssetRow>[
          AssetRow(id: 'asset-1', numericId: 7, name: '主角', assetType: 'role'),
          AssetRow(id: 'asset-2', numericId: 9, name: '长剑', assetType: 'props'),
        ],
    assetsForScript: assetsForScript,
    filterScriptNumericId: filterScriptNumericId,
    focusNotice: null,
    assetsLoading: assetsLoading,
    assetsScriptFilterLoading: assetsScriptFilterLoading,
    assetsBusy: assetsBusy,
  );
}

ProjectAssetsOverviewViewCallbacks buildCallbacks({
  ValueChanged<int?>? onFilterChanged,
  Future<void> Function()? onRefresh,
  VoidCallback? onOpenWorkbench,
}) {
  return ProjectAssetsOverviewViewCallbacks(
    onFilterChanged: onFilterChanged ?? (_) {},
    onRefresh: onRefresh ?? () async {},
    onOpenWorkbench: onOpenWorkbench ?? () {},
  );
}

Finder disabledButtonWithText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is ButtonStyleButton &&
        widget.onPressed == null &&
        widget.child is Text &&
        (widget.child as Text).data == text,
  );
}

void main() {
  Widget buildHarness(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  testWidgets('project assets overview view renders summary and filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        ProjectAssetsOverviewView(
          model: buildModel(
            filterScriptNumericId: 11,
            assetsForScript: const <AssetRow>[
              AssetRow(
                id: 'asset-1',
                numericId: 7,
                name: '主角',
                assetType: 'role',
              ),
            ],
          ),
          callbacks: buildCallbacks(),
        ),
      ),
    );

    expect(find.textContaining('Assets 2 · props 1 · role 1'), findsOneWidget);
    expect(find.text('Script #11 has 1 linked asset(s).'), findsOneWidget);
    expect(find.text('#11 第一幕'), findsOneWidget);
    expect(find.text('资产主工作台'), findsOneWidget);
    expect(find.text('打开资产主工作台'), findsOneWidget);
  });

  testWidgets('project assets overview view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        ProjectAssetsOverviewView(
          model: buildModel(
            assetsLoading: true,
            assetsScriptFilterLoading: true,
            assetsBusy: true,
          ),
          callbacks: const ProjectAssetsOverviewViewCallbacks(
            onFilterChanged: null,
            onRefresh: null,
            onOpenWorkbench: null,
          ),
        ),
      ),
    );

    expect(disabledButtonWithText('刷新资产…'), findsOneWidget);
    expect(disabledButtonWithText('打开资产主工作台'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<int?>>(find.byType(DropdownButton<int?>))
          .onChanged,
      isNull,
    );
  });

  testWidgets('project assets overview view forwards callbacks', (
    WidgetTester tester,
  ) async {
    int? changedScriptId;
    var refreshCalls = 0;
    var openWorkbenchCalls = 0;

    await tester.pumpWidget(
      buildHarness(
        ProjectAssetsOverviewView(
          model: buildModel(),
          callbacks: buildCallbacks(
            onFilterChanged: (value) => changedScriptId = value,
            onRefresh: () async => refreshCalls += 1,
            onOpenWorkbench: () => openWorkbenchCalls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#12 第二幕').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '刷新资产'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '打开资产主工作台'));
    await tester.pump();

    expect(changedScriptId, 12);
    expect(refreshCalls, 1);
    expect(openWorkbenchCalls, 1);
  });
}
