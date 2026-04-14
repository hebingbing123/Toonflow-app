import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/projects/workbenches/agent_memory_view.dart';
import 'package:toonflow_app/rust_api.dart';

ProjectRow buildProject({required int numericId, required String name}) {
  return ProjectRow(id: 'project-$numericId', numericId: numericId, name: name);
}

ProjectsAgentMemoryWorkbenchDialogViewModel buildModel({
  required TextEditingController projectIdCtrl,
  required TextEditingController agentTypeCtrl,
  required TextEditingController episodesIdCtrl,
  required TextEditingController appendContentCtrl,
  required TextEditingController appendRoleCtrl,
  required TextEditingController clearTypeCtrl,
  List<ProjectRow>? projects,
  List<dynamic>? memoryRows,
  String? memorySummary = '已读取 2 条记忆。',
  String? statusLine = '已刷新 2 个项目。',
  bool loadingProjects = false,
  bool loadingMemory = false,
  bool appendingMemory = false,
  bool clearingMemory = false,
}) {
  return ProjectsAgentMemoryWorkbenchDialogViewModel(
    projects:
        projects ??
        <ProjectRow>[
          buildProject(numericId: 11, name: '青溪镇奇案'),
          buildProject(numericId: 12, name: '海雾迷城'),
        ],
    memoryRows:
        memoryRows ??
        <dynamic>[
          <String, Object?>{
            'id': 'memory-1',
            'role': 'user',
            'content': '先补齐第一幕的角色动机和冲突。',
          },
          <String, Object?>{
            'id': 'memory-2',
            'role': 'assistant',
            'content': 'production agent 建议先刷新 storyboardTable 再补镜头。',
          },
        ],
    memorySummary: memorySummary,
    statusLine: statusLine,
    loadingProjects: loadingProjects,
    loadingMemory: loadingMemory,
    appendingMemory: appendingMemory,
    clearingMemory: clearingMemory,
    projectIdCtrl: projectIdCtrl,
    agentTypeCtrl: agentTypeCtrl,
    episodesIdCtrl: episodesIdCtrl,
    appendContentCtrl: appendContentCtrl,
    appendRoleCtrl: appendRoleCtrl,
    clearTypeCtrl: clearTypeCtrl,
  );
}

ProjectsAgentMemoryWorkbenchDialogViewCallbacks buildCallbacks({
  Future<void> Function()? onReloadProjects,
  Future<void> Function()? onQueryMemory,
  Future<void> Function()? onAppendMemory,
  Future<void> Function()? onClearMemory,
  VoidCallback? onClose,
}) {
  return ProjectsAgentMemoryWorkbenchDialogViewCallbacks(
    onReloadProjects: onReloadProjects ?? () async {},
    onQueryMemory: onQueryMemory ?? () async {},
    onAppendMemory: onAppendMemory ?? () async {},
    onClearMemory: onClearMemory ?? () async {},
    onClose: onClose ?? () {},
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
  late TextEditingController projectIdCtrl;
  late TextEditingController agentTypeCtrl;
  late TextEditingController episodesIdCtrl;
  late TextEditingController appendContentCtrl;
  late TextEditingController appendRoleCtrl;
  late TextEditingController clearTypeCtrl;

  setUp(() {
    projectIdCtrl = TextEditingController(text: '11');
    agentTypeCtrl = TextEditingController(text: 'scriptAgent');
    episodesIdCtrl = TextEditingController(text: '3');
    appendContentCtrl = TextEditingController(text: '需要补一个反转伏笔。');
    appendRoleCtrl = TextEditingController(text: 'user');
    clearTypeCtrl = TextEditingController(text: 'message');
  });

  tearDown(() {
    projectIdCtrl.dispose();
    agentTypeCtrl.dispose();
    episodesIdCtrl.dispose();
    appendContentCtrl.dispose();
    appendRoleCtrl.dispose();
    clearTypeCtrl.dispose();
  });

  testWidgets('agent memory workbench view renders summary and rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('Agent 记忆工作台'), findsOneWidget);
    expect(find.textContaining('项目 2 个'), findsOneWidget);
    expect(find.text('已读取 2 条记忆。'), findsOneWidget);
    expect(find.text('2 条记忆'), findsOneWidget);
    expect(find.text('追加记忆'), findsNWidgets(2));
    expect(find.text('清理记忆'), findsOneWidget);
    expect(find.textContaining('memory-1'), findsOneWidget);
  });

  testWidgets('agent memory workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              loadingProjects: true,
              loadingMemory: true,
              appendingMemory: true,
              clearingMemory: true,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(disabledButtonWithText('…'), findsNWidgets(4));
  });

  testWidgets('agent memory workbench view forwards action callbacks', (
    WidgetTester tester,
  ) async {
    var reloadCalls = 0;
    var queryCalls = 0;
    var appendCalls = 0;
    var clearCalls = 0;
    var closeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
            ),
            callbacks: buildCallbacks(
              onReloadProjects: () async => reloadCalls += 1,
              onQueryMemory: () async => queryCalls += 1,
              onAppendMemory: () async => appendCalls += 1,
              onClearMemory: () async => clearCalls += 1,
              onClose: () => closeCalls += 1,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, '刷新项目列表'));
    await tester.tap(find.widgetWithText(FilledButton, '刷新项目列表'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '查询记忆'));
    await tester.tap(find.widgetWithText(FilledButton, '查询记忆'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '追加记忆'));
    await tester.tap(find.widgetWithText(FilledButton, '追加记忆'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '执行清理'));
    await tester.tap(find.widgetWithText(FilledButton, '执行清理'));
    await tester.pump();
    await tester.tap(find.text('关闭'));
    await tester.pump();

    expect(reloadCalls, 1);
    expect(queryCalls, 1);
    expect(appendCalls, 1);
    expect(clearCalls, 1);
    expect(closeCalls, 1);
  });
}
