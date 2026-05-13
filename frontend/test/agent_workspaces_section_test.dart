import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/controls.dart';
import 'package:openflow_app/agent_workspaces/section.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

Finder _cardContaining(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(Card)).first;

Finder _buttonInCard(Type buttonType, String cardText, String buttonText) {
  return find.descendant(
    of: _cardContaining(cardText),
    matching: find.widgetWithText(buttonType, buttonText),
  );
}

Future<void> _tapButtonInCard(
  WidgetTester tester, {
  required Type buttonType,
  required String cardText,
  required String buttonText,
}) async {
  final button = _buttonInCard(buttonType, cardText, buttonText);
  await tester.ensureVisible(button);
  await tester.tap(button);
}

Future<void> _selectDropdownValue(
  WidgetTester tester, {
  required String currentValue,
  required String nextValue,
}) async {
  await tester.tap(
    find.widgetWithText(DropdownButtonFormField<String>, currentValue),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(nextValue).last);
  await tester.pumpAndSettle();
}

Future<void> _switchPane(WidgetTester tester, AgentWorkspacePane pane) async {
  final index = switch (pane) {
    AgentWorkspacePane.script => 0,
    AgentWorkspacePane.production => 1,
    AgentWorkspacePane.activity => 2,
  };
  await tester.tap(find.byType(ChoiceChip).at(index));
  await tester.pumpAndSettle();
}

Future<void> _pumpAgentWorkspacesSection(
  WidgetTester tester,
  AgentWorkspacesSection section, {
  double? width = 1800,
  bool addMaterial = false,
}) async {
  Widget body = section;
  if (width != null) {
    body = SizedBox(width: width, child: body);
  }
  body = SingleChildScrollView(child: body);
  if (addMaterial) {
    body = Material(child: body);
  }
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: body),
    ),
  );
}

class _WorkspaceControllers {
  _WorkspaceControllers({
    String projectId = '1',
    String scriptId = '2',
    String scriptPrompt = '',
    String scriptDomainArgs = '{}',
    String productionPrompt = '',
    String flowKey = 'assets',
    String productionDomainTool = 'get_flowData',
    String productionDomainArgs = '{}',
    String productionSubAgentArgs = '{}',
    String scriptSubAgentTool = 'run_sub_agent_storySkeleton',
    String productionSubAgentTool = 'run_sub_agent_director_plan',
  }) : projectIdController = TextEditingController(text: projectId),
       scriptIdController = TextEditingController(text: scriptId),
       scriptPromptController = TextEditingController(text: scriptPrompt),
       scriptDomainArgsController = TextEditingController(
         text: scriptDomainArgs,
       ),
       productionPromptController = TextEditingController(
         text: productionPrompt,
       ),
       flowKeyController = TextEditingController(text: flowKey),
       productionDomainToolController = TextEditingController(
         text: productionDomainTool,
       ),
       productionDomainArgsController = TextEditingController(
         text: productionDomainArgs,
       ),
       productionSubAgentArgsController = TextEditingController(
         text: productionSubAgentArgs,
       ),
       scriptSubAgentToolController = TextEditingController(
         text: scriptSubAgentTool,
       ),
       productionSubAgentToolController = TextEditingController(
         text: productionSubAgentTool,
       );

  final TextEditingController projectIdController;
  final TextEditingController scriptIdController;
  final TextEditingController scriptPromptController;
  final TextEditingController scriptDomainArgsController;
  final TextEditingController productionPromptController;
  final TextEditingController flowKeyController;
  final TextEditingController productionDomainToolController;
  final TextEditingController productionDomainArgsController;
  final TextEditingController productionSubAgentArgsController;
  final TextEditingController scriptSubAgentToolController;
  final TextEditingController productionSubAgentToolController;

  void dispose() {
    projectIdController.dispose();
    scriptIdController.dispose();
    scriptPromptController.dispose();
    scriptDomainArgsController.dispose();
    productionPromptController.dispose();
    flowKeyController.dispose();
    productionDomainToolController.dispose();
    productionDomainArgsController.dispose();
    productionSubAgentArgsController.dispose();
    scriptSubAgentToolController.dispose();
    productionSubAgentToolController.dispose();
  }
}

void _addWorkspaceTearDown(
  WidgetTester tester,
  _WorkspaceControllers controllers, {
  bool resetView = false,
}) {
  addTearDown(() {
    if (resetView) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
    controllers.dispose();
  });
}

void main() {
  testWidgets('Agent workspace pane switching keeps core content visible', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(
      scriptId: '1',
      scriptPrompt: 'script prompt',
      productionPrompt: 'production prompt',
    );
    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>['{"type":"harness.tool.result"}'],
        workspaceAssistantText: 'assistant output',
        workspaceScriptWritebackCandidate: 'candidate',
        workspaceScriptPlanWritebackCandidate: const <String, dynamic>{
          'data': <String, dynamic>{'script': <Map<String, dynamic>>[]},
        },
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: 'get_script_content.content',
        workspaceLastToolResultLine: 'tool line',
        workspaceSuggestedFlowKey: 'assets',
        workspaceWritebackLine: 'writeback done',
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('剧本工作区'), findsOneWidget);

    await _switchPane(tester, AgentWorkspacePane.production);
    expect(find.text('运行制作工作流'), findsOneWidget);

    await _switchPane(tester, AgentWorkspacePane.activity);
    expect(find.text('最新助手文本'), findsOneWidget);
    expect(find.textContaining('最新：harness.tool.result'), findsOneWidget);
  });

  testWidgets('Script guided tasks trigger probe/sub-agent/writeback actions', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers();

    String? lastProbedTool;
    String? lastProbedArgs;
    var runSubAgentCalls = 0;
    var writeBackCalls = 0;

    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: 'candidate',
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_flowData => storyboard',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'shouldGenerateImage': true,
              'associateAssetsIds': <int>[7, 12],
            },
            <String, dynamic>{
              'id': 102,
              'src': 'https://example.com/102.png',
              'shouldGenerateImage': true,
              'associateAssetsIds': <int>[30],
            },
          ],
        },
        workspaceSuggestedFlowKey: 'storyboard',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (String toolName, String rawArgs) {
          lastProbedTool = toolName;
          lastProbedArgs = rawArgs;
        },
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () => runSubAgentCalls += 1,
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () => writeBackCalls += 1,
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    await tester.tap(find.text('1) 拉取 planData'));
    await tester.pump();
    expect(lastProbedTool, 'get_planData');
    expect(lastProbedArgs, '{"key":"storySkeleton","maxChars":1600}');

    await tester.tap(find.text('2) 拉取剧本正文'));
    await tester.pump();
    expect(lastProbedTool, 'get_script_content');
    expect(
      lastProbedArgs,
      '{"scriptId":2,"lineStart":61,"lineEnd":120,"maxChars":1600}',
    );

    await tester.tap(find.text('3) 生成剧本草稿'));
    await tester.pump();
    expect(runSubAgentCalls, 1);
    expect(
      controllers.scriptSubAgentToolController.text,
      'run_sub_agent_script',
    );
    expect(
      controllers.scriptPromptController.text,
      '请先读取当前集计划与目标章节事件；只有在衔接需要时才补读上一集尾段，其他细节再按需补章节正文窗口，然后生成下一版剧本正文并输出可直接写回的完整内容。',
    );

    await tester.tap(find.text('4) 写回剧本').first);
    await tester.pump();
    expect(writeBackCalls, 1);
  });

  testWidgets('Script pane renders planData and tool context snapshots', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers(scriptPrompt: 'script prompt');
    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: 'script candidate',
        workspaceScriptPlanWritebackCandidate: const <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '主角失去记忆后踏上回乡之路。',
            'adaptationStrategy': '聚焦母女关系，压缩支线角色。',
            'script': <Map<String, dynamic>>[
              <String, dynamic>{'scriptName': '第一集', 'scriptData': '夜雨中的站台重逢。'},
            ],
          },
        },
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: 'tool:get_script_content',
        workspaceLastToolResultLine: 'get_script_content => {...}',
        workspaceLastToolName: 'get_script_content',
        workspaceLastToolResultData: const <String, dynamic>{
          'content': '第 1 场：站台。雨幕里，女主看见熟悉背影。',
        },
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('上下文快照'), findsOneWidget);
    expect(find.text('故事骨架'), findsWidgets);
    expect(find.textContaining('主角失去记忆后踏上回乡之路'), findsNWidgets(2));
    expect(find.text('改编策略'), findsWidgets);
    expect(find.textContaining('聚焦母女关系'), findsNWidgets(2));
    expect(find.textContaining('下游消费提示'), findsWidgets);
    expect(find.textContaining('骨架焦点'), findsOneWidget);
    expect(find.textContaining('script rows'), findsWidgets);
    expect(find.textContaining('第一集'), findsOneWidget);
    expect(find.textContaining('get_script_content'), findsWidgets);
    expect(find.textContaining('第 1 场：站台'), findsOneWidget);
  });

  testWidgets('Script pane renders novel event snapshot from tool result', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers(scriptPrompt: 'script prompt');
    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_novel_events => {...}',
        workspaceLastToolName: 'get_novel_events',
        workspaceLastToolResultData: const <String, dynamic>{
          'events': <Map<String, dynamic>>[
            <String, dynamic>{
              'title': '旧厂房重逢',
              'description': '女主在废弃厂房重新见到失踪多年的姐姐。',
            },
          ],
        },
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.textContaining('get_novel_events'), findsWidgets);
    expect(find.textContaining('旧厂房重逢'), findsOneWidget);
    expect(find.textContaining('失踪多年的姐姐'), findsOneWidget);
  });

  testWidgets('Script pane renders raw harness novel items and recipe cards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(scriptId: '9');

    String? lastTool;
    String? lastArgs;
    var subAgentCalls = 0;

    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_novel_text => {...}',
        workspaceLastToolName: 'get_novel_text',
        workspaceLastToolResultData: const <String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'numeric_id': 21,
              'chapter_index': 1,
              'chapter': '雨夜归乡',
              'chapter_data': '女主在暴雨中回到旧站台。',
            },
          ],
        },
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (tool, args) {
          lastTool = tool;
          lastArgs = args;
        },
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () => subAgentCalls += 1,
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.textContaining('get_novel_text'), findsWidgets);
    expect(find.textContaining('雨夜归乡'), findsOneWidget);
    expect(find.text('下一步建议'), findsOneWidget);
    expect(find.text('读取对应事件'), findsOneWidget);

    await _selectDropdownValue(
      tester,
      currentValue: 'get_planData',
      nextValue: 'get_novel_events',
    );

    expect(find.text('填充首章'), findsOneWidget);

    await _tapButtonInCard(
      tester,
      buttonType: FilledButton,
      cardText: '读取对应事件',
      buttonText: '读取剧本上下文',
    );
    await tester.pump();
    expect(lastTool, 'get_novel_events');
    expect(
      lastArgs,
      '{"novelId":21,"fields":["numeric_id","name","detail"],"limit":8,"maxChars":1200}',
    );

    await tester.tap(find.widgetWithText(FilledButton, '运行子代理').last);
    await tester.pump();
    expect(subAgentCalls, 1);
    expect(
      controllers.scriptSubAgentToolController.text,
      'run_sub_agent_adaptationStrategy',
    );
    expect(controllers.scriptPromptController.text, isNotEmpty);
  });

  testWidgets('Script stage board applies and advances stage actions', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers(scriptId: '9');

    String? lastTool;
    String? lastArgs;
    var scriptSubAgentCalls = 0;

    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        initialPane: AgentWorkspacePane.script,
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: const <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '',
            'adaptationStrategy': '',
          },
        },
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_planData => {...}',
        workspaceLastToolName: 'get_planData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '',
            'adaptationStrategy': '',
          },
        },
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (tool, args) {
          lastTool = tool;
          lastArgs = args;
        },
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () => scriptSubAgentCalls += 1,
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('执行阶段'), findsOneWidget);
    expect(find.text('待生成'), findsWidgets);

    final advanceStageButton = _buttonInCard(FilledButton, '故事骨架', '推进阶段');
    await tester.ensureVisible(advanceStageButton);
    await tester.tap(advanceStageButton);
    await tester.pump();
    expect(scriptSubAgentCalls, 1);
    expect(
      controllers.scriptSubAgentToolController.text,
      'run_sub_agent_storySkeleton',
    );
    expect(controllers.scriptPromptController.text, isNotEmpty);

    final readContextButton = _buttonInCard(FilledButton, '章节材料', '读取剧本上下文');
    await tester.ensureVisible(readContextButton);
    await tester.tap(readContextButton);
    await tester.pump();
    expect(lastTool, 'get_novel_text');
    expect(
      lastArgs,
      '{"fields":["numeric_id","chapter","chapter_data"],"lineStart":1,"lineEnd":80,"maxChars":1800,"limit":1}',
    );
  });

  testWidgets('Script form blocks invalid JSON args before probe', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(scriptDomainArgs: '{');

    var probeCalls = 0;

    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: null,
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) => probeCalls += 1,
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    final probeButton = find.widgetWithText(FilledButton, '读取剧本上下文').first;
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(probeCalls, 0);
    expect(find.text('拦截：剧本工具参数 JSON 解析失败。'), findsOneWidget);
  });

  testWidgets('Script argument templates and probe sync render', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(scriptId: '9');

    String? lastTool;
    String? lastArgs;

    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: 'assistant text',
        workspaceScriptWritebackCandidate: 'candidate body',
        workspaceScriptPlanWritebackCandidate: const <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': 'ready',
            'adaptationStrategy': 'ready',
            'script': <Map<String, dynamic>>[
              <String, dynamic>{'id': 1},
            ],
          },
        },
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: 'tool:get_script_content',
        workspaceLastToolResultLine: null,
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (tool, args) {
          lastTool = tool;
          lastArgs = args;
        },
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    await _selectDropdownValue(
      tester,
      currentValue: 'get_planData',
      nextValue: 'get_script_content',
    );

    expect(find.text('模板: 当前剧本窗口'), findsOneWidget);
    expect(find.text('tool=get_script_content'), findsOneWidget);
    expect(find.text('plan.scriptRows=1'), findsOneWidget);

    await tester.tap(find.text('模板: 当前剧本窗口'));
    await tester.pump();
    expect(
      controllers.scriptDomainArgsController.text,
      '{"scriptId":9,"lineStart":1,"lineEnd":80,"maxChars":2200}',
    );

    final probeButton = find.widgetWithText(FilledButton, '读取剧本上下文').last;
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(lastTool, 'get_script_content');
    expect(
      lastArgs,
      '{"scriptId":9,"lineStart":1,"lineEnd":80,"maxChars":2200}',
    );
  });

  testWidgets('Production guided tasks update flow context and callbacks', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers();

    var productionProbeCalls = 0;
    var productionSubAgentCalls = 0;
    var productionWriteBackCalls = 0;

    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_flowData => storyboard',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'shouldGenerateImage': true,
              'associateAssetsIds': <int>[7, 12],
            },
            <String, dynamic>{
              'id': 102,
              'src': 'https://example.com/102.png',
              'shouldGenerateImage': true,
              'associateAssetsIds': <int>[30],
            },
          ],
        },
        workspaceSuggestedFlowKey: 'storyboard',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () => productionWriteBackCalls += 1,
        onApplySuggestedFlowKey: () {},
      ),
    );

    await _switchPane(tester, AgentWorkspacePane.production);

    await tester.tap(find.text('1) 拉取资产 flow'));
    await tester.pump();
    expect(controllers.flowKeyController.text, 'assets');
    expect(controllers.productionDomainToolController.text, 'get_flowData');
    expect(productionProbeCalls, 1);

    await tester.tap(find.text('2) 运行资产子代理'));
    await tester.pump();
    expect(
      controllers.productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(
      controllers.productionSubAgentArgsController.text,
      '{"assetIds":[7,12,30]}',
    );
    expect(controllers.productionPromptController.text, isNotEmpty);
    expect(productionSubAgentCalls, 1);

    await tester.tap(find.text('3) 拉取分镜 flow'));
    await tester.pump();
    expect(controllers.flowKeyController.text, 'storyboard');
    expect(productionProbeCalls, 2);

    await tester.tap(find.text('4) 写回 flow'));
    await tester.pump();
    expect(productionWriteBackCalls, 1);

    await tester.tap(find.text('5) 运行分镜子代理'));
    await tester.pump();
    expect(controllers.flowKeyController.text, 'storyboard');
    expect(
      controllers.productionSubAgentToolController.text,
      'run_sub_agent_storyboard_gen',
    );
    expect(
      controllers.productionSubAgentArgsController.text,
      '{"storyboardIds":[101],"assetIds":[7,12]}',
    );
    expect(productionSubAgentCalls, 2);

    await tester.tap(find.text('6) 运行导演计划子代理'));
    await tester.pump();
    expect(controllers.flowKeyController.text, 'scriptPlan');
    expect(
      controllers.productionSubAgentToolController.text,
      'run_sub_agent_director_plan',
    );
    expect(
      controllers.productionSubAgentArgsController.text,
      '{"storyboardIds":[101],"assetIds":[7,12,30]}',
    );
    expect(productionSubAgentCalls, 3);
  });

  testWidgets('Production sub-agent dropdown auto-fills focused args', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(
      flowKey: 'scriptPlan',
      productionDomainArgs: '{"key":"scriptPlan"}',
    );
    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        initialPane: AgentWorkspacePane.production,
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        productionSubAgentArgsController:
            controllers.productionSubAgentArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_flowData => scriptPlan',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': '''
<scriptPlan>
先核对资产 #12、7 和 asset 5，再补齐缺失衍生素材。
</scriptPlan>
''',
        },
        workspaceSuggestedFlowKey: 'scriptPlan',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    await _selectDropdownValue(
      tester,
      currentValue: 'run_sub_agent_director_plan',
      nextValue: 'run_sub_agent_derive_assets',
    );

    expect(
      controllers.productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(
      controllers.productionSubAgentArgsController.text,
      '{"assetIds":[5,7,12]}',
    );
  });

  testWidgets('Production form blocks invalid JSON args before probe', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(productionDomainArgs: '{');

    var productionProbeCalls = 0;

    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: null,
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    await _switchPane(tester, AgentWorkspacePane.production);

    final probeButton = find.widgetWithText(FilledButton, '读取制作工具');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(productionProbeCalls, 0);
    expect(find.text('拦截：制作工具参数 JSON 解析失败。'), findsOneWidget);
  });

  testWidgets('Production argument templates and result summary render', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(flowKey: 'storyboard');
    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine:
            'get_flowData => {"data":{"storyboard":[1,2]}}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: <String, dynamic>{
          'data': <String, dynamic>{
            'storyboard': <int>[1, 2],
            'assets': <int>[3, 4, 5],
          },
        },
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    await _switchPane(tester, AgentWorkspacePane.production);

    await tester.tap(find.text('模板: 导演计划'));
    await tester.pump();
    expect(
      controllers.productionDomainArgsController.text,
      '{"key":"scriptPlan","maxChars":2200}',
    );

    expect(find.text('结果摘要'), findsOneWidget);
    expect(find.text('tool=get_flowData'), findsOneWidget);
    expect(find.text('对象 keys=2 个'), findsOneWidget);
    expect(find.text('storyboard: 2 项'), findsOneWidget);
    expect(find.text('assets: 3 项'), findsOneWidget);
    expect(find.text('上下文快照'), findsOneWidget);
    expect(find.text('flow[storyboard]'), findsOneWidget);
    expect(find.text('flow[assets]'), findsOneWidget);
  });

  testWidgets('Production diagnosis card applies and runs suggested actions', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers();
    var productionProbeCalls = 0;
    var productionSubAgentCalls = 0;

    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_flowData => {"data":[]}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: <String, dynamic>{'data': <dynamic>[]},
        workspaceSuggestedFlowKey: 'assets',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
      width: null,
      addMaterial: true,
    );

    await _switchPane(tester, AgentWorkspacePane.production);

    expect(find.text('下一步建议'), findsOneWidget);
    expect(find.text('先生成资产计划'), findsOneWidget);
    expect(find.text('执行提示'), findsWidgets);
    expect(find.textContaining('空白 assets flow'), findsWidgets);

    await _tapButtonInCard(
      tester,
      buttonType: FilledButton,
      cardText: '先生成资产计划',
      buttonText: '运行子代理',
    );
    await tester.pump();

    expect(productionSubAgentCalls, 1);
    expect(controllers.flowKeyController.text, 'assets');
    expect(
      controllers.productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(
      controllers.productionPromptController.text,
      contains('空白 assets flow'),
    );

    await _tapButtonInCard(
      tester,
      buttonType: OutlinedButton,
      cardText: '先生成资产计划',
      buttonText: '应用建议',
    );
    await tester.pump();
    expect(find.textContaining('已应用任务建议：先生成资产计划'), findsOneWidget);

    final useFlowKeyButton = find.widgetWithText(OutlinedButton, '使用该 key');
    await tester.ensureVisible(useFlowKeyButton);
    await tester.tap(useFlowKeyButton);
    await tester.pump();
    expect(controllers.flowKeyController.text, 'assets');
    expect(productionProbeCalls, 0);
  });

  testWidgets('Production pane renders tool result text snapshot', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers(
      flowKey: 'scriptPlan',
      productionDomainTool: 'run_sub_agent_director_plan',
      productionSubAgentTool: 'run_sub_agent_director_plan',
    );
    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        initialPane: AgentWorkspacePane.production,
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine:
            'run_sub_agent_director_plan => {"result":"导演计划：先补资产，再细化分镜。"}',
        workspaceLastToolName: 'run_sub_agent_director_plan',
        workspaceLastToolResultData: const <String, dynamic>{
          'result': '导演计划：先补资产，再细化分镜。',
        },
        workspaceSuggestedFlowKey: 'scriptPlan',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('工具返回文本'), findsOneWidget);
    expect(find.textContaining('导演计划：先补资产'), findsWidgets);
  });

  testWidgets('Production pane renders single flow snapshot for get_flowData', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers(
      flowKey: 'storyboard',
      productionDomainArgs: '{"key":"storyboard"}',
    );
    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        initialPane: AgentWorkspacePane.production,
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine:
            'get_flowData => {"data":[{"id":101,"shouldGenerateImage":true}]}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 101,
              'shouldGenerateImage': true,
              'associateAssetsIds': <int>[7, 12],
            },
            <String, dynamic>{'id': 102, 'shouldGenerateImage': false},
          ],
        },
        workspaceSuggestedFlowKey: 'storyboard',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('flow[storyboard]'), findsOneWidget);
    expect(find.textContaining('缺帧 1 项'), findsWidgets);
    expect(find.textContaining('镜头 #101'), findsWidgets);
    expect(find.textContaining('纯文本模式'), findsWidgets);
    expect(find.textContaining('镜头 #102'), findsNothing);
  });

  testWidgets('Production probe auto-syncs get_flowData key in arguments', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final controllers = _WorkspaceControllers(
      flowKey: 'storyboard',
      productionDomainArgs: '{"key":"assets"}',
    );

    var productionProbeCalls = 0;

    _addWorkspaceTearDown(tester, controllers, resetView: true);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: null,
        workspaceSuggestedFlowKey: null,
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    await _switchPane(tester, AgentWorkspacePane.production);
    final probeButton = find.widgetWithText(FilledButton, '读取制作工具');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(productionProbeCalls, 1);
    expect(
      controllers.productionDomainArgsController.text,
      '{"key":"storyboard"}',
    );
  });

  testWidgets('Production pane fills candidate storyboard ids from flow', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers(
      flowKey: 'storyboard',
      productionDomainTool: 'generate_storyboard',
    );
    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        initialPane: AgentWorkspacePane.production,
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine:
            'get_flowData => {"data":[{"id":101},{"id":102},{"id":103}]}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 101},
            <String, dynamic>{'id': 102},
            <String, dynamic>{'id': 103},
          ],
        },
        workspaceSuggestedFlowKey: 'storyboard',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () {},
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () {},
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('当前结果候选参数'), findsOneWidget);
    expect(find.text('候选 3 项：101, 102, 103'), findsOneWidget);

    final fillButton = find.text('填充前 3 项');
    await tester.ensureVisible(fillButton);
    await tester.tap(fillButton);
    await tester.pump();

    expect(
      controllers.productionDomainArgsController.text,
      '{"ids":[101,102,103]}',
    );
    expect(find.textContaining('已填充候选参数：填充前 3 项'), findsOneWidget);
  });

  testWidgets(
    'Production pane fills focused storyboard ids from supervision review',
    (WidgetTester tester) async {
      final controllers = _WorkspaceControllers(
        flowKey: 'storyboard',
        productionDomainTool: 'generate_storyboard',
      );
      _addWorkspaceTearDown(tester, controllers);

      await _pumpAgentWorkspacesSection(
        tester,
        AgentWorkspacesSection(
          initialPane: AgentWorkspacePane.production,
          projectIdController: controllers.projectIdController,
          scriptIdController: controllers.scriptIdController,
          scriptPromptController: controllers.scriptPromptController,
          scriptDomainArgsController: controllers.scriptDomainArgsController,
          productionPromptController: controllers.productionPromptController,
          flowKeyController: controllers.flowKeyController,
          productionDomainToolController:
              controllers.productionDomainToolController,
          productionDomainArgsController:
              controllers.productionDomainArgsController,
          loadingScriptWorkspaceRun: false,
          loadingProductionWorkspaceRun: false,
          loadingScriptDomainProbe: false,
          loadingProductionFlowProbe: false,
          loadingScriptSubAgentRun: false,
          loadingProductionSubAgentRun: false,
          loadingScriptResultWriteback: false,
          loadingScriptPlanResultWriteback: false,
          loadingProductionResultWriteback: false,
          wsLog: const <String>[],
          workspaceAssistantText: '',
          workspaceScriptWritebackCandidate: null,
          workspaceScriptPlanWritebackCandidate: null,
          workspaceScriptPlanRowId: null,
          workspaceScriptWritebackSource: null,
          workspaceLastToolResultLine:
              'run_sub_agent_production_supervision => {"review":{"nextAction":"generate_storyboard","storyboardIds":[9,3,9]}}',
          workspaceLastToolName: 'run_sub_agent_production_supervision',
          workspaceLastToolResultData: const <String, dynamic>{
            'review': <String, dynamic>{
              'target': 'storyboardTable',
              'grade': 'B',
              'severeCount': '0',
              'mediumCount': '1',
              'minorCount': '0',
              'nextAction': 'generate_storyboard',
              'summary': '只需补第 3、9 镜头',
              'storyboardIds': <int>[9, 3, 9],
            },
          },
          workspaceSuggestedFlowKey: 'storyboardTable',
          workspaceWritebackLine: null,
          onRunScriptWorkspace: () {},
          onRunProductionWorkspace: () {},
          onProbeScriptDomainTool: (_, _) {},
          onProbeProductionDomainTool: () {},
          scriptSubAgentToolController:
              controllers.scriptSubAgentToolController,
          productionSubAgentToolController:
              controllers.productionSubAgentToolController,
          onRunScriptSubAgentTool: () {},
          onRunProductionSubAgentTool: () {},
          onWriteBackScriptResult: () {},
          onWriteBackScriptPlanResult: () {},
          onWriteBackScriptPlanViaUpdateData: () {},
          onWriteBackProductionFlowResult: () {},
          onApplySuggestedFlowKey: () {},
        ),
      );

      expect(find.text('当前结果候选参数'), findsOneWidget);
      expect(find.text('候选 2 项：3, 9'), findsOneWidget);

      final fillButton = find.text('填充前 3 项');
      await tester.ensureVisible(fillButton);
      await tester.tap(fillButton);
      await tester.pump();

      expect(controllers.productionDomainArgsController.text, '{"ids":[3,9]}');
      expect(find.textContaining('已填充候选参数：填充前 3 项'), findsOneWidget);
    },
  );

  testWidgets('Production stage board applies and advances stage actions', (
    WidgetTester tester,
  ) async {
    final controllers = _WorkspaceControllers();

    var productionProbeCalls = 0;
    var productionSubAgentCalls = 0;

    _addWorkspaceTearDown(tester, controllers);

    await _pumpAgentWorkspacesSection(
      tester,
      AgentWorkspacesSection(
        initialPane: AgentWorkspacePane.production,
        projectIdController: controllers.projectIdController,
        scriptIdController: controllers.scriptIdController,
        scriptPromptController: controllers.scriptPromptController,
        scriptDomainArgsController: controllers.scriptDomainArgsController,
        productionPromptController: controllers.productionPromptController,
        flowKeyController: controllers.flowKeyController,
        productionDomainToolController:
            controllers.productionDomainToolController,
        productionDomainArgsController:
            controllers.productionDomainArgsController,
        loadingScriptWorkspaceRun: false,
        loadingProductionWorkspaceRun: false,
        loadingScriptDomainProbe: false,
        loadingProductionFlowProbe: false,
        loadingScriptSubAgentRun: false,
        loadingProductionSubAgentRun: false,
        loadingScriptResultWriteback: false,
        loadingScriptPlanResultWriteback: false,
        loadingProductionResultWriteback: false,
        wsLog: const <String>[],
        workspaceAssistantText: '',
        workspaceScriptWritebackCandidate: null,
        workspaceScriptPlanWritebackCandidate: null,
        workspaceScriptPlanRowId: null,
        workspaceScriptWritebackSource: null,
        workspaceLastToolResultLine: 'get_flowData => {"data":[]}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        },
        workspaceSuggestedFlowKey: 'assets',
        workspaceWritebackLine: null,
        onRunScriptWorkspace: () {},
        onRunProductionWorkspace: () {},
        onProbeScriptDomainTool: (_, _) {},
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        scriptSubAgentToolController: controllers.scriptSubAgentToolController,
        productionSubAgentToolController:
            controllers.productionSubAgentToolController,
        onRunScriptSubAgentTool: () {},
        onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
        onWriteBackScriptResult: () {},
        onWriteBackScriptPlanResult: () {},
        onWriteBackScriptPlanViaUpdateData: () {},
        onWriteBackProductionFlowResult: () {},
        onApplySuggestedFlowKey: () {},
      ),
    );

    expect(find.text('执行阶段'), findsOneWidget);
    expect(find.textContaining('当前卡点：导演计划 · 待读取'), findsOneWidget);
    expect(find.text('等待导演计划'), findsWidgets);
    expect(find.text('资产准备'), findsOneWidget);
    expect(find.text('执行提示'), findsWidgets);
    expect(find.textContaining('最小可行的衍生素材集合'), findsWidgets);

    final advanceStageButton = _buttonInCard(FilledButton, '资产准备', '推进阶段');
    await tester.ensureVisible(advanceStageButton);
    await tester.tap(advanceStageButton);
    await tester.pump();
    expect(productionSubAgentCalls, 1);
    expect(
      controllers.productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(controllers.productionPromptController.text, isNotEmpty);

    final readFlowButton = _buttonInCard(FilledButton, '导演计划', '读取 flow');
    await tester.ensureVisible(readFlowButton);
    await tester.tap(readFlowButton);
    await tester.pump();
    expect(productionProbeCalls, 1);
    expect(controllers.flowKeyController.text, 'scriptPlan');
    expect(controllers.productionDomainToolController.text, 'get_flowData');
    expect(
      controllers.productionDomainArgsController.text,
      '{"key":"scriptPlan","maxChars":2200}',
    );
  });
}
