import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/project_editor/novels/events/workbench_view.dart';
import 'package:toonflow_app/rust_api.dart';

NovelEventsWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController searchCtrl,
  required TextEditingController createNameCtrl,
  required TextEditingController createDetailCtrl,
  required TextEditingController createChapterIdsCtrl,
  required TextEditingController selectedEventIdCtrl,
  required TextEditingController patchNameCtrl,
  required TextEditingController patchDetailCtrl,
  required TextEditingController patchChapterIdsCtrl,
  required TextEditingController batchDeleteIdsCtrl,
  bool localBusy = false,
  List<NovelEventRow> previewRows = const <NovelEventRow>[
    NovelEventRow(
      id: 'event-11',
      projectId: 'project-1',
      numericId: 11,
      name: '开场冲突',
      detail: '主角遭遇意外。',
      chapterIndexes: <int>[1, 2],
    ),
  ],
}) {
  return NovelEventsWorkbenchDialogViewModel(
    infoLine: '已载入 1 条事件。',
    previewRows: previewRows,
    localBusy: localBusy,
    searchCtrl: searchCtrl,
    createNameCtrl: createNameCtrl,
    createDetailCtrl: createDetailCtrl,
    createChapterIdsCtrl: createChapterIdsCtrl,
    selectedEventIdCtrl: selectedEventIdCtrl,
    patchNameCtrl: patchNameCtrl,
    patchDetailCtrl: patchDetailCtrl,
    patchChapterIdsCtrl: patchChapterIdsCtrl,
    batchDeleteIdsCtrl: batchDeleteIdsCtrl,
  );
}

NovelEventsWorkbenchDialogViewCallbacks buildDialogCallbacks({
  VoidCallback? onSearch = noop,
  VoidCallback? onRefresh = noop,
  VoidCallback? onCreate = noop,
  VoidCallback? onSave = noop,
  VoidCallback? onDeleteCurrent = noop,
  VoidCallback? onBatchDelete = noop,
  VoidCallback? onClose = noop,
}) {
  return NovelEventsWorkbenchDialogViewCallbacks(
    onSearch: onSearch,
    onRefresh: onRefresh,
    onCreate: onCreate,
    onSave: onSave,
    onDeleteCurrent: onDeleteCurrent,
    onBatchDelete: onBatchDelete,
    onClose: onClose,
  );
}

void main() {
  late TextEditingController searchCtrl;
  late TextEditingController createNameCtrl;
  late TextEditingController createDetailCtrl;
  late TextEditingController createChapterIdsCtrl;
  late TextEditingController selectedEventIdCtrl;
  late TextEditingController patchNameCtrl;
  late TextEditingController patchDetailCtrl;
  late TextEditingController patchChapterIdsCtrl;
  late TextEditingController batchDeleteIdsCtrl;

  setUp(() {
    searchCtrl = TextEditingController();
    createNameCtrl = TextEditingController(text: '事件 A');
    createDetailCtrl = TextEditingController(text: '事件描述');
    createChapterIdsCtrl = TextEditingController(text: '1,2');
    selectedEventIdCtrl = TextEditingController(text: '11');
    patchNameCtrl = TextEditingController(text: '事件 B');
    patchDetailCtrl = TextEditingController(text: '更新描述');
    patchChapterIdsCtrl = TextEditingController(text: '2,3');
    batchDeleteIdsCtrl = TextEditingController(text: '11,12');
  });

  tearDown(() {
    searchCtrl.dispose();
    createNameCtrl.dispose();
    createDetailCtrl.dispose();
    createChapterIdsCtrl.dispose();
    selectedEventIdCtrl.dispose();
    patchNameCtrl.dispose();
    patchDetailCtrl.dispose();
    patchChapterIdsCtrl.dispose();
    batchDeleteIdsCtrl.dispose();
  });

  testWidgets('novel events workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovelEventsWorkbenchDialogView(
            model: buildDialogModel(
              searchCtrl: searchCtrl,
              createNameCtrl: createNameCtrl,
              createDetailCtrl: createDetailCtrl,
              createChapterIdsCtrl: createChapterIdsCtrl,
              selectedEventIdCtrl: selectedEventIdCtrl,
              patchNameCtrl: patchNameCtrl,
              patchDetailCtrl: patchDetailCtrl,
              patchChapterIdsCtrl: patchChapterIdsCtrl,
              batchDeleteIdsCtrl: batchDeleteIdsCtrl,
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('事件工作台'), findsOneWidget);
    expect(find.text('当前事件预览'), findsOneWidget);
    expect(find.text('新增事件'), findsNWidgets(2));
    expect(find.text('保存事件'), findsOneWidget);
    expect(find.text('批量删除事件'), findsOneWidget);
    expect(find.textContaining('#11 · 开场冲突 · 章节索引 1/2'), findsOneWidget);
  });

  testWidgets('novel events workbench view hides preview section when empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovelEventsWorkbenchDialogView(
            model: buildDialogModel(
              searchCtrl: searchCtrl,
              createNameCtrl: createNameCtrl,
              createDetailCtrl: createDetailCtrl,
              createChapterIdsCtrl: createChapterIdsCtrl,
              selectedEventIdCtrl: selectedEventIdCtrl,
              patchNameCtrl: patchNameCtrl,
              patchDetailCtrl: patchDetailCtrl,
              patchChapterIdsCtrl: patchChapterIdsCtrl,
              batchDeleteIdsCtrl: batchDeleteIdsCtrl,
              previewRows: const <NovelEventRow>[],
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('当前事件预览'), findsNothing);
    expect(find.text('搜索事件'), findsOneWidget);
  });

  testWidgets(
    'novel events workbench view disables actions when callbacks missing',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NovelEventsWorkbenchDialogView(
              model: buildDialogModel(
                searchCtrl: searchCtrl,
                createNameCtrl: createNameCtrl,
                createDetailCtrl: createDetailCtrl,
                createChapterIdsCtrl: createChapterIdsCtrl,
                selectedEventIdCtrl: selectedEventIdCtrl,
                patchNameCtrl: patchNameCtrl,
                patchDetailCtrl: patchDetailCtrl,
                patchChapterIdsCtrl: patchChapterIdsCtrl,
                batchDeleteIdsCtrl: batchDeleteIdsCtrl,
                localBusy: true,
              ),
              callbacks: buildDialogCallbacks(
                onSearch: null,
                onRefresh: null,
                onCreate: null,
                onSave: null,
                onDeleteCurrent: null,
                onBatchDelete: null,
                onClose: null,
              ),
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '新增事件'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '关闭'))
            .onPressed,
        isNull,
      );
    },
  );
}

void noop() {}
