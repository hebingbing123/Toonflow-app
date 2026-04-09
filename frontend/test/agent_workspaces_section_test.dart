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
}
