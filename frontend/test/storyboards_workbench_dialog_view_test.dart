import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page/script_editor/storyboards/workbench_view.dart';
import 'package:openflow_app/home_page/storyboard_editor/support/diagnosis.dart';
import 'package:openflow_app/rust_api.dart';

void noop() {}

StoryboardsWorkbenchDialogViewModel buildDialogModel({
  List<StoryboardRow> boardsList = const <StoryboardRow>[
    StoryboardRow(
      id: 'board-1',
      numericId: 21,
      scriptId: 'script-1',
      sbIndex: 1,
      state: 'draft',
      duration: '5s',
      prompt: '夜景街道推镜',
    ),
  ],
  StoryboardListDiagnosis? diagnosis,
  String? productionSummaryLine = '制作视图 1 条 · #21:draft',
  String? storyboardTaskLine = '最近操作：已同步分镜列表',
  bool actionBusy = false,
  bool boardsLoading = false,
  bool productionSummaryLoading = false,
}) {
  return StoryboardsWorkbenchDialogViewModel(
    boardsList: boardsList,
    diagnosis:
        diagnosis ??
        const StoryboardListDiagnosis(
          summary: '已有 1/1 条分镜可直接进入出图流程。',
          detail: '可以进入分镜出图工作台批量读取制作视图、生成预览并导出所选图片。',
          recommendedAction: StoryboardListRecommendedAction.openBatchWorkbench,
        ),
    productionSummaryLine: productionSummaryLine,
    storyboardTaskLine: storyboardTaskLine,
    actionBusy: actionBusy,
    boardsLoading: boardsLoading,
    productionSummaryLoading: productionSummaryLoading,
  );
}

StoryboardsWorkbenchDialogViewCallbacks buildDialogCallbacks({
  VoidCallback? onAddStoryboard = noop,
  VoidCallback? onBatchAddStoryboards = noop,
  VoidCallback? onReloadBoards = noop,
  VoidCallback? onOpenBatchWorkbench = noop,
  VoidCallback? onReloadProductionSummary = noop,
  Future<void> Function(StoryboardRow board)? onOpenStoryboard,
  VoidCallback? onClose = noop,
}) {
  return StoryboardsWorkbenchDialogViewCallbacks(
    onAddStoryboard: onAddStoryboard,
    onBatchAddStoryboards: onBatchAddStoryboards,
    onReloadBoards: onReloadBoards,
    onOpenBatchWorkbench: onOpenBatchWorkbench,
    onReloadProductionSummary: onReloadProductionSummary,
    onOpenStoryboard: onOpenStoryboard ?? (_) async {},
    onClose: onClose ?? noop,
  );
}

void main() {
  testWidgets('storyboards workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryboardsWorkbenchDialogView(
            model: buildDialogModel(),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('分镜 (1)'), findsOneWidget);
    expect(find.text('制作视图 1 条 · #21:draft'), findsOneWidget);
    expect(find.text('推荐动作：进入分镜出图工作台'), findsOneWidget);
    expect(find.text('最近操作：已同步分镜列表'), findsOneWidget);
    expect(find.text('新增分镜'), findsOneWidget);
    expect(find.text('批量新增分镜'), findsOneWidget);
    expect(find.text('分镜出图工作台'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '#21'), findsOneWidget);
    expect(find.textContaining('夜景街道推镜'), findsOneWidget);
  });

  testWidgets('storyboards workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryboardsWorkbenchDialogView(
            model: buildDialogModel(
              actionBusy: true,
              boardsLoading: true,
              productionSummaryLoading: true,
            ),
            callbacks: buildDialogCallbacks(
              onAddStoryboard: null,
              onBatchAddStoryboards: null,
              onReloadBoards: null,
              onOpenBatchWorkbench: null,
              onReloadProductionSummary: null,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '批量新增分镜'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '刷新中…'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '分镜出图工作台'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '读取制作视图…'))
          .onPressed,
      isNull,
    );
    expect(find.text('处理中…'), findsOneWidget);
    expect(find.text('刷新中…'), findsOneWidget);
    expect(find.text('读取制作视图…'), findsOneWidget);
  });

  testWidgets('storyboards workbench view forwards storyboard selection', (
    WidgetTester tester,
  ) async {
    StoryboardRow? openedBoard;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoryboardsWorkbenchDialogView(
            model: buildDialogModel(),
            callbacks: buildDialogCallbacks(
              onOpenStoryboard: (board) async => openedBoard = board,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ListTile).first);
    await tester.pump();

    expect(openedBoard?.numericId, 21);
    expect(openedBoard?.id, 'board-1');
  });
}
