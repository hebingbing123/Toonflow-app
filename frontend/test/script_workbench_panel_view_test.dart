import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'support/studio_workbench_section_test_support.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/script_editor/support.dart';
import 'package:openflow_app/script_editor/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

final _zh = AppLocalizationsZh();

ScriptWorkbenchPanelViewModel buildModel({
  ScriptWorkbenchDiagnosis? diagnosis,
  List<ScriptRelatedAssetBrief> relatedAssets = const <ScriptRelatedAssetBrief>[
    ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
    ScriptRelatedAssetBrief(numericId: 2, name: '场景 B'),
  ],
  String? contextLine,
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
    contextLine:
        contextLine ?? _zh.projectEditorScriptsSingleWorkbenchContextLoaded(2),
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
  Widget appWithL10n(Widget child) => MaterialApp(
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

  testWidgets('script workbench panel view renders diagnosis and summaries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      appWithL10n(
        ScriptWorkbenchPanelView(
          model: buildModel(),
          callbacks: buildCallbacks(),
        ),
      ),
    );

    expect(find.text(_zh.scriptEditorWorkbenchPanelTitle), findsOneWidget);
    expect(find.text('当前剧本已有关联素材。'), findsOneWidget);
    expect(
      find.textContaining(
        _zh.scriptEditorWorkbenchRelatedAssetsLine('角色 A、场景 B'),
      ),
      findsOneWidget,
    );
    expect(
      find.text(_zh.projectEditorScriptsSingleWorkbenchRecommendExportScriptZip),
      findsOneWidget,
    );
    expect(
      find.text(_zh.projectEditorScriptsSingleWorkbenchRecommendPollExtractState),
      findsOneWidget,
    );
    expect(
      find.text(
        _zh.projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        _zh.projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench,
      ),
      findsNWidgets(2),
    );
    expect(find.text('导出完成：1 个剧本，ZIP 16 KB。'), findsOneWidget);
  });

  testWidgets('script workbench panel view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      appWithL10n(
        ScriptWorkbenchPanelView(
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
    );

    expect(find.byType(StudioSkeleton), findsWidgets);
    expect(
      disabledButtonWithText(_zh.projectEditorScriptsSingleWorkbenchSyncBusy),
      findsOneWidget,
    );
    expect(disabledButtonWithText('处理中…'), findsOneWidget);
    expect(
      disabledButtonWithText(
        _zh.projectEditorScriptsSingleWorkbenchRecommendExportScriptZip,
      ),
      findsOneWidget,
    );
    expect(
      disabledButtonWithText(
        _zh.projectEditorScriptsSingleWorkbenchRecommendPollExtractState,
      ),
      findsOneWidget,
    );
    expect(
      disabledButtonWithText(
        _zh.projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets,
      ),
      findsOneWidget,
    );
    expect(
      disabledButtonWithText(
        _zh.projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench,
      ),
      findsOneWidget,
    );
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
      appWithL10n(
        ScriptWorkbenchPanelView(
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
    );
    await expandStudioWorkbenchSection(tester);

    await tester.tap(
      find.widgetWithText(
        TextButton,
        _zh.projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench,
      ),
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        '进入编辑图片工作台',
      ),
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(
        FilledButton,
        _zh.projectEditorScriptsSingleWorkbenchRecommendExportScriptZip,
      ),
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(
        TextButton,
        _zh.projectEditorScriptsSingleWorkbenchRecommendPollExtractState,
      ),
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(
        TextButton,
        _zh.projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets,
      ),
    );
    await tester.pump();
    await tester.tap(
      find
          .widgetWithText(
            TextButton,
            _zh.projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench,
          )
          .last,
    );
    await tester.pump();

    expect(refreshCalls, 1);
    expect(recommendedCalls, 1);
    expect(exportCalls, 1);
    expect(pollCalls, 1);
    expect(extractCalls, 1);
    expect(editCalls, 1);
  });
}
