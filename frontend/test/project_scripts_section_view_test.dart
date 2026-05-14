import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/scripts/section_view.dart';
import 'package:openflow_app/script_editor/support.dart';
import 'package:openflow_app/rust_api.dart';

ProjectScriptsSectionViewModel buildModel({
  bool saving = false,
  bool scriptTaskBusy = false,
  String? scriptTaskLine = '已轮询 2 条剧本提取状态：#11:0 · #12:1',
  List<ScriptBrief>? scriptList,
  ScriptBatchWorkbenchDiagnosis? overviewDiagnosis,
  String overviewActionLabel = '打开工作台读取上下文',
  VoidCallback? overviewAction,
  List<Widget>? probeActions,
}) {
  return ProjectScriptsSectionViewModel(
    saving: saving,
    scriptTaskBusy: scriptTaskBusy,
    scriptTaskLine: scriptTaskLine,
    scriptList:
        scriptList ??
        const <ScriptBrief>[
          ScriptBrief(numericId: 11, name: '第一幕', extractState: 0),
          ScriptBrief(numericId: 12, name: '第二幕', extractState: 1),
        ],
    overviewDiagnosis:
        overviewDiagnosis ??
        const ScriptBatchWorkbenchDiagnosis(
          summary: '建议先同步剧本上下文。',
          detail: '当前还没有批量上下文快照，先读取后再决定导出或抽取。',
          recommendedAction: ScriptBatchWorkbenchRecommendedAction.syncContext,
        ),
    overviewActionLabel: overviewActionLabel,
    overviewAction: overviewAction,
    probeActions:
        probeActions ??
        <Widget>[
          const TextButton(onPressed: null, child: Text('get-script-api')),
        ],
  );
}

ProjectScriptsSectionViewCallbacks buildCallbacks({
  VoidCallback? onOpenWorkbench,
  VoidCallback? onOpenPlanWorkbench,
  VoidCallback? onOpenBatchAddDialog,
  VoidCallback? onExportAll,
  VoidCallback? onPollAll,
  VoidCallback? onExtractAll,
  VoidCallback? onCreateEmptyScript,
  void Function(ScriptBrief script)? onOpenScriptEditor,
}) {
  return ProjectScriptsSectionViewCallbacks(
    onOpenWorkbench: onOpenWorkbench ?? () {},
    onOpenPlanWorkbench: onOpenPlanWorkbench ?? () {},
    onOpenBatchAddDialog: onOpenBatchAddDialog ?? () {},
    onExportAll: onExportAll ?? () {},
    onPollAll: onPollAll ?? () {},
    onExtractAll: onExtractAll ?? () {},
    onCreateEmptyScript: onCreateEmptyScript ?? () {},
    onOpenScriptEditor: onOpenScriptEditor ?? (_) {},
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

Widget buildHarness({
  required ProjectScriptsSectionViewModel model,
  required ProjectScriptsSectionViewCallbacks callbacks,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProjectScriptsSectionView(model: model, callbacks: callbacks),
      ),
    ),
  );
}

void main() {
  testWidgets('project scripts section view renders overview and list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(model: buildModel(), callbacks: buildCallbacks()),
    );

    expect(find.text('2 条剧本'), findsOneWidget);
    expect(find.text('剧本批量工作台'), findsOneWidget);
    expect(find.text('当前批量建议'), findsOneWidget);
    expect(find.text('打开工作台读取上下文'), findsOneWidget);
    expect(find.text('已轮询 2 条剧本提取状态：#11:0 · #12:1'), findsOneWidget);
    expect(find.text('#11 第一幕'), findsOneWidget);
    expect(find.text('#12 第二幕'), findsOneWidget);
    expect(find.text('兼容性检查'), findsOneWidget);
  });

  testWidgets('project scripts section view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        model: buildModel(
          saving: true,
          scriptTaskBusy: true,
          overviewActionLabel: '处理中…',
          overviewAction: null,
        ),
        callbacks: const ProjectScriptsSectionViewCallbacks(
          onOpenWorkbench: null,
          onOpenPlanWorkbench: null,
          onOpenBatchAddDialog: null,
          onExportAll: null,
          onPollAll: null,
          onExtractAll: null,
          onCreateEmptyScript: null,
          onOpenScriptEditor: null,
        ),
      ),
    );

    expect(disabledButtonWithText('打开剧本批量工作台'), findsOneWidget);
    expect(disabledButtonWithText('处理中…'), findsAtLeastNWidgets(2));
    expect(disabledButtonWithText('批量新增剧本'), findsOneWidget);
    expect(disabledButtonWithText('轮询全部提取状态'), findsOneWidget);
    expect(disabledButtonWithText('提取全部剧本素材'), findsOneWidget);
    expect(disabledButtonWithText('新建空剧本'), findsOneWidget);
  });

  testWidgets('project scripts section view forwards action callbacks', (
    WidgetTester tester,
  ) async {
    var openWorkbenchCalls = 0;
    var openPlanWorkbenchCalls = 0;
    var batchAddCalls = 0;
    var exportCalls = 0;
    var pollCalls = 0;
    var extractCalls = 0;
    var createCalls = 0;
    var overviewCalls = 0;
    ScriptBrief? openedScript;

    await tester.pumpWidget(
      buildHarness(
        model: buildModel(overviewAction: () => overviewCalls += 1),
        callbacks: buildCallbacks(
          onOpenWorkbench: () => openWorkbenchCalls += 1,
          onOpenPlanWorkbench: () => openPlanWorkbenchCalls += 1,
          onOpenBatchAddDialog: () => batchAddCalls += 1,
          onExportAll: () => exportCalls += 1,
          onPollAll: () => pollCalls += 1,
          onExtractAll: () => extractCalls += 1,
          onCreateEmptyScript: () => createCalls += 1,
          onOpenScriptEditor: (script) => openedScript = script,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, '打开剧本批量工作台'));
    await tester.pump();
    await tester.tap(find.widgetWithText(OutlinedButton, '打开骨架工作台'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '打开工作台读取上下文'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '批量新增剧本'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '导出全部剧本'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '轮询全部提取状态'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '提取全部剧本素材'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, '新建空剧本'));
    await tester.pump();
    await tester.ensureVisible(find.text('#12 第二幕'));
    await tester.tap(find.text('#12 第二幕'));
    await tester.pump();

    expect(openWorkbenchCalls, 1);
    expect(openPlanWorkbenchCalls, 1);
    expect(overviewCalls, 1);
    expect(batchAddCalls, 1);
    expect(exportCalls, 1);
    expect(pollCalls, 1);
    expect(extractCalls, 1);
    expect(createCalls, 1);
    expect(openedScript?.numericId, 12);
  });
}
