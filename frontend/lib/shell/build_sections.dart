// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageBuildSections on _HomePageState {
  List<Widget> _buildHomePageSections(BuildContext context, Session? session) {
    final signedIn = session != null;
    final widgets = <Widget>[
      _buildOverviewSection(),
      _buildAuthSection(session, signedIn),
    ];

    if (signedIn) {
      widgets.add(_buildWorkspaceModeSection(context));
      widgets.addAll(
        _homeSectionMode == _HomeSectionMode.product
            ? _buildProductSections(context)
            : _buildDebugSections(),
      );
    }

    widgets.addAll(_buildErrorSection(context));
    return widgets;
  }

  Widget _buildOverviewSection() => OverviewSection(
    apiBaseUrl: kApiBaseUrl,
    loadingHealth: _loadingHealth,
    loadingHealthRoot: _loadingHealthRoot,
    loadingPing: _loadingPing,
    loadingVersion: _loadingVersion,
    loadingReady: _loadingReady,
    healthBody: _healthBody,
    healthRootBody: _healthRootBody,
    pingBody: _pingBody,
    versionBody: _versionBody,
    readyBody: _readyBody,
    onPingHealth: _overviewController.pingHealth,
    onPingHealthRoot: _overviewController.pingHealthRoot,
    onPingPing: _overviewController.pingPing,
    onPingVersion: _overviewController.pingVersion,
    onPingReady: _overviewController.pingReady,
  );

  Widget _buildAuthSection(Session? session, bool signedIn) => AuthSection(
    signedIn: signedIn,
    session: session,
    emailController: _email,
    passwordController: _password,
    loadingMe: _loadingMe,
    loadingDevSwitchProbe: _loadingDevSwitchProbe,
    loadingMemoryConfigProbe: _loadingMemoryConfigProbe,
    loadingAboutProbe: _loadingAboutProbe,
    loadingUsageSummary: _loadingUsageSummary,
    loadingPromptsProbe: _loadingPromptsProbe,
    loadingVisualManualProbe: _loadingVisualManualProbe,
    loadingDirectorManualProbe: _loadingDirectorManualProbe,
    loadingSkillsBinaryProbe: _loadingSkillsBinaryProbe,
    loadingModelsCatalog: _loadingModelsCatalog,
    loadingTextModelDefault: _loadingTextModelDefault,
    loadingModelDetail: _loadingModelDetail,
    meBody: _meBody,
    devSwitchProbeBody: _devSwitchProbeBody,
    memoryConfigProbeBody: _memoryConfigProbeBody,
    aboutProbeBody: _aboutProbeBody,
    usageSummaryBody: _usageSummaryBody,
    promptsProbeBody: _promptsProbeBody,
    visualManualProbeBody: _visualManualProbeBody,
    directorManualProbeBody: _directorManualProbeBody,
    skillsBinaryProbeBody: _skillsBinaryProbeBody,
    modelsCatalogBody: _modelsCatalogBody,
    textModelDefaultBody: _textModelDefaultBody,
    modelDetailBody: _modelDetailBody,
    onSignIn: _signIn,
    onSignUp: _signUp,
    onSignOut: _signOut,
    onCallMe: _callMe,
    onCallDevSwitchProbe: _callDevSwitchProbe,
    onCallMemoryConfigProbe: _callMemoryConfigProbe,
    onCallAboutProbe: _callAboutProbe,
    onCallUsageSummary: _callUsageSummary,
    onCallPromptsProbe: _callPromptsProbe,
    onCallVisualManualProbe: _callVisualManualProbe,
    onCallDirectorManualProbe: _callDirectorManualProbe,
    onCallSkillsBinaryProbe: _callSkillsBinaryProbe,
    onCallModelsCatalog: _callModelsCatalog,
    onCallTextModelDefault: _callTextModelDefault,
    onCallModelDetail: _callModelDetail,
  );

  Widget _buildWorkspaceModeSection(BuildContext context) {
    final selected = <_HomeSectionMode>{_homeSectionMode};
    final isProduct = _homeSectionMode == _HomeSectionMode.product;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Workspace mode', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<_HomeSectionMode>(
            segments: const <ButtonSegment<_HomeSectionMode>>[
              ButtonSegment<_HomeSectionMode>(
                value: _HomeSectionMode.product,
                label: Text('Product workspace'),
              ),
              ButtonSegment<_HomeSectionMode>(
                value: _HomeSectionMode.debug,
                label: Text('Ops and debug'),
              ),
            ],
            selected: selected,
            onSelectionChanged: (selection) {
              final nextMode = selection.firstOrNull;
              if (nextMode == null || nextMode == _homeSectionMode) {
                return;
              }
              setState(() => _homeSectionMode = nextMode);
            },
          ),
          const SizedBox(height: 8),
          Text(
            isProduct
                ? '当前聚焦用户工作流：项目、Agent 工作区、任务与质量。'
                : '当前聚焦运维探针：Harness 工具目录、WS 探测与系统诊断。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProductPaneSelector(BuildContext context) {
    final paneEntries = <(_ProductWorkspacePane, String)>[
      (_ProductWorkspacePane.projects, '项目'),
      (_ProductWorkspacePane.scriptWorkspace, '脚本工作区'),
      (_ProductWorkspacePane.productionWorkspace, '制作工作区'),
      (_ProductWorkspacePane.workspaceActivity, '工作区动态'),
      (_ProductWorkspacePane.tasks, '任务中心'),
      (_ProductWorkspacePane.jobs, '任务作业'),
      (_ProductWorkspacePane.quality, '质量评审'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('产品导航', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: paneEntries
                .map((entry) {
                  final pane = entry.$1;
                  return ChoiceChip(
                    label: Text(entry.$2),
                    selected: _productWorkspacePane == pane,
                    onSelected: (selected) {
                      if (!selected || pane == _productWorkspacePane) {
                        return;
                      }
                      setState(() => _productWorkspacePane = pane);
                    },
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentWorkspacePane({
    required AgentWorkspacePane initialPane,
    required String sectionTitle,
    required String sectionDescription,
  }) {
    return AgentWorkspacesSection(
      initialPane: initialPane,
      showPaneSelector: false,
      sectionTitle: sectionTitle,
      sectionDescription: sectionDescription,
      projectIdController: _agentWorkspaceProjectIdCtrl,
      scriptIdController: _agentWorkspaceScriptIdCtrl,
      scriptPromptController: _scriptWorkspacePromptCtrl,
      scriptDomainArgsController: _scriptDomainArgsCtrl,
      productionPromptController: _productionWorkspacePromptCtrl,
      flowKeyController: _productionFlowKeyCtrl,
      productionDomainToolController: _productionDomainToolCtrl,
      productionDomainArgsController: _productionDomainArgsCtrl,
      loadingScriptWorkspaceRun: _loadingScriptWorkspaceRun,
      loadingProductionWorkspaceRun: _loadingProductionWorkspaceRun,
      loadingScriptDomainProbe: _loadingScriptDomainProbe,
      loadingProductionFlowProbe: _loadingProductionFlowProbe,
      loadingScriptSubAgentRun: _loadingScriptSubAgentRun,
      loadingProductionSubAgentRun: _loadingProductionSubAgentRun,
      loadingScriptResultWriteback: _loadingScriptResultWriteback,
      loadingScriptPlanResultWriteback: _loadingScriptPlanResultWriteback,
      loadingProductionResultWriteback: _loadingProductionResultWriteback,
      wsLog: _wsLog,
      workspaceAssistantText: _workspaceAssistantText,
      workspaceScriptWritebackCandidate: _workspaceScriptWritebackCandidate,
      workspaceScriptPlanWritebackCandidate:
          _workspaceScriptPlanWritebackCandidate,
      workspaceScriptPlanRowId: _workspaceScriptPlanRowId,
      workspaceScriptWritebackSource: _workspaceScriptWritebackSource,
      workspaceLastToolResultLine: _workspaceLastToolResultLine,
      workspaceLastToolName: _workspaceLastToolName,
      workspaceLastToolResultData: _workspaceLastToolResultData,
      workspaceSuggestedFlowKey: _workspaceSuggestedFlowKey,
      workspaceWritebackLine: _workspaceWritebackLine,
      onRunScriptWorkspace: _runScriptWorkspaceAgent,
      onRunProductionWorkspace: _runProductionWorkspaceAgent,
      onProbeScriptDomainTool: _probeScriptDomainTool,
      onProbeProductionDomainTool: _probeProductionDomainTool,
      scriptSubAgentToolController: _scriptSubAgentToolCtrl,
      productionSubAgentToolController: _productionSubAgentToolCtrl,
      onRunScriptSubAgentTool: _runScriptSubAgentTool,
      onRunProductionSubAgentTool: _runProductionSubAgentTool,
      onWriteBackScriptResult: _writeBackScriptWorkspaceResult,
      onWriteBackScriptPlanResult: _writeBackScriptPlanWorkspaceResult,
      onWriteBackScriptPlanViaUpdateData: _writeBackScriptPlanViaUpdateData,
      onWriteBackProductionFlowResult: _writeBackProductionFlowResult,
      onApplySuggestedFlowKey: _applySuggestedProductionFlowKey,
    );
  }

  List<Widget> _buildProductSections(BuildContext context) => [
    _buildProductPaneSelector(context),
    if (_productWorkspacePane == _ProductWorkspacePane.projects)
      ProjectsSection(
        accessToken: _session?.accessToken,
        controller: _projectsController,
        onOpenProjectDetail: _openProjectDetail,
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.scriptWorkspace)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.script,
        sectionTitle: '剧本工作区',
        sectionDescription: '专注剧本 Agent 工作流：上下文探测、子 Agent 编排与正文/计划回写。',
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.productionWorkspace)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.production,
        sectionTitle: '制作工作区',
        sectionDescription: '专注 production Agent 工作流：flow 数据读取、资产/分镜工具执行与安全回写。',
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.workspaceActivity)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.activity,
        sectionTitle: '执行动态',
        sectionDescription: '集中查看最近 WS 事件、工具回执与回写状态，作为统一执行日志面板。',
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.tasks)
      TaskCenterSection(
        accessToken: _session?.accessToken,
        loadingTaskProjects: _taskCenterController.loadingTaskProjects,
        loadingTaskCategories: _taskCenterController.loadingTaskCategories,
        loadingTaskApi: _taskCenterController.loadingTaskApi,
        loadingTaskDetailsByNumericId:
            _taskCenterController.loadingTaskDetailsByNumericId,
        loadingTaskDetailsUuid: _taskCenterController.loadingTaskDetailsUuid,
        taskDetailJobIdController:
            _taskCenterController.taskDetailJobIdController,
        taskProjects: _taskCenterController.taskProjects,
        taskCategoriesLine: _taskCenterController.taskCategoriesLine,
        taskApiSummaryLine: _taskCenterController.taskApiSummaryLine,
        taskDetailNumericIdLine: _taskCenterController.taskDetailNumericIdLine,
        taskDetailUuidLine: _taskCenterController.taskDetailUuidLine,
        taskApiJobs: _taskCenterController.taskApiJobs,
        onTaskDetailJobIdChanged: (_) =>
            _taskCenterController.notifyJobIdChanged(),
        onLoadTaskProjects: _taskCenterController.loadTaskProjects,
        onLoadTaskCategories: _taskCenterController.loadTaskCategories,
        onLoadTaskApi: _taskCenterController.loadTaskApi,
        onProbeTaskDetailByNumericId:
            _taskCenterController.probeTaskDetailByNumericId,
        onProbeTaskDetailUuid: _taskCenterController.probeTaskDetailUuid,
        onSelectTaskJob: _taskCenterController.selectTaskJob,
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.jobs)
      JobsSection(controller: _jobsController),
    if (_productWorkspacePane == _ProductWorkspacePane.quality)
      QualityReviewsSection(
        accessToken: _session?.accessToken,
        controller: _qualityReviewsController,
      ),
  ];

  List<Widget> _buildDebugSections() => [
    HarnessSection(
      loadingHarnessTools: _skillsHarnessController.loadingHarnessTools,
      loadingSkillsSummary: _skillsHarnessController.loadingSkillsSummary,
      loadingSkillList: _skillsHarnessController.loadingSkillList,
      loadingSkillPreview: _skillsHarnessController.loadingSkillPreview,
      loadingSkillPut: _skillsHarnessController.loadingSkillPut,
      loadingSkillPost: _skillsHarnessController.loadingSkillPost,
      loadingSkillDelete: _skillsHarnessController.loadingSkillDelete,
      wsProbesBusy: _wsProbesBusy,
      loadingWs: _loadingWs,
      loadingWsHarness: _loadingWsHarness,
      loadingWsIsolatedEcho: _loadingWsIsolatedEcho,
      loadingWsWasmProbe: _loadingWsWasmProbe,
      loadingWsSkillsRead: _loadingWsSkillsRead,
      loadingWsHarnessAgent: _loadingWsHarnessAgent,
      harnessToolsLine: _skillsHarnessController.harnessToolsLine,
      skillsAggregateLine: _skillsHarnessController.skillsAggregateLine,
      skillsListSummary: _skillsHarnessController.skillsListSummary,
      skillMutationLine: _skillsHarnessController.skillMutationLine,
      skillPathController: _skillsHarnessController.skillPathController,
      skillContentController: _skillsHarnessController.skillContentController,
      wsLog: _wsLog,
      onLoadHarnessTools: _skillsHarnessController.loadHarnessTools,
      onLoadSkillsAggregate: _skillsHarnessController.loadSkillsAggregate,
      onLoadSkillList: _skillsHarnessController.loadSkillList,
      onPreviewSkillFile: () =>
          _skillsHarnessController.previewSkillFile(context),
      onPutSkillProbe: _skillsHarnessController.putSkillProbe,
      onPostSkillProbe: _skillsHarnessController.postSkillProbe,
      onDeleteSkillProbe: _skillsHarnessController.deleteSkillProbe,
      onTestWebSocket: _skillsHarnessController.testWebSocket,
      onTestHarnessToolWebSocket:
          _skillsHarnessController.testHarnessToolWebSocket,
      onTestHarnessIsolatedEchoWebSocket:
          _skillsHarnessController.testHarnessIsolatedEchoWebSocket,
      onTestHarnessWasmProbeWebSocket:
          _skillsHarnessController.testHarnessWasmProbeWebSocket,
      onTestHarnessSkillsReadWebSocket:
          _skillsHarnessController.testHarnessSkillsReadWebSocket,
      onTestHarnessAgentRunWebSocket:
          _skillsHarnessController.testHarnessAgentRunWebSocket,
    ),
  ];

  List<Widget> _buildErrorSection(BuildContext context) {
    if (_error == null) return const [];
    return [
      const SizedBox(height: 16),
      Text(
        '错误: $_error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ];
  }
}
