import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/agent_workspaces_section.dart';

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
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Script workspace'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Production workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Run production'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Latest assistant text'), findsOneWidget);
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
            productionSubAgentToolController: productionSubAgentToolController,
            onRunScriptSubAgentTool: () => runSubAgentCalls += 1,
            onRunProductionSubAgentTool: () {},
            onWriteBackScriptResult: () => writeBackCalls += 1,
            onWriteBackScriptPlanResult: () {},
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

    await tester.tap(find.text('2) 拉取剧本正文'));
    await tester.pump();
    expect(lastProbedTool, 'get_script_content');
    expect(lastProbedArgs, contains('"scriptId":2'));

    await tester.tap(find.text('3) 生成剧本草稿'));
    await tester.pump();
    expect(runSubAgentCalls, 1);
    expect(scriptSubAgentToolController.text, 'run_sub_agent_script');
    expect(scriptPromptController.text, isNotEmpty);

    await tester.tap(find.text('4) 写回剧本'));
    await tester.pump();
    expect(writeBackCalls, 1);
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
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final probeButton = find.widgetWithText(FilledButton, 'Probe script data');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(probeCalls, 0);
    expect(
      find.text('拦截：script tool arguments JSON 解析失败。'),
      findsOneWidget,
    );
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
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'get_planData'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('get_script_content').last);
    await tester.pumpAndSettle();

    expect(find.text('模板: 当前 script'), findsOneWidget);
    expect(find.text('tool=get_script_content'), findsOneWidget);
    expect(find.text('plan.scriptRows=1'), findsOneWidget);

    await tester.tap(find.text('模板: 当前 script'));
    await tester.pump();
    expect(scriptDomainArgsController.text, '{"scriptId":9}');

    final probeButton = find.widgetWithText(FilledButton, 'Probe script data');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(lastTool, 'get_script_content');
    expect(lastArgs, '{"scriptId":9}');
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
            workspaceScriptWritebackSource: null,
            workspaceLastToolResultLine: 'line',
            workspaceSuggestedFlowKey: null,
            workspaceWritebackLine: null,
            onRunScriptWorkspace: () {},
            onRunProductionWorkspace: () {},
            onProbeScriptDomainTool: (_, _) {},
            onProbeProductionDomainTool: () => productionProbeCalls += 1,
            scriptSubAgentToolController: scriptSubAgentToolController,
            productionSubAgentToolController: productionSubAgentToolController,
            onRunScriptSubAgentTool: () {},
            onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
            onWriteBackScriptResult: () {},
            onWriteBackScriptPlanResult: () {},
            onWriteBackProductionFlowResult: () => productionWriteBackCalls += 1,
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Production workspace'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1) 拉取资产 flow'));
    await tester.pump();
    expect(flowKeyController.text, 'assets');
    expect(productionDomainToolController.text, 'get_flowData');
    expect(productionProbeCalls, 1);

    await tester.tap(find.text('2) 运行资产子代理'));
    await tester.pump();
    expect(productionSubAgentToolController.text, 'run_sub_agent_derive_assets');
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
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Production workspace'));
    await tester.pumpAndSettle();

    final probeButton = find.widgetWithText(FilledButton, 'Probe production tool');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(productionProbeCalls, 0);
    expect(
      find.text('拦截：production tool arguments JSON 解析失败。'),
      findsOneWidget,
    );
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
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Production workspace'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('模板: default assets'));
    await tester.pump();
    expect(productionDomainArgsController.text, '{"key":"assets"}');

    expect(find.text('Result summary'), findsOneWidget);
    expect(find.text('tool=get_flowData'), findsOneWidget);
    expect(find.text('storyboard.count=2'), findsOneWidget);
    expect(find.text('assets.count=3'), findsOneWidget);
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
                onWriteBackProductionFlowResult: () {},
                onApplySuggestedFlowKey: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Production workspace'));
    await tester.pumpAndSettle();
    final probeButton = find.widgetWithText(FilledButton, 'Probe production tool');
    await tester.ensureVisible(probeButton);
    await tester.tap(probeButton);
    await tester.pump();

    expect(productionProbeCalls, 1);
    expect(productionDomainArgsController.text, '{"key":"storyboard"}');
  });
}
