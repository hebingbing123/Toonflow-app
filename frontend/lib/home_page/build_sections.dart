// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

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
    onPingHealth: _pingHealth,
    onPingHealthRoot: _pingHealthRoot,
    onPingPing: _pingPing,
    onPingVersion: _pingVersion,
    onPingReady: _pingReady,
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
      (_ProductWorkspacePane.projects, 'Projects'),
      (_ProductWorkspacePane.scriptWorkspace, 'Script Workspace'),
      (_ProductWorkspacePane.productionWorkspace, 'Production Workspace'),
      (_ProductWorkspacePane.workspaceActivity, 'Workspace Activity'),
      (_ProductWorkspacePane.tasks, 'Task Center'),
      (_ProductWorkspacePane.jobs, 'Jobs'),
      (_ProductWorkspacePane.quality, 'Quality Reviews'),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Product navigation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
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
      workspaceScriptPlanWritebackCandidate: _workspaceScriptPlanWritebackCandidate,
      workspaceScriptWritebackSource: _workspaceScriptWritebackSource,
      workspaceLastToolResultLine: _workspaceLastToolResultLine,
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
      onWriteBackProductionFlowResult: _writeBackProductionFlowResult,
      onApplySuggestedFlowKey: _applySuggestedProductionFlowKey,
    );
  }

  List<Widget> _buildProductSections(BuildContext context) => [
    _buildProductPaneSelector(context),
    if (_productWorkspacePane == _ProductWorkspacePane.projects)
      ProjectsSection(
        loadingProjects: _loadingProjects,
        loadingProjectsSummary: _loadingProjectsSummary,
        loadingArtStyles: _loadingArtStyles,
        creatingProject: _creatingProject,
        loadingAgentMemory: _loadingAgentMemory,
        projects: _projects,
        projectsSummaryLine: _projectsSummaryLine,
        artStylesLine: _artStylesLine,
        agentMemoryBody: _agentMemoryBody,
        onLoadProjects: _loadProjects,
        onLoadProjectsSummary: _loadProjectsSummary,
        onLoadArtStyles: _loadArtStyles,
        onCreateEmptyProject: _createEmptyProject,
        onOpenProjectDetail: _openProjectDetail,
        onProbeAgentMemory: _probeAgentMemory,
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.scriptWorkspace)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.script,
        sectionTitle: 'Script workspace',
        sectionDescription: '专注剧本 Agent 工作流：上下文探测、子 Agent 编排与正文/计划回写。',
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.productionWorkspace)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.production,
        sectionTitle: 'Production workspace',
        sectionDescription: '专注 production Agent 工作流：flow 数据读取、资产/分镜工具执行与安全回写。',
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.workspaceActivity)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.activity,
        sectionTitle: 'Workspace activity',
        sectionDescription: '集中查看最近 WS 事件、工具回执与回写状态，作为统一执行日志面板。',
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.tasks)
      TaskCenterSection(
        loadingTaskProjects: _loadingTaskProjects,
        loadingTaskCategories: _loadingTaskCategories,
        loadingTaskApi: _loadingTaskApi,
        loadingTaskDetailsLegacy: _loadingTaskDetailsLegacy,
        loadingTaskDetailsUuid: _loadingTaskDetailsUuid,
        taskDetailJobIdController: _taskDetailJobIdCtrl,
        taskProjects: _taskProjects,
        taskCategoriesLine: _taskCategoriesLine,
        taskApiSummaryLine: _taskApiSummaryLine,
        taskDetailLegacyLine: _taskDetailLegacyLine,
        taskDetailUuidLine: _taskDetailUuidLine,
        taskApiJobs: _taskApiJobs,
        onTaskDetailJobIdChanged: (_) => setState(() {}),
        onLoadTaskProjects: _loadTaskProjects,
        onLoadTaskCategories: _loadTaskCategories,
        onLoadTaskApi: _loadTaskApi,
        onProbeTaskDetailLegacy: _probeTaskDetailLegacy,
        onProbeTaskDetailUuid: _probeTaskDetailUuid,
        onSelectTaskJob: (job) =>
            setState(() => _taskDetailJobIdCtrl.text = job.id),
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.jobs)
      JobsSection(
        loadingJobs: _loadingJobs,
        loadingJobKinds: _loadingJobKinds,
        loadingJobKindSummary: _loadingJobKindSummary,
        loadingJobStatusSummary: _loadingJobStatusSummary,
        creatingJob: _creatingJob,
        loadingJobById: _loadingJobById,
        jobIdController: _jobIdCtrl,
        jobs: _jobs,
        jobByIdLine: _jobByIdLine,
        jobKindsLine: _jobKindsLine,
        jobKindSummaryLine: _jobKindSummaryLine,
        jobStatusSummaryLine: _jobStatusSummaryLine,
        cancellingJobId: _cancellingJobId,
        retryingJobId: _retryingJobId,
        onJobIdChanged: (_) => setState(() {}),
        onLoadJobs: _loadJobs,
        onLoadJobsKindFlutterProbe: _loadJobsKindFlutterProbe,
        onLoadJobsStatusFailed: _loadJobsStatusFailed,
        onLoadJobsKindProbeStatusQueued: _loadJobsKindProbeStatusQueued,
        onLoadJobKinds: _loadJobKinds,
        onLoadJobKindSummary: _loadJobKindSummary,
        onLoadJobStatusSummary: _loadJobStatusSummary,
        onCreateProbeJob: _createProbeJob,
        onFetchJobById: _fetchJobById,
        onSelectJob: (job) => setState(() => _jobIdCtrl.text = job.id),
        onRetryFailedJob: _retryFailedJob,
        onCancelQueuedJob: _cancelQueuedJob,
      ),
    if (_productWorkspacePane == _ProductWorkspacePane.quality)
      QualityReviewsSection(
        loadingQualityReviews: _loadingQualityReviews,
        loadingQualityBadCases: _loadingQualityBadCases,
        loadingQualityStats: _loadingQualityStats,
        loadingQualityStagePassRate: _loadingQualityStagePassRate,
        creatingQualityReview: _creatingQualityReview,
        loadingQualityReviewById: _loadingQualityReviewById,
        qualityReviewIdController: _qualityReviewIdCtrl,
        qualityReviews: _qualityReviews,
        qualityStatsLine: _qualityStatsLine,
        qualityStagePassRateLine: _qualityStagePassRateLine,
        qualityReviewByIdLine: _qualityReviewByIdLine,
        onQualityReviewIdChanged: (_) => setState(() {}),
        onLoadQualityReviews: _loadQualityReviews,
        onLoadQualityBadCases: () => _loadQualityReviews(onlyBadCases: true),
        onLoadQualityStats: _loadQualityStats,
        onLoadQualityStagePassRate: _loadQualityStagePassRate,
        onCreateQualityReviewProbe: _createQualityReviewProbe,
        onFetchQualityReviewById: _fetchQualityReviewById,
        onSelectQualityReview: (review) =>
            setState(() => _qualityReviewIdCtrl.text = review.id),
      ),
  ];

  List<Widget> _buildDebugSections() => [
    HarnessSection(
      loadingHarnessTools: _loadingHarnessTools,
      loadingSkillsSummary: _loadingSkillsSummary,
      loadingSkillList: _loadingSkillList,
      loadingSkillPreview: _loadingSkillPreview,
      loadingSkillPut: _loadingSkillPut,
      loadingSkillPost: _loadingSkillPost,
      loadingSkillDelete: _loadingSkillDelete,
      wsProbesBusy: _wsProbesBusy,
      loadingWs: _loadingWs,
      loadingWsHarness: _loadingWsHarness,
      loadingWsIsolatedEcho: _loadingWsIsolatedEcho,
      loadingWsWasmProbe: _loadingWsWasmProbe,
      loadingWsSkillsRead: _loadingWsSkillsRead,
      loadingWsHarnessAgent: _loadingWsHarnessAgent,
      harnessToolsLine: _harnessToolsLine,
      skillsAggregateLine: _skillsAggregateLine,
      skillsListSummary: _skillsListSummary,
      skillMutationLine: _skillMutationLine,
      skillPathController: _skillPathCtrl,
      skillContentController: _skillContentCtrl,
      wsLog: _wsLog,
      onLoadHarnessTools: _loadHarnessTools,
      onLoadSkillsAggregate: _loadSkillsAggregate,
      onLoadSkillList: _loadSkillList,
      onPreviewSkillFile: _previewSkillFile,
      onPutSkillProbe: _putSkillProbe,
      onPostSkillProbe: _postSkillProbe,
      onDeleteSkillProbe: _deleteSkillProbe,
      onTestWebSocket: _testWebSocket,
      onTestHarnessToolWebSocket: _testHarnessToolWebSocket,
      onTestHarnessIsolatedEchoWebSocket: _testHarnessIsolatedEchoWebSocket,
      onTestHarnessWasmProbeWebSocket: _testHarnessWasmProbeWebSocket,
      onTestHarnessSkillsReadWebSocket: _testHarnessSkillsReadWebSocket,
      onTestHarnessAgentRunWebSocket: _testHarnessAgentRunWebSocket,
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
