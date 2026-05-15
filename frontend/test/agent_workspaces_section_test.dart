import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/agent_workspaces/controls.dart';
import 'package:openflow_app/agent_workspaces/section.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

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
    String scriptDomainTool = 'get_planData',
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
       scriptDomainToolController = TextEditingController(
         text: scriptDomainTool,
       ),
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
  final TextEditingController scriptDomainToolController;
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
    scriptDomainToolController.dispose();
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

AgentWorkspacesSection _buildSection({
  required _WorkspaceControllers controllers,
  AgentWorkspacePane initialPane = AgentWorkspacePane.script,
  bool loadingScriptWorkspaceRun = false,
  bool loadingProductionWorkspaceRun = false,
  bool loadingScriptDomainProbe = false,
  bool loadingProductionFlowProbe = false,
  bool loadingScriptSubAgentRun = false,
  bool loadingProductionSubAgentRun = false,
  bool loadingScriptResultWriteback = false,
  bool loadingScriptPlanResultWriteback = false,
  bool loadingProductionResultWriteback = false,
  List<String> wsLog = const <String>[],
  String workspaceAssistantText = '',
  String? workspaceScriptWritebackCandidate,
  Map<String, dynamic>? workspaceScriptPlanWritebackCandidate,
  int? workspaceScriptPlanRowId,
  String? workspaceScriptWritebackSource,
  String? workspaceLastToolResultLine,
  String? workspaceLastToolName,
  Object? workspaceLastToolResultData,
  Map<String, dynamic>? workspaceLastToolArguments,
  String? workspaceSuggestedFlowKey,
  String? workspaceWritebackLine,
  VoidCallback? onRunScriptWorkspace,
  VoidCallback? onRunProductionWorkspace,
  void Function(String toolName, String rawArgs)? onProbeScriptDomainTool,
  VoidCallback? onProbeProductionDomainTool,
  VoidCallback? onRunScriptSubAgentTool,
  VoidCallback? onRunProductionSubAgentTool,
  VoidCallback? onWriteBackScriptResult,
  VoidCallback? onWriteBackScriptPlanResult,
  VoidCallback? onWriteBackScriptPlanViaUpdateData,
  VoidCallback? onWriteBackProductionFlowResult,
  VoidCallback? onApplySuggestedFlowKey,
}) {
  return AgentWorkspacesSection(
    initialPane: initialPane,
    projectIdController: controllers.projectIdController,
    scriptIdController: controllers.scriptIdController,
    scriptPromptController: controllers.scriptPromptController,
    scriptDomainToolController: controllers.scriptDomainToolController,
    scriptDomainArgsController: controllers.scriptDomainArgsController,
    productionPromptController: controllers.productionPromptController,
    flowKeyController: controllers.flowKeyController,
    productionDomainToolController: controllers.productionDomainToolController,
    productionDomainArgsController: controllers.productionDomainArgsController,
    productionSubAgentArgsController:
        controllers.productionSubAgentArgsController,
    loadingScriptWorkspaceRun: loadingScriptWorkspaceRun,
    loadingProductionWorkspaceRun: loadingProductionWorkspaceRun,
    loadingScriptDomainProbe: loadingScriptDomainProbe,
    loadingProductionFlowProbe: loadingProductionFlowProbe,
    loadingScriptSubAgentRun: loadingScriptSubAgentRun,
    loadingProductionSubAgentRun: loadingProductionSubAgentRun,
    loadingScriptResultWriteback: loadingScriptResultWriteback,
    loadingScriptPlanResultWriteback: loadingScriptPlanResultWriteback,
    loadingProductionResultWriteback: loadingProductionResultWriteback,
    wsLog: wsLog,
    workspaceAssistantText: workspaceAssistantText,
    workspaceScriptWritebackCandidate: workspaceScriptWritebackCandidate,
    workspaceScriptPlanWritebackCandidate:
        workspaceScriptPlanWritebackCandidate,
    workspaceScriptPlanRowId: workspaceScriptPlanRowId,
    workspaceScriptWritebackSource: workspaceScriptWritebackSource,
    workspaceLastToolResultLine: workspaceLastToolResultLine,
    workspaceLastToolName: workspaceLastToolName,
    workspaceLastToolResultData: workspaceLastToolResultData,
    workspaceLastToolArguments: workspaceLastToolArguments,
    workspaceSuggestedFlowKey: workspaceSuggestedFlowKey,
    workspaceWritebackLine: workspaceWritebackLine,
    onRunScriptWorkspace: onRunScriptWorkspace ?? () {},
    onRunProductionWorkspace: onRunProductionWorkspace ?? () {},
    onProbeScriptDomainTool: onProbeScriptDomainTool ?? (_, _) {},
    onProbeProductionDomainTool: onProbeProductionDomainTool ?? () {},
    scriptSubAgentToolController: controllers.scriptSubAgentToolController,
    productionSubAgentToolController:
        controllers.productionSubAgentToolController,
    onRunScriptSubAgentTool: onRunScriptSubAgentTool ?? () {},
    onRunProductionSubAgentTool: onRunProductionSubAgentTool ?? () {},
    onWriteBackScriptResult: onWriteBackScriptResult ?? () {},
    onWriteBackScriptPlanResult: onWriteBackScriptPlanResult ?? () {},
    onWriteBackScriptPlanViaUpdateData:
        onWriteBackScriptPlanViaUpdateData ?? () {},
    onWriteBackProductionFlowResult: onWriteBackProductionFlowResult ?? () {},
    onApplySuggestedFlowKey: onApplySuggestedFlowKey ?? () {},
  );
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required _WorkspaceControllers controllers,
  AgentWorkspacePane initialPane = AgentWorkspacePane.script,
  bool loadingScriptWorkspaceRun = false,
  bool loadingProductionWorkspaceRun = false,
  bool loadingScriptDomainProbe = false,
  bool loadingProductionFlowProbe = false,
  bool loadingScriptSubAgentRun = false,
  bool loadingProductionSubAgentRun = false,
  bool loadingScriptResultWriteback = false,
  bool loadingScriptPlanResultWriteback = false,
  bool loadingProductionResultWriteback = false,
  List<String> wsLog = const <String>[],
  String workspaceAssistantText = '',
  String? workspaceScriptWritebackCandidate,
  Map<String, dynamic>? workspaceScriptPlanWritebackCandidate,
  int? workspaceScriptPlanRowId,
  String? workspaceScriptWritebackSource,
  String? workspaceLastToolResultLine,
  String? workspaceLastToolName,
  Object? workspaceLastToolResultData,
  Map<String, dynamic>? workspaceLastToolArguments,
  String? workspaceSuggestedFlowKey,
  String? workspaceWritebackLine,
  VoidCallback? onRunScriptWorkspace,
  VoidCallback? onRunProductionWorkspace,
  void Function(String toolName, String rawArgs)? onProbeScriptDomainTool,
  VoidCallback? onProbeProductionDomainTool,
  VoidCallback? onRunScriptSubAgentTool,
  VoidCallback? onRunProductionSubAgentTool,
  VoidCallback? onWriteBackScriptResult,
  VoidCallback? onWriteBackScriptPlanResult,
  VoidCallback? onWriteBackScriptPlanViaUpdateData,
  VoidCallback? onWriteBackProductionFlowResult,
  VoidCallback? onApplySuggestedFlowKey,
  double? width = 1800,
  bool addMaterial = false,
}) async {
  await _pumpAgentWorkspacesSection(
    tester,
    _buildSection(
      controllers: controllers,
      initialPane: initialPane,
      loadingScriptWorkspaceRun: loadingScriptWorkspaceRun,
      loadingProductionWorkspaceRun: loadingProductionWorkspaceRun,
      loadingScriptDomainProbe: loadingScriptDomainProbe,
      loadingProductionFlowProbe: loadingProductionFlowProbe,
      loadingScriptSubAgentRun: loadingScriptSubAgentRun,
      loadingProductionSubAgentRun: loadingProductionSubAgentRun,
      loadingScriptResultWriteback: loadingScriptResultWriteback,
      loadingScriptPlanResultWriteback: loadingScriptPlanResultWriteback,
      loadingProductionResultWriteback: loadingProductionResultWriteback,
      wsLog: wsLog,
      workspaceAssistantText: workspaceAssistantText,
      workspaceScriptWritebackCandidate: workspaceScriptWritebackCandidate,
      workspaceScriptPlanWritebackCandidate:
          workspaceScriptPlanWritebackCandidate,
      workspaceScriptPlanRowId: workspaceScriptPlanRowId,
      workspaceScriptWritebackSource: workspaceScriptWritebackSource,
      workspaceLastToolResultLine: workspaceLastToolResultLine,
      workspaceLastToolName: workspaceLastToolName,
      workspaceLastToolResultData: workspaceLastToolResultData,
      workspaceLastToolArguments: workspaceLastToolArguments,
      workspaceSuggestedFlowKey: workspaceSuggestedFlowKey,
      workspaceWritebackLine: workspaceWritebackLine,
      onRunScriptWorkspace: onRunScriptWorkspace,
      onRunProductionWorkspace: onRunProductionWorkspace,
      onProbeScriptDomainTool: onProbeScriptDomainTool,
      onProbeProductionDomainTool: onProbeProductionDomainTool,
      onRunScriptSubAgentTool: onRunScriptSubAgentTool,
      onRunProductionSubAgentTool: onRunProductionSubAgentTool,
      onWriteBackScriptResult: onWriteBackScriptResult,
      onWriteBackScriptPlanResult: onWriteBackScriptPlanResult,
      onWriteBackScriptPlanViaUpdateData: onWriteBackScriptPlanViaUpdateData,
      onWriteBackProductionFlowResult: onWriteBackProductionFlowResult,
      onApplySuggestedFlowKey: onApplySuggestedFlowKey,
    ),
    width: width,
    addMaterial: addMaterial,
  );
}

void main() {
  final zh = AppLocalizationsZh();

  group('Shared pane behavior', () {
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

      await _pumpSection(
        tester,
        controllers: controllers,
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
      );

      expect(find.text(zh.agentWorkspaceScriptCardTitle), findsOneWidget);

      await _switchPane(tester, AgentWorkspacePane.production);
      expect(find.text(zh.agentWorkspaceProductionRunWorkflow), findsOneWidget);

      await _switchPane(tester, AgentWorkspacePane.activity);
      expect(find.text(zh.agentWorkspaceActivityLatestAssistantText), findsOneWidget);
      expect(
        find.textContaining(zh.agentWorkspaceActivityLatest('harness.tool.result')),
        findsOneWidget,
      );
    });
  });

  group('Script workspace behavior', () {
    testWidgets('Script guided tasks trigger probe/sub-agent/writeback actions', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers();

      String? lastProbedTool;
      String? lastProbedArgs;
      var runSubAgentCalls = 0;
      var writeBackCalls = 0;

      _addWorkspaceTearDown(tester, controllers);

      await _pumpSection(
        tester,
        controllers: controllers,
        workspaceScriptWritebackCandidate: 'candidate',
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
        onProbeScriptDomainTool: (String toolName, String rawArgs) {
          lastProbedTool = toolName;
          lastProbedArgs = rawArgs;
        },
        onRunScriptSubAgentTool: () => runSubAgentCalls += 1,
        onWriteBackScriptResult: () => writeBackCalls += 1,
      );

      await tester.tap(find.text(zh.agentWorkspaceScriptStepFetchPlanData));
      await tester.pump();
      expect(lastProbedTool, 'get_planData');
      expect(lastProbedArgs, '{"key":"storySkeleton","maxChars":1600}');

      await tester.tap(find.text(zh.agentWorkspaceScriptStepFetchContent));
      await tester.pump();
      expect(lastProbedTool, 'get_script_content');
      expect(
        lastProbedArgs,
        '{"scriptId":2,"lineStart":61,"lineEnd":120,"maxChars":1600}',
      );

      await tester.tap(find.text(zh.agentWorkspaceScriptStepGenerateDraft));
      await tester.pump();
      expect(runSubAgentCalls, 1);
      expect(
        controllers.scriptSubAgentToolController.text,
        'run_sub_agent_script',
      );
      expect(
        controllers.scriptPromptController.text,
        zh.agentWorkspaceScriptGuidedGenerateDraftPrompt,
      );

      await tester.tap(find.text(zh.agentWorkspaceScriptStepWriteback).first);
      await tester.pump();
      expect(writeBackCalls, 1);
    });

    testWidgets('Script pane renders planData and tool context snapshots', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers(scriptPrompt: 'script prompt');
      _addWorkspaceTearDown(tester, controllers);

      await _pumpSection(
        tester,
        controllers: controllers,
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
        workspaceScriptWritebackSource: 'tool:get_script_content',
        workspaceLastToolResultLine: 'get_script_content => {...}',
        workspaceLastToolName: 'get_script_content',
        workspaceLastToolResultData: const <String, dynamic>{
          'content': '第 1 场：站台。雨幕里，女主看见熟悉背影。',
        },
      );

      expect(find.text(zh.agentWorkspaceScriptContextSnapshotTitle), findsOneWidget);
      expect(find.text(zh.agentWorkspaceScriptStageTitleStorySkeleton), findsWidgets);
      expect(find.textContaining('主角失去记忆后踏上回乡之路'), findsNWidgets(2));
      expect(find.text(zh.agentWorkspaceScriptStageTitleAdaptationStrategy), findsWidgets);
      expect(find.textContaining('聚焦母女关系'), findsNWidgets(2));
      expect(
        find.textContaining(zh.agentWorkspaceScriptContextRewriteConstraints),
        findsWidgets,
      );
      expect(
        find.textContaining(zh.agentWorkspaceScriptContextSkeletonFocus('')),
        findsOneWidget,
      );
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

      await _pumpSection(
        tester,
        controllers: controllers,
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

      await _pumpSection(
        tester,
        controllers: controllers,
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
        onProbeScriptDomainTool: (tool, args) {
          lastTool = tool;
          lastArgs = args;
        },
        onRunScriptSubAgentTool: () => subAgentCalls += 1,
      );

      expect(find.textContaining('get_novel_text'), findsWidgets);
      expect(find.textContaining('雨夜归乡'), findsOneWidget);
      expect(find.text(zh.agentWorkspaceScriptDiagnosisTitle), findsOneWidget);
      expect(find.text(zh.agentWorkspaceScriptRecipeReadMatchingEventsTitle), findsOneWidget);

      await _selectDropdownValue(
        tester,
        currentValue: 'get_planData',
        nextValue: 'get_novel_events',
      );

      expect(find.text(zh.agentWorkspaceScriptArgFillFirstChapter), findsOneWidget);

      await _tapButtonInCard(
        tester,
        buttonType: FilledButton,
        cardText: zh.agentWorkspaceScriptRecipeReadMatchingEventsTitle,
        buttonText: zh.agentWorkspaceScriptReadContext,
      );
      await tester.pump();
      expect(lastTool, 'get_novel_events');
      expect(
        lastArgs,
        '{"novelId":21,"fields":["numeric_id","name","detail"],"limit":8,"maxChars":1200}',
      );

      await tester.tap(find.widgetWithText(FilledButton, zh.agentWorkspaceScriptRunSubAgent).last);
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

      await _pumpSection(
        tester,
        controllers: controllers,
        initialPane: AgentWorkspacePane.script,
        workspaceScriptPlanWritebackCandidate: const <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '',
            'adaptationStrategy': '',
          },
        },
        workspaceLastToolResultLine: 'get_planData => {...}',
        workspaceLastToolName: 'get_planData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <String, dynamic>{
            'storySkeleton': '',
            'adaptationStrategy': '',
          },
        },
        onProbeScriptDomainTool: (tool, args) {
          lastTool = tool;
          lastArgs = args;
        },
        onRunScriptSubAgentTool: () => scriptSubAgentCalls += 1,
      );

      expect(find.text(zh.agentWorkspaceScriptStagesTitle), findsOneWidget);
      expect(find.text(zh.agentWorkspaceScriptStageStatusPendingGenerate), findsWidgets);

      final advanceStageButton = _buttonInCard(
        FilledButton,
        zh.agentWorkspaceScriptStageTitleStorySkeleton,
        zh.agentWorkspaceScriptAdvanceStage,
      );
      await tester.ensureVisible(advanceStageButton);
      await tester.tap(advanceStageButton);
      await tester.pump();
      expect(scriptSubAgentCalls, 1);
      expect(
        controllers.scriptSubAgentToolController.text,
        'run_sub_agent_storySkeleton',
      );
      expect(controllers.scriptPromptController.text, isNotEmpty);

      final readContextButton = _buttonInCard(
        FilledButton,
        zh.agentWorkspaceScriptStageTitleChapterMaterial,
        zh.agentWorkspaceScriptReadContext,
      );
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

      await _pumpSection(
        tester,
        controllers: controllers,
        onProbeScriptDomainTool: (_, _) => probeCalls += 1,
      );

      final probeButton = find.widgetWithText(FilledButton, zh.agentWorkspaceScriptReadContext).first;
      await tester.ensureVisible(probeButton);
      await tester.tap(probeButton);
      await tester.pump();

      expect(probeCalls, 0);
      expect(find.text(zh.agentWorkspaceScriptInterceptArgsJsonParseFailed), findsOneWidget);
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

      await _pumpSection(
        tester,
        controllers: controllers,
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
        onProbeScriptDomainTool: (tool, args) {
          lastTool = tool;
          lastArgs = args;
        },
      );

      await _selectDropdownValue(
        tester,
        currentValue: 'get_planData',
        nextValue: 'get_script_content',
      );

      expect(find.text(zh.agentWorkspaceScriptArgTemplateCurrentWindow), findsOneWidget);
      expect(find.text('tool=get_script_content'), findsOneWidget);
      expect(find.text('plan.scriptRows=1'), findsOneWidget);

      await tester.tap(find.text(zh.agentWorkspaceScriptArgTemplateCurrentWindow));
      await tester.pump();
      expect(
        controllers.scriptDomainArgsController.text,
        '{"scriptId":9,"lineStart":1,"lineEnd":80,"maxChars":2200}',
      );

      final probeButton = find.widgetWithText(FilledButton, zh.agentWorkspaceScriptReadContext).last;
      await tester.ensureVisible(probeButton);
      await tester.tap(probeButton);
      await tester.pump();

      expect(lastTool, 'get_script_content');
      expect(
        lastArgs,
        '{"scriptId":9,"lineStart":1,"lineEnd":80,"maxChars":2200}',
      );
    });

    testWidgets('Script domain tool follows external controller updates', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers(scriptId: '9');
      String? lastTool;
      String? lastArgs;

      _addWorkspaceTearDown(tester, controllers);

      await _pumpAgentWorkspacesSection(
        tester,
        _buildSection(
          controllers: controllers,
          onProbeScriptDomainTool: (tool, args) {
            lastTool = tool;
            lastArgs = args;
          },
        ),
      );

      expect(find.text('tool=get_planData'), findsOneWidget);

      controllers.scriptDomainToolController.text = 'get_script_content';
      controllers.scriptDomainArgsController.text =
          '{"scriptId":9,"lineStart":61,"lineEnd":120,"maxChars":1600}';

      await _pumpAgentWorkspacesSection(
        tester,
        _buildSection(
          controllers: controllers,
          onProbeScriptDomainTool: (tool, args) {
            lastTool = tool;
            lastArgs = args;
          },
        ),
      );

      expect(find.text('tool=get_script_content'), findsOneWidget);

      final probeButton = find
          .widgetWithText(FilledButton, zh.agentWorkspaceScriptReadContext)
          .last;
      await tester.ensureVisible(probeButton);
      await tester.tap(probeButton);
      await tester.pump();

      expect(lastTool, 'get_script_content');
      expect(
        lastArgs,
        '{"scriptId":9,"lineStart":61,"lineEnd":120,"maxChars":1600}',
      );
    });
  });

  group('Production workspace behavior', () {
    testWidgets('Production guided tasks update flow context and callbacks', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers();

      var productionProbeCalls = 0;
      var productionSubAgentCalls = 0;
      var productionWriteBackCalls = 0;

      _addWorkspaceTearDown(tester, controllers);

      await _pumpSection(
        tester,
        controllers: controllers,
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
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
        onWriteBackProductionFlowResult: () => productionWriteBackCalls += 1,
      );

      await _switchPane(tester, AgentWorkspacePane.production);

      await tester.tap(find.text(zh.agentWorkspaceProductionStepPullAssetsFlow));
      await tester.pump();
      expect(controllers.flowKeyController.text, 'assets');
      expect(controllers.productionDomainToolController.text, 'get_flowData');
      expect(productionProbeCalls, 1);

      await tester.tap(find.text(zh.agentWorkspaceProductionStepRunAssetsSubAgent));
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

      await tester.tap(find.text(zh.agentWorkspaceProductionStepPullStoryboardFlow));
      await tester.pump();
      expect(controllers.flowKeyController.text, 'storyboard');
      expect(productionProbeCalls, 2);

      await tester.tap(find.text(zh.agentWorkspaceProductionStepWritebackFlow));
      await tester.pump();
      expect(productionWriteBackCalls, 1);

      await tester.tap(find.text(zh.agentWorkspaceProductionStepRunStoryboardSubAgent));
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

      await tester.tap(find.text(zh.agentWorkspaceProductionStepRunDirectorPlanSubAgent));
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

    // Production input helpers and guards.
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

      await _pumpSection(
        tester,
        controllers: controllers,
        initialPane: AgentWorkspacePane.production,
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

      await _pumpSection(
        tester,
        controllers: controllers,
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
      );

      await _switchPane(tester, AgentWorkspacePane.production);

      final probeButton = find.widgetWithText(FilledButton, zh.agentWorkspaceProductionReadTool);
      await tester.ensureVisible(probeButton);
      await tester.tap(probeButton);
      await tester.pump();

      expect(productionProbeCalls, 0);
      expect(find.text(zh.agentWorkspaceProductionInterceptArgsJsonParseFailed), findsOneWidget);
    });

    testWidgets('Production argument templates and result summary render', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 2400);
      tester.view.devicePixelRatio = 1.0;

      final controllers = _WorkspaceControllers(flowKey: 'storyboard');
      _addWorkspaceTearDown(tester, controllers, resetView: true);

      await _pumpSection(
        tester,
        controllers: controllers,
        workspaceLastToolResultLine:
            'get_flowData => {"data":{"storyboard":[1,2]}}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: <String, dynamic>{
          'data': <String, dynamic>{
            'storyboard': <int>[1, 2],
            'assets': <int>[3, 4, 5],
          },
        },
      );

      await _switchPane(tester, AgentWorkspacePane.production);

      await tester.tap(find.text(zh.agentWorkspaceProductionArgTemplateDirectorPlan));
      await tester.pump();
      expect(
        controllers.productionDomainArgsController.text,
        '{"key":"scriptPlan","maxChars":2200}',
      );

      expect(find.text(zh.agentWorkspaceProductionResultSummary), findsOneWidget);
      expect(find.text('tool=get_flowData'), findsOneWidget);
      expect(find.text(zh.agentWorkspaceProductionSummaryObjectKeyCount(2)), findsOneWidget);
      expect(
        find.text(zh.agentWorkspaceProductionSummaryObjectListEntry('storyboard', 2)),
        findsOneWidget,
      );
      expect(
        find.text(zh.agentWorkspaceProductionSummaryObjectListEntry('assets', 3)),
        findsOneWidget,
      );
      expect(find.text(zh.agentWorkspaceProductionContextSnapshotTitle), findsOneWidget);
      expect(find.text('flow[storyboard]'), findsOneWidget);
      expect(find.text('flow[assets]'), findsOneWidget);
    });

    testWidgets(
      'Production diagnosis card applies and runs suggested actions',
      (WidgetTester tester) async {
        final controllers = _WorkspaceControllers();
        var productionProbeCalls = 0;
        var productionSubAgentCalls = 0;

        _addWorkspaceTearDown(tester, controllers);

        await _pumpSection(
          tester,
          controllers: controllers,
          workspaceLastToolResultLine: 'get_flowData => {"data":[]}',
          workspaceLastToolName: 'get_flowData',
          workspaceLastToolResultData: <String, dynamic>{'data': <dynamic>[]},
          workspaceSuggestedFlowKey: 'assets',
          onProbeProductionDomainTool: () => productionProbeCalls += 1,
          onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
          width: null,
          addMaterial: true,
        );

        await _switchPane(tester, AgentWorkspacePane.production);

        expect(find.text(zh.agentWorkspaceProductionDiagnosisTitle), findsOneWidget);
        expect(find.text(zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstTitle), findsOneWidget);
        expect(find.text(zh.agentWorkspaceProductionPromptPreviewTitle), findsWidgets);
        expect(
          find.textContaining(zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstPrompt),
          findsWidgets,
        );

        await _tapButtonInCard(
          tester,
          buttonType: FilledButton,
          cardText: zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstTitle,
          buttonText: zh.agentWorkspaceProductionSubAgentAdvanceStage,
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
          contains(zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstPrompt),
        );

        await _tapButtonInCard(
          tester,
          buttonType: OutlinedButton,
          cardText: zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstTitle,
          buttonText: zh.agentWorkspaceProductionApplySuggestion,
        );
        await tester.pump();
        expect(
          find.textContaining(
            zh.agentWorkspaceProductionRecipeAppliedGeneric(
              zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstTitle,
            ),
          ),
          findsOneWidget,
        );

        final useFlowKeyButton = find.widgetWithText(
          OutlinedButton,
          zh.agentWorkspaceProductionUseSuggestedFlowKey,
        );
        await tester.ensureVisible(useFlowKeyButton);
        await tester.tap(useFlowKeyButton);
        await tester.pump();
        expect(controllers.flowKeyController.text, 'assets');
        expect(productionProbeCalls, 0);
      },
    );

    // Production result summaries and snapshots.
    testWidgets('Production pane renders tool result text snapshot', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers(
        flowKey: 'scriptPlan',
        productionDomainTool: 'run_sub_agent_director_plan',
        productionSubAgentTool: 'run_sub_agent_director_plan',
      );
      _addWorkspaceTearDown(tester, controllers);

      await _pumpSection(
        tester,
        controllers: controllers,
        initialPane: AgentWorkspacePane.production,
        workspaceLastToolResultLine:
            'run_sub_agent_director_plan => {"result":"导演计划：先补资产，再细化分镜。"}',
        workspaceLastToolName: 'run_sub_agent_director_plan',
        workspaceLastToolResultData: const <String, dynamic>{
          'result': '导演计划：先补资产，再细化分镜。',
        },
        workspaceSuggestedFlowKey: 'scriptPlan',
      );

      expect(find.text(zh.agentWorkspaceProductionContextToolText), findsOneWidget);
      expect(find.textContaining('导演计划：先补资产'), findsWidgets);
    });

    testWidgets(
      'Production pane renders single flow snapshot for get_flowData',
      (WidgetTester tester) async {
        final controllers = _WorkspaceControllers(
          flowKey: 'storyboard',
          productionDomainArgs: '{"key":"storyboard"}',
        );
        _addWorkspaceTearDown(tester, controllers);

        await _pumpSection(
          tester,
          controllers: controllers,
          initialPane: AgentWorkspacePane.production,
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
        );

        expect(find.text('flow[storyboard]'), findsOneWidget);
        expect(find.textContaining(zh.agentWorkspaceProductionSummaryMissingFrames(1)), findsWidgets);
        expect(find.textContaining(zh.agentWorkspaceProductionStoryboardShotsHashShort(101)), findsWidgets);
        expect(
          find.textContaining(
            zh.agentWorkspaceProductionStageDetailStoryboardMissingSkipped(1),
          ),
          findsWidgets,
        );
        expect(find.textContaining(zh.agentWorkspaceProductionStoryboardShotsHashShort(102)), findsNothing);
      },
    );

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

      await _pumpSection(
        tester,
        controllers: controllers,
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
      );

      await _switchPane(tester, AgentWorkspacePane.production);
      final probeButton = find.widgetWithText(FilledButton, zh.agentWorkspaceProductionReadTool);
      await tester.ensureVisible(probeButton);
      await tester.tap(probeButton);
      await tester.pump();

      expect(productionProbeCalls, 1);
      expect(
        controllers.productionDomainArgsController.text,
        '{"key":"storyboard"}',
      );
    });

    // Production candidate extraction.
    testWidgets('Production pane fills candidate storyboard ids from flow', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers(
        flowKey: 'storyboard',
        productionDomainTool: 'generate_storyboard',
      );
      _addWorkspaceTearDown(tester, controllers);

      await _pumpSection(
        tester,
        controllers: controllers,
        initialPane: AgentWorkspacePane.production,
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
      );

      expect(find.text(zh.agentWorkspaceProductionCurrentCandidateArgs), findsOneWidget);
      expect(
        find.text(zh.agentWorkspaceProductionCandidateIds(3, '101, 102, 103')),
        findsOneWidget,
      );

      final fillButton = find.text(zh.agentWorkspaceProductionArgSuggestFillFirstThree);
      await tester.ensureVisible(fillButton);
      await tester.tap(fillButton);
      await tester.pump();

      expect(
        controllers.productionDomainArgsController.text,
        '{"ids":[101,102,103]}',
      );
      expect(
        find.textContaining(
          zh.agentWorkspaceFilledCandidateArgs(
            zh.agentWorkspaceProductionArgSuggestFillFirstThree,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Production pane fills focused storyboard ids from supervision review',
      (WidgetTester tester) async {
        final controllers = _WorkspaceControllers(
          flowKey: 'storyboard',
          productionDomainTool: 'generate_storyboard',
        );
        _addWorkspaceTearDown(tester, controllers);

        await _pumpSection(
          tester,
          controllers: controllers,
          initialPane: AgentWorkspacePane.production,
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
        );

        expect(find.text(zh.agentWorkspaceProductionCurrentCandidateArgs), findsOneWidget);
        expect(
          find.text(zh.agentWorkspaceProductionCandidateIds(2, '3, 9')),
          findsOneWidget,
        );

        final fillButton = find.text(zh.agentWorkspaceProductionArgSuggestFillFirstThree);
        await tester.ensureVisible(fillButton);
        await tester.tap(fillButton);
        await tester.pump();

        expect(
          controllers.productionDomainArgsController.text,
          '{"ids":[3,9]}',
        );
        expect(
          find.textContaining(
            zh.agentWorkspaceFilledCandidateArgs(
              zh.agentWorkspaceProductionArgSuggestFillFirstThree,
            ),
          ),
          findsOneWidget,
        );
      },
    );

    // Production stage execution.
    testWidgets('Production stage board applies and advances stage actions', (
      WidgetTester tester,
    ) async {
      final controllers = _WorkspaceControllers();

      var productionProbeCalls = 0;
      var productionSubAgentCalls = 0;

      _addWorkspaceTearDown(tester, controllers);

      await _pumpSection(
        tester,
        controllers: controllers,
        initialPane: AgentWorkspacePane.production,
        workspaceLastToolResultLine: 'get_flowData => {"data":[]}',
        workspaceLastToolName: 'get_flowData',
        workspaceLastToolResultData: const <String, dynamic>{
          'data': <Map<String, dynamic>>[],
        },
        workspaceSuggestedFlowKey: 'assets',
        onProbeProductionDomainTool: () => productionProbeCalls += 1,
        onRunProductionSubAgentTool: () => productionSubAgentCalls += 1,
      );

      expect(find.text(zh.agentWorkspaceProductionStagesTitle), findsOneWidget);
      expect(
        find.textContaining(
          '当前卡点：${zh.agentWorkspaceProductionStageFlowScriptPlan} · ${zh.agentWorkspaceScriptStageStatusPendingRead}',
        ),
        findsOneWidget,
      );
      expect(find.text(zh.agentWorkspaceProductionStageStatusWaitingScriptPlan), findsWidgets);
      expect(find.text(zh.agentWorkspaceProductionStageFlowAssets), findsOneWidget);
      expect(find.text(zh.agentWorkspaceProductionPromptPreviewTitle), findsWidgets);
      expect(
        find.textContaining(zh.agentWorkspaceProductionFlowRecipeAssetsPlanFirstPrompt),
        findsWidgets,
      );

      final advanceStageButton = _buttonInCard(
        FilledButton,
        zh.agentWorkspaceProductionStageFlowAssets,
        zh.agentWorkspaceProductionSubAgentAdvanceStage,
      );
      await tester.ensureVisible(advanceStageButton);
      await tester.tap(advanceStageButton);
      await tester.pump();
      expect(productionSubAgentCalls, 1);
      expect(
        controllers.productionSubAgentToolController.text,
        'run_sub_agent_derive_assets',
      );
      expect(controllers.productionPromptController.text, isNotEmpty);

      final readFlowButton = _buttonInCard(
        FilledButton,
        zh.agentWorkspaceProductionStageFlowScriptPlan,
        zh.agentWorkspaceProductionDomainReadFlow,
      );
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
  });
}
