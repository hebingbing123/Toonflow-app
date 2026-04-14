import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/script_editor/support.dart';
import 'package:toonflow_app/home_page/script_editor/workbench_view.dart';
import 'package:toonflow_app/rust_api.dart';

ScriptWorkbenchPanelViewModel buildModel({
  ScriptWorkbenchDiagnosis? diagnosis,
  List<ScriptRelatedAssetBrief> relatedAssets = const <ScriptRelatedAssetBrief>[
    ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
    ScriptRelatedAssetBrief(numericId: 2, name: '场景 B'),
  ],
  String? contextLine = '已加载脚本上下文：素材 2 项',
  bool loadingContext = false,
  bool runningAction = false,
  String? exportLine = '导出完成：1 个剧本，ZIP 16 KB。',
  String? extractStateLine = '已轮询当前剧本提取状态：提取状态 0',
  String? extractAssetsLine = '素材抽取已提交：queued',
  String errorReason = '',
  String recommendedActionLabel = '进入编辑图片工作台',
  VoidCallback? recommendedAction,
}) {
  return ScriptWorkbenchPanelViewModel(
    contextLine: contextLine,
    loadingContext: loadingContext,
    runningAction: runningAction,
    scriptContext: ScriptWorkbenchDetailRow(
      numericId: 7,
      extractState: 0,
      errorReason: errorReason,
      relatedAssets: relatedAssets,
    ),
    extractStateRow: errorReason.isEmpty
        ? const ScriptExtractStatePollRow(numericId: 7, extractState: 0)
        : ScriptExtractStatePollRow(
            numericId: 7,
            extractState: -1,
            errorReason: errorReason,
          ),
    exportLine: exportLine,
    extractStateLine: extractStateLine,
    extractAssetsLine: extractAssetsLine,
    diagnosis:
        diagnosis ??
        const ScriptWorkbenchDiagnosis(
          summary: '当前剧本已有关联素材。',
          detail: '已同步 2 条关联素材，可继续进入编辑图片工作台。',
          recommendedAction:
              ScriptWorkbenchRecommendedAction.openEditImageWorkbench,
        ),
    relatedAssets: relatedAssets,
    errorReason: errorReason,
    recommendedActionLabel: recommendedActionLabel,
    recommendedAction: recommendedAction,
  );
}

ScriptWorkbenchPanelViewCallbacks buildCallbacks({
  VoidCallback? onRefreshWorkbench,
  VoidCallback? onExportCurrentScript,
  VoidCallback? onPollExtractState,
  VoidCallback? onStartExtractAssets,
  VoidCallback? onOpenEditImageWorkbench,
}) {
  return ScriptWorkbenchPanelViewCallbacks(
    onRefreshWorkbench: onRefreshWorkbench ?? () {},
    onExportCurrentScript: onExportCurrentScript ?? () {},
    onPollExtractState: onPollExtractState ?? () {},
    onStartExtractAssets: onStartExtractAssets ?? () {},
    onOpenEditImageWorkbench: onOpenEditImageWorkbench ?? () {},
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
  testWidgets('script workbench panel view renders diagnosis and summaries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptWorkbenchPanelView(
            model: buildModel(),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('脚本工作台'), findsOneWidget);
    expect(find.text('当前剧本已有关联素材。'), findsOneWidget);
    expect(find.text('进入编辑图片工作台'), findsOneWidget);
    expect(find.textContaining('关联素材：角色 A、场景 B'), findsOneWidget);
    expect(find.text('导出当前剧本 ZIP'), findsOneWidget);
    expect(find.text('轮询提取状态'), findsOneWidget);
    expect(find.text('提取当前剧本素材'), findsOneWidget);
    expect(find.text('编辑图片工作台'), findsOneWidget);
    expect(find.text('导出完成：1 个剧本，ZIP 16 KB。'), findsOneWidget);
  });

  testWidgets('script workbench panel view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptWorkbenchPanelView(
            model: buildModel(
              loadingContext: true,
              runningAction: true,
              recommendedActionLabel: '处理中…',
              recommendedAction: null,
            ),
            callbacks: const ScriptWorkbenchPanelViewCallbacks(
              onRefreshWorkbench: null,
              onExportCurrentScript: null,
              onPollExtractState: null,
              onStartExtractAssets: null,
              onOpenEditImageWorkbench: null,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(disabledButtonWithText('同步中…'), findsOneWidget);
    expect(disabledButtonWithText('处理中…'), findsOneWidget);
    expect(disabledButtonWithText('导出当前剧本 ZIP'), findsOneWidget);
    expect(disabledButtonWithText('轮询提取状态'), findsOneWidget);
    expect(disabledButtonWithText('提取当前剧本素材'), findsOneWidget);
    expect(disabledButtonWithText('编辑图片工作台'), findsOneWidget);
  });

  testWidgets('script workbench panel view forwards action callbacks', (
    WidgetTester tester,
  ) async {
    var refreshCalls = 0;
    var exportCalls = 0;
    var pollCalls = 0;
    var extractCalls = 0;
    var editCalls = 0;
    var recommendedCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptWorkbenchPanelView(
            model: buildModel(recommendedAction: () => recommendedCalls += 1),
            callbacks: buildCallbacks(
              onRefreshWorkbench: () => refreshCalls += 1,
              onExportCurrentScript: () => exportCalls += 1,
              onPollExtractState: () => pollCalls += 1,
              onStartExtractAssets: () => extractCalls += 1,
              onOpenEditImageWorkbench: () => editCalls += 1,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, '同步工作台'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '进入编辑图片工作台'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '导出当前剧本 ZIP'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '轮询提取状态'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '提取当前剧本素材'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '编辑图片工作台'));
    await tester.pump();

    expect(refreshCalls, 1);
    expect(recommendedCalls, 1);
    expect(exportCalls, 1);
    expect(pollCalls, 1);
    expect(extractCalls, 1);
    expect(editCalls, 1);
  });
}
