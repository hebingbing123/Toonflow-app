import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/script_editor/storyboards/workbench_view.dart';
import 'package:openflow_app/storyboard_editor/support/diagnosis.dart';
import 'package:openflow_app/rust_api.dart';

final _zh = AppLocalizationsZh();

void noop() {}

Widget appWithZh(Widget child) => MaterialApp(
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
        StoryboardListDiagnosis(
          summary: _zh.scriptEditorStoryboardsDiagnosisReadyBatchSummary(1, 1),
          detail: _zh.scriptEditorStoryboardsDiagnosisReadyBatchDetail,
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
      appWithZh(
        StoryboardsWorkbenchDialogView(
          model: buildDialogModel(),
          callbacks: buildDialogCallbacks(),
        ),
      ),
    );

    expect(find.text(_zh.scriptEditorStoryboardsDialogTitle(1)), findsOneWidget);
    expect(find.text('制作视图 1 条 · #21:draft'), findsOneWidget);
    expect(
      find.text(
        _zh.scriptEditorStoryboardsRecommendedActionLine(
          _zh.scriptEditorStoryboardsRecommendOpenBatchWorkbench,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('最近操作：已同步分镜列表'), findsOneWidget);
    expect(find.text(_zh.scriptEditorStoryboardAddDialogTitle), findsOneWidget);
    expect(
      find.text(_zh.scriptEditorStoryboardBatchAddDialogTitle),
      findsOneWidget,
    );
    expect(
      find.text(_zh.scriptEditorStoryboardsOpenImageWorkbench),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, '#21'), findsOneWidget);
    expect(find.textContaining('夜景街道推镜'), findsOneWidget);
    final subtitleLine =
        '${_zh.scriptEditorStoryboardsRowOrder(1)} · ${_zh.scriptEditorStoryboardsRowState('draft')} · ${_zh.scriptEditorStoryboardsRowDuration('5s')}';
    expect(find.textContaining(subtitleLine), findsOneWidget);
  });

  testWidgets('storyboards workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      appWithZh(
        StoryboardsWorkbenchDialogView(
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
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(
              TextButton,
              _zh.scriptEditorStoryboardBatchAddDialogTitle,
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(
              TextButton,
              _zh.scriptEditorStoryboardsRefreshing,
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(
              TextButton,
              _zh.scriptEditorStoryboardsOpenImageWorkbench,
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(
              TextButton,
              _zh.scriptEditorStoryboardsLoadingProductionView,
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.text(_zh.scriptEditorStoryboardsBusy), findsOneWidget);
    expect(find.text(_zh.scriptEditorStoryboardsRefreshing), findsOneWidget);
    expect(
      find.text(_zh.scriptEditorStoryboardsLoadingProductionView),
      findsOneWidget,
    );
  });

  testWidgets('storyboards workbench view forwards storyboard selection', (
    WidgetTester tester,
  ) async {
    StoryboardRow? openedBoard;

    await tester.pumpWidget(
      appWithZh(
        StoryboardsWorkbenchDialogView(
          model: buildDialogModel(),
          callbacks: buildDialogCallbacks(
            onOpenStoryboard: (board) async => openedBoard = board,
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
