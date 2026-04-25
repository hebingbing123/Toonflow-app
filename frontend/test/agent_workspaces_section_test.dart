import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/controls.dart';
import 'package:openflow_app/agent_workspaces/section.dart';

void main() {
  testWidgets('Agent workspace pane switching keeps core content visible', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '1');
    final scriptPromptController = TextEditingController(text: 'script prompt');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(
      text: 'production prompt',
    );
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('剧本工作区'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, '制作工作区'));
    await tester.pumpAndSettle();
    expect(find.text('运行制作工作流'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '执行动态'));
    await tester.pumpAndSettle();
    expect(find.text('最新助手文本'), findsOneWidget);
    expect(find.textContaining('latest: harness.tool.result'), findsOneWidget);
  });

  testWidgets('Script guided tasks trigger probe/sub-agent/writeback actions', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    String? lastProbedTool;
    String? lastProbedArgs;
    var runSubAgentCalls = 0;
    var writeBackCalls = 0;

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                workspaceLastToolResultLine: 'line',
                workspaceSuggestedFlowKey: null,
                workspaceWritebackLine: null,
                onRunScriptWorkspace: () {},
                onRunProductionWorkspace: () {},
                onProbeScriptDomainTool: (String toolName, String rawArgs) {
                  lastProbedTool = toolName;
                  lastProbedArgs = rawArgs;
                },
                onProbeProductionDomainTool: () {},
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () => runSubAgentCalls += 1,
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () => writeBackCalls += 1,
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
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
    expect(scriptSubAgentToolController.text, 'run_sub_agent_script');
    expect(
      scriptPromptController.text,
      '请先读取当前集计划与目标章节事件；只有在衔接需要时才补读上一集尾段，其他细节再按需补章节正文窗口，然后生成下一版剧本正文并输出可直接写回的完整内容。',
    );

    await tester.tap(find.text('4) 写回剧本'));
    await tester.pump();
    expect(writeBackCalls, 1);
  });

  testWidgets('Script pane renders planData and tool context snapshots', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: 'script prompt');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                      <String, dynamic>{
                        'scriptName': '第一集',
                        'scriptData': '夜雨中的站台重逢。',
                      },
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('上下文快照'), findsOneWidget);
    expect(find.text('故事骨架'), findsWidgets);
    expect(find.textContaining('主角失去记忆后踏上回乡之路'), findsOneWidget);
    expect(find.text('改编策略'), findsWidgets);
    expect(find.textContaining('聚焦母女关系'), findsOneWidget);
    expect(find.text('计划内剧本草稿'), findsOneWidget);
    expect(find.textContaining('第一集'), findsOneWidget);
    expect(find.text('当前剧本正文'), findsOneWidget);
    expect(find.textContaining('第 1 场：站台'), findsOneWidget);
  });

  testWidgets('Script pane renders novel event snapshot from tool result', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: 'script prompt');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('小说事件'), findsOneWidget);
    expect(find.textContaining('旧厂房重逢'), findsOneWidget);
    expect(find.textContaining('失踪多年的姐姐'), findsOneWidget);
  });

  testWidgets('Script pane renders raw harness novel items and recipe cards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '9');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    String? lastTool;
    String? lastArgs;
    var subAgentCalls = 0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () => subAgentCalls += 1,
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('小说章节正文'), findsOneWidget);
    expect(find.textContaining('雨夜归乡'), findsOneWidget);
    expect(find.text('下一步建议'), findsOneWidget);
    expect(find.text('读取对应事件'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'get_planData'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('get_novel_events').last);
    await tester.pumpAndSettle();

    expect(find.text('填充首章'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '读取上下文').at(4));
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
      scriptSubAgentToolController.text,
      'run_sub_agent_adaptationStrategy',
    );
    expect(scriptPromptController.text, isNotEmpty);
  });

  testWidgets('Script stage board applies and advances stage actions', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '9');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    String? lastTool;
    String? lastArgs;
    var scriptSubAgentCalls = 0;

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                initialPane: AgentWorkspacePane.script,
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () => scriptSubAgentCalls += 1,
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('执行阶段'), findsOneWidget);
    expect(find.text('待生成'), findsWidgets);

    final advanceStageButton = find.widgetWithText(FilledButton, '推进阶段').first;
    await tester.ensureVisible(advanceStageButton);
    await tester.tap(advanceStageButton);
    await tester.pump();
    expect(scriptSubAgentCalls, 1);
    expect(scriptSubAgentToolController.text, 'run_sub_agent_storySkeleton');
    expect(scriptPromptController.text, isNotEmpty);

    final readContextButton = find.text('读取上下文').first;
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

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    var probeCalls = 0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final probeButton = find.widgetWithText(FilledButton, '读取剧本上下文');
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

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '9');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    String? lastTool;
    String? lastArgs;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'get_planData'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('get_script_content').last);
    await tester.pumpAndSettle();

    expect(find.text('模板: 当前剧本窗口'), findsOneWidget);
    expect(find.text('tool=get_script_content'), findsOneWidget);
    expect(find.text('plan.scriptRows=1'), findsOneWidget);

    await tester.tap(find.text('模板: 当前剧本窗口'));
    await tester.pump();
    expect(
      scriptDomainArgsController.text,
      '{"scriptId":9,"lineStart":1,"lineEnd":80,"maxChars":2200}',
    );

    final probeButton = find.widgetWithText(FilledButton, '读取剧本上下文');
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
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    var productionProbeCalls = 0;
    var productionSubAgentCalls = 0;
    var productionWriteBackCalls = 0;

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                workspaceLastToolResultLine: 'line',
                workspaceSuggestedFlowKey: null,
                workspaceWritebackLine: null,
                onRunScriptWorkspace: () {},
                onRunProductionWorkspace: () {},
                onProbeScriptDomainTool: (_, _) {},
                onProbeProductionDomainTool: () => productionProbeCalls += 1,
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () =>
                    productionWriteBackCalls += 1,
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '制作工作区'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1) 拉取资产 flow'));
    await tester.pump();
    expect(flowKeyController.text, 'assets');
    expect(productionDomainToolController.text, 'get_flowData');
    expect(productionProbeCalls, 1);

    await tester.tap(find.text('2) 运行资产子代理'));
    await tester.pump();
    expect(
      productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(productionPromptController.text, isNotEmpty);
    expect(productionSubAgentCalls, 1);

    await tester.tap(find.text('3) 拉取分镜 flow'));
    await tester.pump();
    expect(flowKeyController.text, 'storyboard');
    expect(productionProbeCalls, 2);

    await tester.tap(find.text('4) 写回 flow'));
    await tester.pump();
    expect(productionWriteBackCalls, 1);

    await tester.tap(find.text('5) 运行分镜子代理'));
    await tester.pump();
    expect(flowKeyController.text, 'storyboard');
    expect(
      productionSubAgentToolController.text,
      'run_sub_agent_storyboard_gen',
    );
    expect(productionSubAgentCalls, 2);

    await tester.tap(find.text('6) 运行导演计划子代理'));
    await tester.pump();
    expect(flowKeyController.text, 'scriptPlan');
    expect(
      productionSubAgentToolController.text,
      'run_sub_agent_director_plan',
    );
    expect(productionSubAgentCalls, 3);
  });

  testWidgets('Production form blocks invalid JSON args before probe', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    var productionProbeCalls = 0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '制作工作区'));
    await tester.pumpAndSettle();

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

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'storyboard');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '制作工作区'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模板: 导演计划'));
    await tester.pump();
    expect(
      productionDomainArgsController.text,
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
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );
    var productionProbeCalls = 0;
    var productionSubAgentCalls = 0;

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: SingleChildScrollView(
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                workspaceLastToolResultData: <String, dynamic>{
                  'data': <dynamic>[],
                },
                workspaceSuggestedFlowKey: 'assets',
                workspaceWritebackLine: null,
                onRunScriptWorkspace: () {},
                onRunProductionWorkspace: () {},
                onProbeScriptDomainTool: (_, _) {},
                onProbeProductionDomainTool: () => productionProbeCalls += 1,
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '制作工作区'));
    await tester.pumpAndSettle();

    expect(find.text('下一步建议'), findsOneWidget);
    expect(find.text('先生成资产计划'), findsOneWidget);

    final recipeCard = find
        .ancestor(of: find.text('先生成资产计划'), matching: find.byType(Card))
        .first;
    final runSubAgentButton = find.descendant(
      of: recipeCard,
      matching: find.widgetWithText(FilledButton, '运行子代理'),
    );
    await tester.ensureVisible(runSubAgentButton);
    await tester.tap(runSubAgentButton);
    await tester.pump();

    expect(productionSubAgentCalls, 1);
    expect(flowKeyController.text, 'assets');
    expect(
      productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(productionPromptController.text, contains('空白 assets flow'));

    await tester.tap(find.widgetWithText(OutlinedButton, '应用建议').first);
    await tester.pump();
    expect(find.textContaining('已应用任务建议：先生成资产计划'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '使用该 key'));
    await tester.pump();
    expect(flowKeyController.text, 'assets');
    expect(productionProbeCalls, 0);
  });

  testWidgets('Production pane renders tool result text snapshot', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'scriptPlan');
    final productionDomainToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                initialPane: AgentWorkspacePane.production,
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('工具返回文本'), findsOneWidget);
    expect(find.textContaining('导演计划：先补资产'), findsWidgets);
  });

  testWidgets('Production probe auto-syncs get_flowData key in arguments', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 2400);
    tester.view.devicePixelRatio = 1.0;

    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'storyboard');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(
      text: '{"key":"assets"}',
    );
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    var productionProbeCalls = 0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '制作工作区'));
    await tester.pumpAndSettle();
    final probeButton = find.widgetWithText(FilledButton, '读取制作工具');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(productionProbeCalls, 1);
    expect(productionDomainArgsController.text, '{"key":"storyboard"}');
  });

  testWidgets('Production pane fills candidate storyboard ids from flow', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'storyboard');
    final productionDomainToolController = TextEditingController(
      text: 'generate_storyboard',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                initialPane: AgentWorkspacePane.production,
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () {},
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('当前 flow 候选参数'), findsOneWidget);
    expect(find.text('候选 3 项：101, 102, 103'), findsOneWidget);

    final fillButton = find.text('填充前 3 项');
    await tester.ensureVisible(fillButton);
    await tester.tap(fillButton);
    await tester.pump();

    expect(productionDomainArgsController.text, '{"ids":[101,102,103]}');
    expect(find.textContaining('已填充候选参数：填充前 3 项'), findsOneWidget);
  });

  testWidgets('Production stage board applies and advances stage actions', (
    WidgetTester tester,
  ) async {
    final projectIdController = TextEditingController(text: '1');
    final scriptIdController = TextEditingController(text: '2');
    final scriptPromptController = TextEditingController(text: '');
    final scriptDomainArgsController = TextEditingController(text: '{}');
    final productionPromptController = TextEditingController(text: '');
    final flowKeyController = TextEditingController(text: 'assets');
    final productionDomainToolController = TextEditingController(
      text: 'get_flowData',
    );
    final productionDomainArgsController = TextEditingController(text: '{}');
    final scriptSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_storySkeleton',
    );
    final productionSubAgentToolController = TextEditingController(
      text: 'run_sub_agent_director_plan',
    );

    var productionProbeCalls = 0;
    var productionSubAgentCalls = 0;

    addTearDown(() {
      projectIdController.dispose();
      scriptIdController.dispose();
      scriptPromptController.dispose();
      scriptDomainArgsController.dispose();
      productionPromptController.dispose();
      flowKeyController.dispose();
      productionDomainToolController.dispose();
      productionDomainArgsController.dispose();
      scriptSubAgentToolController.dispose();
      productionSubAgentToolController.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1800,
              child: AgentWorkspacesSection(
                initialPane: AgentWorkspacePane.production,
                projectIdController: projectIdController,
                scriptIdController: scriptIdController,
                scriptPromptController: scriptPromptController,
                scriptDomainArgsController: scriptDomainArgsController,
                productionPromptController: productionPromptController,
                flowKeyController: flowKeyController,
                productionDomainToolController: productionDomainToolController,
                productionDomainArgsController: productionDomainArgsController,
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
                scriptSubAgentToolController: scriptSubAgentToolController,
                productionSubAgentToolController:
                    productionSubAgentToolController,
                onRunScriptSubAgentTool: () {},
                onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
                onWriteBackScriptResult: () {},
                onWriteBackScriptPlanResult: () {},
                onWriteBackScriptPlanViaUpdateData: () {},
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('执行阶段'), findsOneWidget);
    expect(find.text('待规划'), findsOneWidget);
    expect(find.text('资产准备'), findsOneWidget);

    final advanceStageButton = find.widgetWithText(FilledButton, '推进阶段').first;
    await tester.ensureVisible(advanceStageButton);
    await tester.tap(advanceStageButton);
    await tester.pump();
    expect(productionSubAgentCalls, 1);
    expect(
      productionSubAgentToolController.text,
      'run_sub_agent_derive_assets',
    );
    expect(productionPromptController.text, isNotEmpty);

    final readFlowButton = find.text('读取 flow').first;
    await tester.ensureVisible(readFlowButton);
    await tester.tap(readFlowButton);
    await tester.pump();
    expect(productionProbeCalls, 1);
    expect(flowKeyController.text, 'scriptPlan');
    expect(productionDomainToolController.text, 'get_flowData');
    expect(
      productionDomainArgsController.text,
      '{"key":"scriptPlan","maxChars":2200}',
    );
  });
}
