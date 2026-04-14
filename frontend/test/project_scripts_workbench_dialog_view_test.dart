import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/project_editor/scripts/workbench/dialog_view.dart';
import 'package:toonflow_app/home_page/script_editor/support.dart';
import 'package:toonflow_app/rust_api.dart';

ProjectScriptsWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController filterCtrl,
  required TextEditingController selectedIdsCtrl,
  required TextEditingController groupSizeCtrl,
  required TextEditingController addCountCtrl,
  required TextEditingController addPrefixCtrl,
  required TextEditingController addBodyCtrl,
  bool localBusy = false,
  List<ScriptWorkbenchDetailRow> previewRows =
      const <ScriptWorkbenchDetailRow>[],
  List<ScriptBrief> scriptList = const <ScriptBrief>[
    ScriptBrief(numericId: 7, name: '第一集', extractState: 0),
  ],
  String? scriptTaskLine,
}) {
  return ProjectScriptsWorkbenchDialogViewModel(
    localBusy: localBusy,
    infoLine: '当前已载入 1 条剧本，可筛选后批量执行。',
    filterCtrl: filterCtrl,
    previewRows: previewRows,
    selectedIdsCtrl: selectedIdsCtrl,
    diagnosis: const ScriptBatchWorkbenchDiagnosis(
      summary: '所选剧本仍有待抽取素材的项。',
      detail: '建议直接批量发起素材抽取。',
      recommendedAction:
          ScriptBatchWorkbenchRecommendedAction.startExtractSelected,
    ),
    recommendedActionLabel: '提取所选素材',
    groupSizeCtrl: groupSizeCtrl,
    addCountCtrl: addCountCtrl,
    addPrefixCtrl: addPrefixCtrl,
    addBodyCtrl: addBodyCtrl,
    scriptList: scriptList,
    scriptTaskLine: scriptTaskLine,
  );
}

ProjectScriptsWorkbenchDialogViewCallbacks buildDialogCallbacks({
  VoidCallback? onReadContext = noop,
  VoidCallback? onUsePreviewOrAll = noop,
  VoidCallback? onReloadScripts = noop,
  VoidCallback? onRunRecommendedAction = noop,
  VoidCallback? onExportSelected = noop,
  VoidCallback? onPollSelected = noop,
  VoidCallback? onExtractSelected = noop,
  VoidCallback? onBatchCreate = noop,
  VoidCallback? onClose = noop,
}) {
  return ProjectScriptsWorkbenchDialogViewCallbacks(
    onReadContext: onReadContext,
    onUsePreviewOrAll: onUsePreviewOrAll,
    onReloadScripts: onReloadScripts,
    onRunRecommendedAction: onRunRecommendedAction,
    onExportSelected: onExportSelected,
    onPollSelected: onPollSelected,
    onExtractSelected: onExtractSelected,
    onBatchCreate: onBatchCreate,
    onClose: onClose,
  );
}

void main() {
  late TextEditingController filterCtrl;
  late TextEditingController selectedIdsCtrl;
  late TextEditingController groupSizeCtrl;
  late TextEditingController addCountCtrl;
  late TextEditingController addPrefixCtrl;
  late TextEditingController addBodyCtrl;

  setUp(() {
    filterCtrl = TextEditingController();
    selectedIdsCtrl = TextEditingController(text: '7');
    groupSizeCtrl = TextEditingController(text: '3');
    addCountCtrl = TextEditingController(text: '3');
    addPrefixCtrl = TextEditingController(text: '新剧本');
    addBodyCtrl = TextEditingController(text: '剧情梗概待补充。');
  });

  tearDown(() {
    filterCtrl.dispose();
    selectedIdsCtrl.dispose();
    groupSizeCtrl.dispose();
    addCountCtrl.dispose();
    addPrefixCtrl.dispose();
    addBodyCtrl.dispose();
  });

  testWidgets('project scripts workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectScriptsWorkbenchDialogView(
            model: buildDialogModel(
              filterCtrl: filterCtrl,
              selectedIdsCtrl: selectedIdsCtrl,
              groupSizeCtrl: groupSizeCtrl,
              addCountCtrl: addCountCtrl,
              addPrefixCtrl: addPrefixCtrl,
              addBodyCtrl: addBodyCtrl,
              scriptTaskLine: '已导出 1 条剧本。',
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('剧本批量工作台'), findsOneWidget);
    expect(find.text('读取剧本上下文'), findsOneWidget);
    expect(find.text('导出所选剧本'), findsOneWidget);
    expect(find.text('批量新增剧本'), findsOneWidget);
    expect(find.text('上下文预览'), findsOneWidget);
    expect(find.textContaining('#7 第一集'), findsOneWidget);
    expect(find.text('已导出 1 条剧本。'), findsOneWidget);
  });

  testWidgets('project scripts workbench view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectScriptsWorkbenchDialogView(
            model: buildDialogModel(
              filterCtrl: filterCtrl,
              selectedIdsCtrl: selectedIdsCtrl,
              groupSizeCtrl: groupSizeCtrl,
              addCountCtrl: addCountCtrl,
              addPrefixCtrl: addPrefixCtrl,
              addBodyCtrl: addBodyCtrl,
              localBusy: true,
            ),
            callbacks: buildDialogCallbacks(
              onReadContext: null,
              onUsePreviewOrAll: null,
              onReloadScripts: null,
              onRunRecommendedAction: null,
              onExportSelected: null,
              onPollSelected: null,
              onExtractSelected: null,
              onBatchCreate: null,
              onClose: null,
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(
              const Key('project-scripts-workbench-recommended-action'),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '导出所选剧本'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '关闭'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('project scripts workbench view renders preview rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectScriptsWorkbenchDialogView(
            model: buildDialogModel(
              filterCtrl: filterCtrl,
              selectedIdsCtrl: selectedIdsCtrl,
              groupSizeCtrl: groupSizeCtrl,
              addCountCtrl: addCountCtrl,
              addPrefixCtrl: addPrefixCtrl,
              addBodyCtrl: addBodyCtrl,
              previewRows: const <ScriptWorkbenchDetailRow>[
                ScriptWorkbenchDetailRow(
                  numericId: 11,
                  name: '第二集',
                  extractState: 2,
                  relatedAssets: <ScriptRelatedAssetBrief>[
                    ScriptRelatedAssetBrief(numericId: 1, name: '角色 A'),
                    ScriptRelatedAssetBrief(numericId: 2, name: '场景 B'),
                  ],
                ),
              ],
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('使用当前预览'), findsOneWidget);
    expect(
      find.textContaining('#11 第二集 · 提取状态 2 · 素材 角色 A、场景 B'),
      findsOneWidget,
    );
  });
}

void noop() {}
