// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageBuildProductSections on _HomePageState {
  Future<void> _openComplianceProductTarget(
    ContentComplianceReportItemV1 item,
  ) async {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    switch (item.targetType) {
      case 'user':
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.account,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('已切到账户面板；用户治理仍建议在内部管理台处理。')),
        );
        return;
      default:
        break;
    }

    final token = _session?.accessToken;
    final projectId =
        item.projectId ?? (item.targetType == 'project' ? item.targetId : null);
    if (token == null || token.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('当前未登录，无法打开目标上下文。')));
      return;
    }
    if (projectId == null || projectId.isEmpty) {
      if ((item.workspaceId ?? '').isNotEmpty) {
        _shellNavigationController.selectProductWorkspacePane(
          ProductWorkspacePane.teamWorkspaces,
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '该举报已切到团队工作区上下文；workspace ${item.workspaceName ?? item.workspaceId!}',
            ),
          ),
        );
        return;
      }
      messenger.showSnackBar(const SnackBar(content: Text('该举报没有可打开的项目上下文。')));
      return;
    }

    try {
      final detail = await fetchProjectByProjectId(token, projectId);
      if (!mounted) {
        return;
      }
      final row = detail.project;
      setState(() {
        _productScopedProjectNumericId = row.numericId;
      });
      _workspaceInputController.applyProjectScope(
        row.numericId,
        projectUuid: row.id,
        workspaceId: row.workspaceId,
      );
      _shellNavigationController.selectProductWorkspacePane(
        ProductWorkspacePane.projects,
      );
      await _openProjectDetail(row);
    } on RustApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('打开目标失败：${error.message}')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('打开目标失败：$error')));
    }
  }

  Widget _buildFeatureGatedPane({
    required bool enabled,
    required String title,
    required String reason,
    required Widget child,
  }) {
    if (enabled) {
      return child;
    }
    return _PlatformPaneDisabledNotice(title: title, reason: reason);
  }

  Widget _buildProductPaneSelector(BuildContext context) {
    return _ProductPaneSelector(
      config: _platformConfig,
      unreadNotifications: _notificationsController.unreadCount,
      selectedPane: _shellNavigationController.productWorkspacePane,
      onSelectPane: (pane) {
        _shellNavigationController.selectProductWorkspacePane(pane);
      },
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
      projectIdController: _workspaceInputController.projectIdController,
      scriptIdController: _workspaceInputController.scriptIdController,
      projectUuidController: _workspaceInputController.projectUuidController,
      scriptUuidController: _workspaceInputController.scriptUuidController,
      workspaceUuidController:
          _workspaceInputController.workspaceUuidController,
      scriptPromptController: _workspaceInputController.scriptPromptController,
      scriptDomainArgsController:
          _workspaceInputController.scriptDomainArgsController,
      productionPromptController:
          _workspaceInputController.productionPromptController,
      flowKeyController: _workspaceInputController.productionFlowKeyController,
      productionDomainToolController:
          _workspaceInputController.productionDomainToolController,
      productionDomainArgsController:
          _workspaceInputController.productionDomainArgsController,
      productionSubAgentArgsController:
          _workspaceInputController.productionSubAgentArgsController,
      loadingScriptWorkspaceRun:
          _workspaceOperationController.loadingScriptWorkspaceRun,
      loadingProductionWorkspaceRun:
          _workspaceOperationController.loadingProductionWorkspaceRun,
      loadingScriptDomainProbe:
          _workspaceOperationController.loadingScriptDomainProbe,
      loadingProductionFlowProbe:
          _workspaceOperationController.loadingProductionFlowProbe,
      loadingScriptSubAgentRun:
          _workspaceOperationController.loadingScriptSubAgentRun,
      loadingProductionSubAgentRun:
          _workspaceOperationController.loadingProductionSubAgentRun,
      loadingScriptResultWriteback:
          _workspaceOperationController.loadingScriptResultWriteback,
      loadingScriptPlanResultWriteback:
          _workspaceOperationController.loadingScriptPlanResultWriteback,
      loadingProductionResultWriteback:
          _workspaceOperationController.loadingProductionResultWriteback,
      wsLog: _wsLog,
      workspaceAssistantText: _workspaceOutputController.assistantText,
      workspaceScriptWritebackCandidate:
          _workspaceOutputController.scriptWritebackCandidate,
      workspaceScriptPlanWritebackCandidate:
          _workspaceOutputController.scriptPlanWritebackCandidate,
      workspaceScriptPlanRowId: _workspaceOutputController.scriptPlanRowId,
      workspaceScriptWritebackSource:
          _workspaceOutputController.scriptWritebackSource,
      workspaceLastToolResultLine:
          _workspaceOutputController.lastToolResultLine,
      workspaceLastToolName: _workspaceOutputController.lastToolName,
      workspaceLastToolResultData:
          _workspaceOutputController.lastToolResultData,
      workspaceLastToolArguments: _workspaceOutputController.lastToolArguments,
      workspaceSuggestedFlowKey: _workspaceOutputController.suggestedFlowKey,
      workspaceWritebackLine: _workspaceOutputController.writebackLine,
      onRunScriptWorkspace: _workspaceRunController.runScriptWorkspaceAgent,
      onRunProductionWorkspace:
          _workspaceRunController.runProductionWorkspaceAgent,
      onProbeScriptDomainTool: _workspaceRunController.probeScriptDomainTool,
      onProbeProductionDomainTool:
          _workspaceRunController.probeProductionDomainTool,
      scriptSubAgentToolController:
          _workspaceInputController.scriptSubAgentToolController,
      productionSubAgentToolController:
          _workspaceInputController.productionSubAgentToolController,
      onRunScriptSubAgentTool: _workspaceRunController.runScriptSubAgentTool,
      onRunProductionSubAgentTool:
          _workspaceRunController.runProductionSubAgentTool,
      onWriteBackScriptResult:
          _workspaceWritebackController.writeBackScriptWorkspaceResult,
      onWriteBackScriptPlanResult:
          _workspaceWritebackController.writeBackScriptPlanWorkspaceResult,
      onWriteBackScriptPlanViaUpdateData:
          _workspaceWritebackController.writeBackScriptPlanViaUpdateData,
      onWriteBackProductionFlowResult:
          _workspaceWritebackController.writeBackProductionFlowResult,
      onApplySuggestedFlowKey: () {
        _workspaceInputController.applySuggestedProductionFlowKey(
          _workspaceOutputController.suggestedFlowKey,
        );
      },
    );
  }

  List<Widget> _buildProductSections(BuildContext context) => [
    _buildProductPaneSelector(context),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.helpHub)
      _buildFeatureGatedPane(
        enabled: _platformConfig.helpHubEnabled,
        title: '帮助',
        reason: '当前平台配置已关闭帮助 Hub，可在「平台配置」中重新开启。',
        child: _HelpHubSection(accessToken: _session?.accessToken),
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.shortVideoSpace)
      ShortVideoSpaceSection(
        accessToken: _session?.accessToken,
        onOpenProjects: () {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.projects,
          );
        },
        onSyncProjectContext: (projectNumericId) {
          setState(() {
            _productScopedProjectNumericId = projectNumericId;
          });
          if (projectNumericId == null) {
            _workspaceInputController.projectIdController.clear();
            _workspaceInputController.projectUuidController.clear();
            _workspaceInputController.workspaceUuidController.clear();
            _workspaceInputController.clearScriptScope();
            return;
          }
          _workspaceInputController.applyProjectScope(projectNumericId);
          _workspaceInputController.clearScriptScope();
        },
        onOpenScriptWorkspace: () {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.scriptWorkspace,
          );
        },
        onOpenProductionWorkspace: () {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.productionWorkspace,
          );
        },
        onOpenTasks: () {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.tasks,
          );
        },
        onOpenQuality: () {
          _selectProductPaneWithGate(
            ProductWorkspacePane.quality,
            disabledReason: '当前平台配置已关闭质量主面板，可在「平台配置」中重新开启。',
          );
        },
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.projects)
      ProjectsSection(
        accessToken: _session?.accessToken,
        controller: _projectsController,
        currentWorkspaceName: _sessionMe?.currentWorkspace?.name,
        currentWorkspaceType: _sessionMe?.currentWorkspace?.workspaceType,
        onOpenProjectDetail: _openProjectDetail,
        onOpenTeamWorkspaces: () {
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.teamWorkspaces,
          );
        },
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.account)
      AccountSection(
        controller: _accountController,
        onAccountDeleted: _handleAccountDeleted,
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.apiKeys)
      ApiKeysSection(controller: _apiKeysController),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.notifications)
      NotificationsSection(
        controller: _notificationsController,
        onOpenNotification: _openNotificationLink,
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.contentCompliance)
      ContentComplianceSection(
        controller: _contentComplianceController,
        onOpenTarget: _openComplianceProductTarget,
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.platformStatus)
      _buildFeatureGatedPane(
        enabled: _platformConfig.platformStatusEnabled,
        title: '平台状态',
        reason: '当前平台配置已关闭平台状态入口，可在「平台配置」中重新开启。',
        child: PlatformStatusSection(
          onOverallHealthChanged: (healthy, degradedEndpoints) {
            _notificationsController.addPlatformStatusTransitionNotification(
              healthy: healthy,
              degradedEndpoints: degradedEndpoints,
            );
          },
        ),
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.teamWorkspaces)
      TeamWorkspacesSection(
        accessToken: _session?.accessToken,
        onWorkspaceContextChanged: _handleWorkspaceContextChanged,
        currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.scriptWorkspace)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.script,
        sectionTitle: '剧本工作区',
        sectionDescription: '专注剧本 Agent 工作流：上下文探测、子 Agent 编排与正文/计划回写。',
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.productionWorkspace)
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.production,
        sectionTitle: '制作工作区',
        sectionDescription: '专注 production Agent 工作流：flow 数据读取、资产/分镜工具执行与安全回写。',
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.workspaceActivity)
      _buildFeatureGatedPane(
        enabled: _platformConfig.workspaceActivityEnabled,
        title: '工作区动态',
        reason: '当前平台配置已关闭执行动态面板，可在「平台配置」中重新开启。',
        child: _buildAgentWorkspacePane(
          initialPane: AgentWorkspacePane.activity,
          sectionTitle: '执行动态',
          sectionDescription: '集中查看最近 WS 事件、工具回执与回写状态，作为统一执行日志面板。',
        ),
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.benchmark)
      _buildFeatureGatedPane(
        enabled: _platformConfig.benchmarkPaneEnabled,
        title: '评测基线',
        reason: '当前平台配置已关闭评测基线入口，可在「平台配置」中重新开启。',
        child: BenchmarkSection(accessToken: _session?.accessToken),
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.tasks)
      TaskCenterSection(
        accessToken: _session?.accessToken,
        initialProjectNumericId: _productScopedProjectNumericId,
        onNavigateExportJobDeepLink: (TaskCenterExportJobDeepLink link) {
          setState(() {
            _productScopedProjectNumericId = link.projectNumericId;
          });
          _workspaceInputController.applyProjectScope(
            link.projectNumericId,
            scriptNumericId: link.scriptNumericId,
          );
          _shellNavigationController.selectProductWorkspacePane(
            link.openProductionWorkspace
                ? ProductWorkspacePane.productionWorkspace
                : ProductWorkspacePane.scriptWorkspace,
          );
        },
        onNavigateDomainDeepLink: (TaskCenterDomainDeepLink link) {
          setState(() {
            _productScopedProjectNumericId = link.projectNumericId;
          });
          _workspaceInputController.applyProjectScope(
            link.projectNumericId,
            scriptNumericId: link.scriptNumericId,
          );
          switch (link.target) {
            case TaskCenterDomainDeepLinkTarget.publish:
            case TaskCenterDomainDeepLinkTarget.project:
              _shellNavigationController.selectProductWorkspacePane(
                ProductWorkspacePane.shortVideoSpace,
              );
              break;
            case TaskCenterDomainDeepLinkTarget.script:
              _shellNavigationController.selectProductWorkspacePane(
                ProductWorkspacePane.scriptWorkspace,
              );
              break;
            case TaskCenterDomainDeepLinkTarget.storyboard:
              _shellNavigationController.selectProductWorkspacePane(
                ProductWorkspacePane.productionWorkspace,
              );
              break;
          }
        },
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
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.jobs)
      _buildFeatureGatedPane(
        enabled: _platformConfig.jobsPaneEnabled,
        title: '任务作业',
        reason: '当前平台配置已关闭 jobs 面板，可在「平台配置」中重新开启。',
        child: JobsSection(controller: _jobsController),
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.quality)
      _buildFeatureGatedPane(
        enabled: _platformConfig.qualityDashboardEnabled,
        title: '质量评审',
        reason: '当前平台配置已关闭质量主面板，可在「平台配置」中重新开启。',
        child: QualityReviewsSection(
          accessToken: _session?.accessToken,
          controller: _qualityReviewsController,
          initialProjectNumericId: _productScopedProjectNumericId,
          platformConfig: _platformConfig,
        ),
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.platformConfig)
      _PlatformConfigSection(
        accessToken: _session?.accessToken,
        currentWorkspaceId: _sessionMe?.currentWorkspace?.id,
        initialConfig: _platformConfig,
        onConfigSaved: (config) {
          if (!mounted) {
            return;
          }
          setState(() {
            _applyPlatformConfig(config);
          });
        },
      ),
  ];
}

class _ProductPaneSelector extends StatefulWidget {
  const _ProductPaneSelector({
    required this.config,
    required this.unreadNotifications,
    required this.selectedPane,
    required this.onSelectPane,
  });

  final PlatformConfigToggleSetV1 config;
  final int unreadNotifications;
  final ProductWorkspacePane selectedPane;
  final ValueChanged<ProductWorkspacePane> onSelectPane;

  @override
  State<_ProductPaneSelector> createState() => _ProductPaneSelectorState();
}

class _ProductPaneSelectorState extends State<_ProductPaneSelector> {
  bool _isPaneEnabled(ProductWorkspacePane pane) {
    switch (pane) {
      case ProductWorkspacePane.helpHub:
        return widget.config.helpHubEnabled;
      case ProductWorkspacePane.platformStatus:
        return widget.config.platformStatusEnabled;
      case ProductWorkspacePane.workspaceActivity:
        return widget.config.workspaceActivityEnabled;
      case ProductWorkspacePane.benchmark:
        return widget.config.benchmarkPaneEnabled;
      case ProductWorkspacePane.jobs:
        return widget.config.jobsPaneEnabled;
      case ProductWorkspacePane.quality:
        return widget.config.qualityDashboardEnabled;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paneEntries = <(ProductWorkspacePane, String, int?)>[
      (ProductWorkspacePane.shortVideoSpace, '短视频 Space', null),
      (ProductWorkspacePane.projects, '项目', null),
      (ProductWorkspacePane.account, '账户', null),
      (ProductWorkspacePane.apiKeys, 'API 密钥', null),
      (ProductWorkspacePane.notifications, '通知中心', widget.unreadNotifications),
      (ProductWorkspacePane.contentCompliance, '内容合规', null),
      (ProductWorkspacePane.platformStatus, '平台状态', null),
      (ProductWorkspacePane.teamWorkspaces, '团队工作区', null),
      (ProductWorkspacePane.scriptWorkspace, '脚本工作区', null),
      (ProductWorkspacePane.productionWorkspace, '制作工作区', null),
      (ProductWorkspacePane.workspaceActivity, '工作区动态', null),
      (ProductWorkspacePane.benchmark, '评测基线', null),
      (ProductWorkspacePane.tasks, '任务中心', null),
      (ProductWorkspacePane.jobs, '任务作业', null),
      (ProductWorkspacePane.quality, '质量评审', null),
      (ProductWorkspacePane.platformConfig, '平台配置', null),
      (ProductWorkspacePane.helpHub, '帮助', null),
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
                  final enabled = _isPaneEnabled(pane);
                  final unread = entry.$3;
                  return ChoiceChip(
                    label: Text(
                      unread != null && unread > 0
                          ? '${entry.$2} ($unread)'
                          : entry.$2,
                    ),
                    selected: widget.selectedPane == pane,
                    onSelected: enabled
                        ? (selected) {
                            if (!selected) {
                              return;
                            }
                            widget.onSelectPane(pane);
                          }
                        : null,
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          PlatformShortDramaPipelineStrip(
            onSelectPane: widget.onSelectPane,
            jobsPaneEnabled: widget.config.jobsPaneEnabled,
            qualityPaneEnabled: widget.config.qualityDashboardEnabled,
          ),
        ],
      ),
    );
  }
}

class _PlatformPaneDisabledNotice extends StatelessWidget {
  const _PlatformPaneDisabledNotice({
    required this.title,
    required this.reason,
  });

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: outline.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(reason, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _PlatformConfigSection extends StatefulWidget {
  const _PlatformConfigSection({
    required this.accessToken,
    required this.currentWorkspaceId,
    required this.initialConfig,
    required this.onConfigSaved,
  });

  final String? accessToken;
  final String? currentWorkspaceId;
  final PlatformConfigToggleSetV1 initialConfig;
  final ValueChanged<PlatformConfigToggleSetV1> onConfigSaved;

  @override
  State<_PlatformConfigSection> createState() => _PlatformConfigSectionState();
}

class _PlatformConfigSectionState extends State<_PlatformConfigSection> {
  bool _loading = false;
  bool _savingUser = false;
  bool _savingWorkspace = false;
  String? _error;
  int _loadRequestEpoch = 0;
  PlatformConfigResponseV1? _response;
  PlatformConfigToggleSetV1? _userDraft;
  PlatformConfigToggleSetV1? _workspaceDraft;

  @override
  void initState() {
    super.initState();
    _userDraft = widget.initialConfig;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _PlatformConfigSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contextChanged =
        oldWidget.accessToken != widget.accessToken ||
        oldWidget.currentWorkspaceId != widget.currentWorkspaceId;
    if (oldWidget.initialConfig != widget.initialConfig &&
        !_savingUser &&
        !_savingWorkspace &&
        _response == null) {
      _userDraft = widget.initialConfig;
    }
    if (contextChanged) {
      _response = null;
      _error = null;
      _savingUser = false;
      _savingWorkspace = false;
      _userDraft = widget.initialConfig;
      _workspaceDraft = null;
      unawaited(_load());
    }
  }

  bool _isCurrentLoadRequest(
    int requestEpoch,
    String token,
    String? workspaceId,
  ) {
    return mounted &&
        requestEpoch == _loadRequestEpoch &&
        widget.accessToken == token &&
        widget.currentWorkspaceId == workspaceId;
  }

  bool _isCurrentMutationContext(String token, String? workspaceId) {
    return mounted &&
        widget.accessToken == token &&
        widget.currentWorkspaceId == workspaceId;
  }

  PlatformConfigToggleSetV1? _workspaceDraftForResponse(
    PlatformConfigResponseV1 response,
  ) {
    return response.workspaceOverride ??
        (response.currentWorkspace?.canManageOverride == true
            ? PlatformConfigToggleSetV1.defaults
            : null);
  }

  void _applyResponse(PlatformConfigResponseV1 response) {
    _response = response;
    _userDraft = response.userOverride;
    _workspaceDraft = _workspaceDraftForResponse(response);
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = '请先登录';
        _response = null;
        _userDraft = null;
        _workspaceDraft = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final requestEpoch = ++_loadRequestEpoch;
    try {
      final res = await fetchPlatformConfigV1(token);
      if (!_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
    } on RustApiException catch (e) {
      if (!_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
      });
    } catch (e) {
      if (!_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveUser() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final draft = _userDraft;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null || token.isEmpty || draft == null) {
      return;
    }
    setState(() {
      _savingUser = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(token, draft, scope: 'user');
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      messenger.showSnackBar(const SnackBar(content: Text('已保存用户平台配置')));
    } on RustApiException catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
      });
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingUser = false;
        });
      }
    }
  }

  Future<void> _resetUser() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _savingUser = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(
        token,
        null,
        scope: 'user',
        reset: true,
      );
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      messenger.showSnackBar(const SnackBar(content: Text('已重置用户覆盖层')));
    } on RustApiException catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
      });
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingUser = false;
        });
      }
    }
  }

  Future<void> _saveWorkspace() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final draft = _workspaceDraft;
    final workspace = _response?.currentWorkspace;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null ||
        token.isEmpty ||
        draft == null ||
        workspace == null ||
        !workspace.canManageOverride) {
      return;
    }
    setState(() {
      _savingWorkspace = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(token, draft, scope: 'workspace');
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      messenger.showSnackBar(
        const SnackBar(content: Text('已保存当前 workspace 平台配置')),
      );
    } on RustApiException catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
      });
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkspace = false;
        });
      }
    }
  }

  Future<void> _resetWorkspace() async {
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    final workspace = _response?.currentWorkspace;
    final messenger = ScaffoldMessenger.of(context);
    if (token == null ||
        token.isEmpty ||
        workspace == null ||
        !workspace.canManageOverride) {
      return;
    }
    setState(() {
      _savingWorkspace = true;
      _error = null;
    });
    try {
      final res = await postPlatformConfigV1(
        token,
        null,
        scope: 'workspace',
        reset: true,
      );
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _applyResponse(res);
      });
      widget.onConfigSaved(res.effective);
      messenger.showSnackBar(
        const SnackBar(content: Text('已重置 workspace 覆盖层')),
      );
    } on RustApiException catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
      });
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingWorkspace = false;
        });
      }
    }
  }

  Future<void> _copyConfig() async {
    final response = _response;
    if (response == null) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'scope': response.scope,
          'schemaVersion': response.schemaVersion,
          'effective': response.effective.toJson(),
          'planTier': response.planTier,
          'planOverride': response.planOverride?.toJson(),
          'hasPlanOverride': response.hasPlanOverride,
          'userOverride': response.userOverride.toJson(),
          'hasUserOverride': response.hasUserOverride,
          'workspaceOverride': response.workspaceOverride?.toJson(),
          'hasWorkspaceOverride': response.hasWorkspaceOverride,
          'currentWorkspace': response.currentWorkspace == null
              ? null
              : <String, dynamic>{
                  'id': response.currentWorkspace!.id,
                  'name': response.currentWorkspace!.name,
                  'workspaceType': response.currentWorkspace!.workspaceType,
                  'role': response.currentWorkspace!.role,
                  'canManageOverride':
                      response.currentWorkspace!.canManageOverride,
                },
        }),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制平台配置 JSON')));
  }

  void _patchUserDraft(PlatformConfigToggleSetV1 next) {
    setState(() {
      _userDraft = next;
    });
  }

  void _patchWorkspaceDraft(PlatformConfigToggleSetV1 next) {
    setState(() {
      _workspaceDraft = next;
    });
  }

  Widget _buildToggleEditor({
    required PlatformConfigToggleSetV1 draft,
    required ValueChanged<PlatformConfigToggleSetV1>? onChanged,
  }) {
    return Column(
      children: [
        SwitchListTile(
          value: draft.helpHubEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(helpHubEnabled: v)),
          title: const Text('帮助 Hub'),
          subtitle: const Text('控制帮助 / 文档产品入口的可见性'),
        ),
        SwitchListTile(
          value: draft.qualityDashboardEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(qualityDashboardEnabled: v)),
          title: const Text('质量主面板'),
          subtitle: const Text('控制质量运营看板与主面板摘要区'),
        ),
        SwitchListTile(
          value: draft.qualityRefreshControlsEnabled,
          onChanged: onChanged == null
              ? null
              : (v) =>
                    onChanged(draft.copyWith(qualityRefreshControlsEnabled: v)),
          title: const Text('质量刷新控制'),
          subtitle: const Text('控制物化读模型 refresh 相关按钮与入口'),
        ),
        SwitchListTile(
          value: draft.platformStatusEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(platformStatusEnabled: v)),
          title: const Text('平台状态'),
          subtitle: const Text('控制平台状态（Health/Ready/SLI/Metrics）入口'),
        ),
        SwitchListTile(
          value: draft.workspaceActivityEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(workspaceActivityEnabled: v)),
          title: const Text('工作区动态'),
          subtitle: const Text('控制 Agent Workspace Activity 导航入口'),
        ),
        SwitchListTile(
          value: draft.benchmarkPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(benchmarkPaneEnabled: v)),
          title: const Text('评测基线'),
          subtitle: const Text('控制 benchmark / 评测相关产品入口'),
        ),
        SwitchListTile(
          value: draft.jobsPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(jobsPaneEnabled: v)),
          title: const Text('任务作业'),
          subtitle: const Text('控制 jobs 面板导航入口'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final userDraft = _userDraft;
    final workspaceDraft = _workspaceDraft;
    final workspace = _response?.currentWorkspace;
    final userDraftDirty =
        userDraft != null &&
        _response != null &&
        userDraft != _response!.userOverride;
    final workspaceBaseline =
        _response?.workspaceOverride ??
        ((_response?.currentWorkspace?.canManageOverride ?? false)
            ? PlatformConfigToggleSetV1.defaults
            : null);
    final workspaceDraftDirty =
        workspaceDraft != null &&
        workspaceBaseline != null &&
        workspaceDraft != workspaceBaseline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '平台配置',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: '本机客户端偏好（与各主面板标题旁 ⋯ 相同）',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '管理产品壳层的功能开关与运营面可见性。effective 现按 defaults <- plan override <- current workspace override <- user override 合成。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text('本机客户端偏好', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '下列项仅影响当前设备上的本应用本地存储，与服务器侧平台配置无关。'
          '需要恢复删除版本、归档、导出等二次确认时，请点上方标题栏 ⋯ 菜单。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _loading ? null : _load,
              child: Text(_loading ? '加载中…' : '刷新配置'),
            ),
            FilledButton(
              onPressed: _savingUser || !userDraftDirty ? null : _saveUser,
              child: Text(_savingUser ? '保存中…' : '保存用户配置'),
            ),
            OutlinedButton(
              onPressed: _savingUser || !(_response?.hasUserOverride ?? false)
                  ? null
                  : _resetUser,
              child: const Text('重置用户覆盖'),
            ),
            FilledButton.tonal(
              onPressed:
                  _savingWorkspace ||
                      !workspaceDraftDirty ||
                      workspace == null ||
                      !workspace.canManageOverride
                  ? null
                  : _saveWorkspace,
              child: Text(_savingWorkspace ? '保存中…' : '保存 workspace 配置'),
            ),
            OutlinedButton(
              onPressed:
                  _savingWorkspace ||
                      workspace == null ||
                      !workspace.canManageOverride ||
                      !(_response?.hasWorkspaceOverride ?? false)
                  ? null
                  : _resetWorkspace,
              child: const Text('重置 workspace 覆盖'),
            ),
            OutlinedButton(
              onPressed: _response == null ? null : _copyConfig,
              child: const Text('复制 JSON'),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        if (_response != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'scope=${_response!.scope} · schema=v${_response!.schemaVersion}',
          ),
          const SizedBox(height: 4),
          SelectableText(
            'plan_tier=${_response!.planTier} · has_plan_override=${_response!.hasPlanOverride}',
          ),
          if (workspace != null) ...[
            const SizedBox(height: 4),
            SelectableText(
              'current_workspace=${workspace.name} (${workspace.workspaceType}) · role=${workspace.role} · can_manage_override=${workspace.canManageOverride}',
            ),
          ],
        ],
        if (_response != null) ...[
          const SizedBox(height: 12),
          Text('Plan Override', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '套餐层是只读覆盖层，来自服务端环境配置；适合先做分层收口，再由 workspace / user 继续细调。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'env: TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            _response!.hasPlanOverride
                ? '当前状态：plan override 已生效'
                : '当前状态：未配置 plan override，直接继承 defaults',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_response!.planOverride != null) ...[
            const SizedBox(height: 12),
            _buildToggleEditor(
              draft: _response!.planOverride!,
              onChanged: null,
            ),
          ],
        ],
        if (workspace != null && workspaceDraft != null) ...[
          const SizedBox(height: 12),
          Text(
            'Workspace Override',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            workspace.canManageOverride
                ? '当前 enterprise workspace 的公共覆盖层，会先于个人配置参与 effective 合成。'
                : '当前 workspace 仅展示公共覆盖层；只有 enterprise owner/admin 可以修改。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            (_response?.hasWorkspaceOverride ?? false)
                ? '当前状态：已写入 workspace override'
                : '当前状态：继承 defaults，再叠个人覆盖',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildToggleEditor(
            draft: workspaceDraft,
            onChanged: workspace.canManageOverride
                ? _patchWorkspaceDraft
                : null,
          ),
        ],
        if (workspace != null && workspaceDraft == null) ...[
          const SizedBox(height: 12),
          Text(
            'Workspace Override',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            workspace.workspaceType == 'enterprise'
                ? '当前 workspace 没有可编辑的公共覆盖层。请先切到 enterprise owner/admin 身份，或等待公共覆盖配置下发。'
                : '当前 workspace 为 personal。workspace 级公共覆盖层仅对 enterprise workspace 开放。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userDraft != null) ...[
          const SizedBox(height: 12),
          Text('User Override', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '个人覆盖层始终最后生效，适合放自己的运营视图与工具偏好。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            (_response?.hasUserOverride ?? false)
                ? '当前状态：已写入 user override'
                : '当前状态：直接继承 workspace/defaults',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildToggleEditor(draft: userDraft, onChanged: _patchUserDraft),
        ],
      ],
    );
  }
}

class _HelpHubSection extends StatefulWidget {
  const _HelpHubSection({required this.accessToken});

  final String? accessToken;

  @override
  State<_HelpHubSection> createState() => _HelpHubSectionState();
}

class _WebhookActivityEntry {
  const _WebhookActivityEntry({
    required this.at,
    required this.action,
    required this.webhookId,
    required this.summary,
  });

  final DateTime at;
  final String action;
  final String webhookId;
  final String summary;
}

class _HelpHubSectionState extends State<_HelpHubSection> {
  bool _loading = false;
  String? _error;
  HelpHubLinksResponseV1? _resp;
  HelpHubConfigResponseV1? _helpHubConfig;
  bool _savingHelpHubLinks = false;
  bool _loadingWebhooks = false;
  String? _webhooksError;
  OutboundWebhookListResponseV1? _webhooks;
  OutboundWebhookCreatedResponseV1? _latestCreatedWebhook;
  final _webhookUrlController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  final _webhookSearchController = TextEditingController();
  final _webhookTestEventTypeController = TextEditingController(
    text: 'test.ping',
  );
  final _webhookWorkspaceIdController = TextEditingController();
  /// Create form: selected platform event slugs (empty on server = all types).
  final Set<String> _createWebhookEventTypes =
      <String>{...kOutboundWebhookPlatformEventTypes};
  final _helpHubSearchController = TextEditingController();
  final _helpHubNewIdController = TextEditingController();
  final _helpHubNewTitleController = TextEditingController();
  final _helpHubNewUrlController = TextEditingController();
  String? _webhookBusyId;
  final Map<String, OutboundWebhookTestResponseV1> _webhookLastTestResultById =
      <String, OutboundWebhookTestResponseV1>{};
  final Map<String, OutboundWebhookDeliveryListResponseV1> _webhookDeliveries =
      <String, OutboundWebhookDeliveryListResponseV1>{};
  String? _loadingDeliveriesId;
  final List<_WebhookActivityEntry> _webhookActivity =
      <_WebhookActivityEntry>[];
  bool _loadingBillingEvents = false;
  bool _loadingMoreBillingEvents = false;
  bool _exportingAllBillingEvents = false;
  String? _billingEventsError;
  BillingWebhookEventsResponseV1? _billingEventsPage;
  final List<BillingWebhookEventItemV1> _billingEvents =
      <BillingWebhookEventItemV1>[];
  final _billingEventTypeController = TextEditingController();
  final _billingProviderEventIdController = TextEditingController();
  final _billingProviderEventIdPrefixController = TextEditingController();
  final _billingRawEventIdController = TextEditingController();
  final _billingRawEventIdPrefixController = TextEditingController();
  final _billingEventCreatedFromController = TextEditingController();
  final _billingEventCreatedToController = TextEditingController();
  final _billingCreatedFromController = TextEditingController();
  final _billingCreatedToController = TextEditingController();
  String _billingProvider = '';
  bool? _billingInformationalOnly;
  String _billingSort = 'id_desc';

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = '请先登录';
        _resp = null;
        _helpHubConfig = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await getSettingsHelpHubConfigV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _helpHubConfig = cfg;
        _resp = HelpHubLinksResponseV1(items: cfg.effectiveItems);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
        _resp = null;
        _helpHubConfig = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadWebhooks());
    unawaited(_loadBillingEvents());
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _webhookSecretController.dispose();
    _webhookSearchController.dispose();
    _webhookTestEventTypeController.dispose();
    _webhookWorkspaceIdController.dispose();
    _helpHubSearchController.dispose();
    _helpHubNewIdController.dispose();
    _helpHubNewTitleController.dispose();
    _helpHubNewUrlController.dispose();
    _billingEventTypeController.dispose();
    _billingProviderEventIdController.dispose();
    _billingProviderEventIdPrefixController.dispose();
    _billingRawEventIdController.dispose();
    _billingRawEventIdPrefixController.dispose();
    _billingEventCreatedFromController.dispose();
    _billingEventCreatedToController.dispose();
    _billingCreatedFromController.dispose();
    _billingCreatedToController.dispose();
    super.dispose();
  }

  Future<void> _openHelpHubManageDialog() async {
    final token = widget.accessToken;
    final cfg = _helpHubConfig;
    if (token == null || token.isEmpty) {
      return;
    }
    if (cfg == null) {
      await _load();
      if (!mounted) {
        return;
      }
    }

    final initial = _helpHubConfig;
    if (initial == null) {
      return;
    }

    var userItems = initial.userItems.toList(growable: true);
    var workspaceItems = initial.workspaceItems.toList(growable: true);
    var useWorkspaceTab = initial.canManageWorkspace;
    var errorText = '';

    _helpHubNewIdController.text = '';
    _helpHubNewTitleController.text = '';
    _helpHubNewUrlController.text = '';

    Future<void> saveScope({required bool workspace}) async {
      setState(() {
        _savingHelpHubLinks = true;
      });
      try {
        final resp = workspace
            ? await postSettingsHelpHubWorkspaceLinksV1(
                token,
                items: workspaceItems,
              )
            : await postSettingsHelpHubUserLinksV1(token, items: userItems);
        if (!mounted) {
          return;
        }
        setState(() {
          _helpHubConfig = resp;
          _resp = HelpHubLinksResponseV1(items: resp.effectiveItems);
        });
      } catch (e) {
        errorText = describeRustApiError(e);
      } finally {
        if (mounted) {
          setState(() {
            _savingHelpHubLinks = false;
          });
        }
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            final canManageWorkspace =
                _helpHubConfig?.canManageWorkspace ?? false;
            final activeIsWorkspace = canManageWorkspace && useWorkspaceTab;
            final activeItems = activeIsWorkspace ? workspaceItems : userItems;

            void addNew() {
              final id = _helpHubNewIdController.text.trim();
              final title = _helpHubNewTitleController.text.trim();
              final url = _helpHubNewUrlController.text.trim();
              if (id.isEmpty || title.isEmpty || url.isEmpty) {
                setInner(() {
                  errorText = 'id / title / url 不能为空';
                });
                return;
              }
              setInner(() {
                errorText = '';
                activeItems.add(
                  HelpHubLinkItemV1(id: id, title: title, url: url),
                );
                _helpHubNewIdController.text = '';
                _helpHubNewTitleController.text = '';
                _helpHubNewUrlController.text = '';
              });
            }

            return AlertDialog(
              title: const Text('管理帮助入口（个人 / 工作区）'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '生效顺序：个人覆盖 > 工作区覆盖 > 环境默认。'
                        '${canManageWorkspace ? '' : '（当前工作区不可配置，只有个人覆盖可用）'}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (canManageWorkspace)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('个人覆盖'),
                              selected: !activeIsWorkspace,
                              onSelected: (v) => setInner(() {
                                useWorkspaceTab = !v;
                                errorText = '';
                              }),
                            ),
                            FilterChip(
                              label: const Text('工作区覆盖'),
                              selected: activeIsWorkspace,
                              onSelected: (v) => setInner(() {
                                useWorkspaceTab = v;
                                errorText = '';
                              }),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _helpHubNewIdController,
                        decoration: const InputDecoration(
                          labelText: 'id（用于去重/覆盖）',
                          hintText: 'runbook-quality',
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpHubNewTitleController,
                        decoration: const InputDecoration(labelText: '标题'),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _helpHubNewUrlController,
                        decoration: const InputDecoration(
                          labelText: 'URL',
                          hintText: 'https://docs.example.com/runbook',
                        ),
                        enabled: !_savingHelpHubLinks,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _savingHelpHubLinks ? null : addNew,
                            child: const Text('添加'),
                          ),
                          if (errorText.isNotEmpty)
                            Text(
                              errorText,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (activeItems.isEmpty)
                        Text(
                          '当前范围没有自定义入口。',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ...activeItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.title} (${item.id})',
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(item.url),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: '上移',
                                  onPressed: (_savingHelpHubLinks || idx == 0)
                                      ? null
                                      : () => setInner(() {
                                          final tmp = activeItems[idx - 1];
                                          activeItems[idx - 1] =
                                              activeItems[idx];
                                          activeItems[idx] = tmp;
                                        }),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                IconButton(
                                  tooltip: '下移',
                                  onPressed:
                                      (_savingHelpHubLinks ||
                                          idx >= activeItems.length - 1)
                                      ? null
                                      : () => setInner(() {
                                          final tmp = activeItems[idx + 1];
                                          activeItems[idx + 1] =
                                              activeItems[idx];
                                          activeItems[idx] = tmp;
                                        }),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                                IconButton(
                                  tooltip: '删除',
                                  onPressed: _savingHelpHubLinks
                                      ? null
                                      : () => setInner(() {
                                          activeItems.removeAt(idx);
                                        }),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _savingHelpHubLinks
                      ? null
                      : () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
                FilledButton(
                  onPressed: _savingHelpHubLinks
                      ? null
                      : () async {
                          await saveScope(workspace: activeIsWorkspace);
                          if (!ctx.mounted) {
                            return;
                          }
                          if (errorText.isNotEmpty) {
                            setInner(() {});
                            return;
                          }
                          Navigator.pop(ctx);
                        },
                  child: Text(_savingHelpHubLinks ? '保存中…' : '保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadWebhooks() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _webhooksError = '请先登录';
        _webhooks = null;
      });
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
    });
    try {
      final resp = await getSettingsOutboundWebhookListV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooks = resp;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeRustApiError(e);
        _webhooks = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
        });
      }
    }
  }

  List<HelpHubLinkItemV1> _filteredHelpHubLinks() {
    final items = _resp?.items ?? const <HelpHubLinkItemV1>[];
    final needle = _helpHubSearchController.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return items;
    }
    return items
        .where((item) {
          final haystack = '${item.id} ${item.title} ${item.url}'.toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  String _helpHubCategoryFor(HelpHubLinkItemV1 item) {
    final key = '${item.id} ${item.title} ${item.url}'.toLowerCase();
    if (key.contains('runbook') || key.contains('guide')) {
      return 'Runbook';
    }
    if (key.contains('webhook') || key.contains('billing')) {
      return 'Billing/Webhook';
    }
    if (key.contains('workspace') || key.contains('team')) {
      return 'Workspace';
    }
    if (key.contains('quality') || key.contains('review')) {
      return 'Quality';
    }
    if (key.contains('status') || key.contains('health')) {
      return 'Status';
    }
    return 'General';
  }

  String _helpHubInventorySummary() {
    final items = _resp?.items ?? const <HelpHubLinkItemV1>[];
    final filtered = _filteredHelpHubLinks();
    final counts = <String, int>{};
    for (final item in filtered) {
      counts.update(
        _helpHubCategoryFor(item),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final categories = counts.entries
        .map((e) => '${e.key}:${e.value}')
        .join(', ');
    return 'total=${items.length} · filtered=${filtered.length}${categories.isEmpty ? '' : ' · $categories'}';
  }

  BillingWebhookEventsQueryV1 _buildBillingEventsQuery({int offset = 0}) {
    return BillingWebhookEventsQueryV1(
      informationalEvent: _billingInformationalOnly,
      provider: _billingProvider,
      rawEventId: _billingRawEventIdController.text,
      rawEventIdPrefix: _billingRawEventIdPrefixController.text,
      eventType: _billingEventTypeController.text,
      providerEventId: _billingProviderEventIdController.text,
      providerEventIdPrefix: _billingProviderEventIdPrefixController.text,
      eventCreatedFrom: _billingEventCreatedFromController.text,
      eventCreatedTo: _billingEventCreatedToController.text,
      createdFrom: _billingCreatedFromController.text,
      createdTo: _billingCreatedToController.text,
      sort: _billingSort,
      limit: 30,
      offset: offset,
    );
  }

  Uri _billingEventsUri({int offset = 0}) {
    final query = _buildBillingEventsQuery(offset: offset);
    return Uri.parse(
      '$kApiBaseUrl/api/v1/webhooks/billing/events',
    ).replace(queryParameters: query.toQueryParameters());
  }

  Future<void> _loadBillingEvents({bool append = false}) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _billingEventsError = '请先登录';
        _billingEventsPage = null;
        _billingEvents.clear();
      });
      return;
    }
    setState(() {
      if (append) {
        _loadingMoreBillingEvents = true;
      } else {
        _loadingBillingEvents = true;
      }
      _billingEventsError = null;
    });
    try {
      final response = await getBillingWebhookEventsV1(
        token,
        query: _buildBillingEventsQuery(
          offset: append
              ? (_billingEventsPage?.nextOffset ?? _billingEvents.length)
              : 0,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _billingEventsPage = response;
        if (append) {
          _billingEvents.addAll(response.items);
        } else {
          _billingEvents
            ..clear()
            ..addAll(response.items);
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingEventsError = describeRustApiError(e);
        if (!append) {
          _billingEventsPage = null;
          _billingEvents.clear();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingBillingEvents = false;
          _loadingMoreBillingEvents = false;
        });
      }
    }
  }

  Future<void> _createWebhook() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final url = _webhookUrlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _webhooksError = 'URL 不能为空';
      });
      return;
    }
    final wsRaw = _webhookWorkspaceIdController.text.trim();
    String? workspaceId;
    if (wsRaw.isNotEmpty) {
      if (!outboundWebhookWorkspaceIdLooksValid(wsRaw)) {
        setState(() {
          _webhooksError = 'workspaceId 须为合法 UUID，或留空';
        });
        return;
      }
      workspaceId = wsRaw;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
    });
    try {
      final created = await postSettingsOutboundWebhookCreateV1(
        token,
        OutboundWebhookCreateBodyV1(
          url: url,
          secret: _webhookSecretController.text.trim().isEmpty
              ? null
              : _webhookSecretController.text.trim(),
          workspaceId: workspaceId,
          eventTypes: outboundWebhookEventTypesPayloadForCreate(
            _createWebhookEventTypes,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestCreatedWebhook = created;
        _webhookUrlController.clear();
        _webhookSecretController.clear();
        _webhookWorkspaceIdController.clear();
        _createWebhookEventTypes
          ..clear()
          ..addAll(kOutboundWebhookPlatformEventTypes);
        _appendWebhookActivity(
          action: 'created',
          webhookId: created.id,
          summary: created.url,
        );
      });
      await Clipboard.setData(ClipboardData(text: created.secret));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已创建；secret 已复制到剪贴板')));
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeRustApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
        });
      }
    }
  }

  Future<void> _patchWebhookEventSubscription(
    OutboundWebhookListItemV1 wh,
    Set<String> nextSelection,
  ) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = wh.id;
    });
    try {
      await patchSettingsOutboundWebhookV1(
        token,
        wh.id,
        OutboundWebhookPatchBodyV1(
          eventTypes: outboundWebhookEventTypesPayloadForPatch(nextSelection),
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新订阅事件')),
      );
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeRustApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  Future<void> _deleteWebhook(String id) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除 Webhook'),
          content: SelectableText('即将删除 webhook：$id\n此操作会移除该目标地址。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = id;
    });
    try {
      await deleteSettingsOutboundWebhookV1(token, id);
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookLastTestResultById.remove(id);
        _webhookDeliveries.remove(id);
        if (_latestCreatedWebhook?.id == id) {
          _latestCreatedWebhook = null;
        }
        _appendWebhookActivity(
          action: 'deleted',
          webhookId: id,
          summary: 'webhook deleted',
        );
      });
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeRustApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  List<OutboundWebhookListItemV1> _filteredWebhooks() {
    final items = _webhooks?.items ?? const <OutboundWebhookListItemV1>[];
    final needle = _webhookSearchController.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return items;
    }
    return items
        .where((wh) {
          final haystack =
              '${wh.id} ${wh.url} ${wh.createdAt} ${wh.updatedAt ?? ''} ${wh.eventTypes.join(',')} ${wh.workspaceId ?? ''}'
                  .toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }

  Future<void> _loadWebhookDeliveries(String id) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _webhooksError = null;
      _loadingDeliveriesId = id;
    });
    try {
      final r = await getSettingsOutboundWebhookDeliveriesV1(
        token,
        id,
        limit: 30,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookDeliveries[id] = r;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeRustApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDeliveriesId = null;
        });
      }
    }
  }

  int _countWebhookActivity(String action) {
    return countWebhookActivity(
      _webhookActivity.map((entry) => entry.action),
      action,
    );
  }

  String _webhookInventorySummary() {
    return buildWebhookInventorySummary(
      total: _webhooks?.items.length ?? 0,
      filtered: _filteredWebhooks().length,
      sessionTestOkCount: _countWebhookActivity('test_success'),
      sessionTestFailedCount: _countWebhookActivity('test_failed'),
      latestWebhookId: _latestCreatedWebhook?.id,
    );
  }

  void _appendWebhookActivity({
    required String action,
    required String webhookId,
    required String summary,
  }) {
    _webhookActivity.insert(
      0,
      _WebhookActivityEntry(
        at: DateTime.now(),
        action: action,
        webhookId: webhookId,
        summary: summary,
      ),
    );
    if (_webhookActivity.length > 20) {
      _webhookActivity.removeRange(20, _webhookActivity.length);
    }
  }

  Future<void> _testWebhook(String id) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
      _webhookBusyId = id;
    });
    try {
      final res = await postSettingsOutboundWebhookTestV1(
        token,
        id,
        OutboundWebhookTestBodyV1(
          eventType: _webhookTestEventTypeController.text.trim().isEmpty
              ? null
              : _webhookTestEventTypeController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _webhookLastTestResultById[id] = res;
        _appendWebhookActivity(
          action: res.delivered ? 'test_success' : 'test_failed',
          webhookId: id,
          summary: res.delivered
              ? 'http=${res.httpStatus ?? "-"}'
              : 'http=${res.httpStatus ?? "-"} error=${res.error ?? "unknown"}',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.delivered
                ? '投递成功（${res.httpStatus ?? '-'}）'
                : '投递失败：${res.error ?? 'unknown'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = describeRustApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
          _webhookBusyId = null;
        });
      }
    }
  }

  String _formatWebhookTestResult(OutboundWebhookTestResponseV1 result) {
    if (result.delivered) {
      return '最近测试: success (${result.httpStatus ?? "-"})';
    }
    return '最近测试: failed (${result.httpStatus ?? "-"}) ${result.error ?? "unknown"}';
  }

  String _formatBillingEventMeta(BillingWebhookEventItemV1 item) {
    final parts = <String>[
      'provider=${item.provider ?? '-'}',
      'type=${item.eventType ?? '-'}',
      'created=${item.createdAt.toLocal().toIso8601String()}',
    ];
    if (item.eventCreatedAt != null) {
      parts.add(
        'event_created=${item.eventCreatedAt!.toLocal().toIso8601String()}',
      );
    }
    parts.add(item.isInformationalEvent ? 'informational' : 'stateful');
    return parts.join(' · ');
  }

  Map<String, int> _billingEventCountsByProvider() {
    return countBillingEventsByProvider(_billingEvents);
  }

  Map<String, int> _billingEventCountsByType() {
    return countBillingEventsByType(_billingEvents);
  }

  String _billingEventsSnapshotSummary() {
    return buildBillingEventsSnapshotSummary(_billingEvents);
  }

  String _billingEventsQuerySummary() {
    final parts = <String>[
      'provider=${_billingProvider.isEmpty ? "all" : _billingProvider}',
      'informational=${_billingInformationalOnly ?? "all"}',
      'sort=$_billingSort',
    ];
    void addText(String label, TextEditingController controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        parts.add('$label=$value');
      }
    }

    addText('event_type', _billingEventTypeController);
    addText('provider_event_id', _billingProviderEventIdController);
    addText(
      'provider_event_id_prefix',
      _billingProviderEventIdPrefixController,
    );
    addText('raw_event_id', _billingRawEventIdController);
    addText('raw_event_id_prefix', _billingRawEventIdPrefixController);
    addText('event_created_from', _billingEventCreatedFromController);
    addText('event_created_to', _billingEventCreatedToController);
    addText('created_from', _billingCreatedFromController);
    addText('created_to', _billingCreatedToController);
    return parts.join('\n');
  }

  String _buildBillingEventsCsv() {
    final rows = <List<String>>[
      <String>[
        'id',
        'provider_event_id',
        'provider',
        'raw_event_id',
        'event_type',
        'event_created_at',
        'created_at',
        'is_informational_event',
      ],
      ..._billingEvents.map(
        (item) => <String>[
          '${item.id}',
          item.providerEventId,
          item.provider ?? '',
          item.rawEventId ?? '',
          item.eventType ?? '',
          item.eventCreatedAt?.toUtc().toIso8601String() ?? '',
          item.createdAt.toUtc().toIso8601String(),
          item.isInformationalEvent ? 'true' : 'false',
        ],
      ),
    ];
    return rows.map(_toCsvLine).join('\n');
  }

  String _toCsvLine(List<String> cells) {
    return cells.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',');
  }

  Future<void> _copyBillingEventsQuerySummary() async {
    await Clipboard.setData(ClipboardData(text: _billingEventsQuerySummary()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制当前查询摘要')));
  }

  Future<void> _copyBillingEventsSnapshotSummary() async {
    await Clipboard.setData(
      ClipboardData(text: _billingEventsSnapshotSummary()),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制当前审计摘要')));
  }

  Future<void> _copyBillingAuditText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制$label')));
  }

  Future<void> _applyBillingRowFilters({
    String? provider,
    String? eventType,
    String? providerEventId,
    String? rawEventId,
  }) async {
    setState(() {
      if (provider != null) {
        _billingProvider = provider.trim();
      }
      if (eventType != null) {
        _billingEventTypeController.text = eventType.trim();
      }
      if (providerEventId != null) {
        _billingProviderEventIdController.text = providerEventId.trim();
      }
      if (rawEventId != null) {
        _billingRawEventIdController.text = rawEventId.trim();
      }
    });
    await _loadBillingEvents();
  }

  Future<void> _copyAllBillingEventsCsv() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _billingEventsError = '请先登录';
      });
      return;
    }
    setState(() {
      _exportingAllBillingEvents = true;
      _billingEventsError = null;
    });
    try {
      final all = <BillingWebhookEventItemV1>[];
      var offset = 0;
      const pageSize = 200;
      for (var page = 0; page < 20; page++) {
        final response = await getBillingWebhookEventsV1(
          token,
          query: BillingWebhookEventsQueryV1(
            informationalEvent: _billingInformationalOnly,
            provider: _billingProvider,
            rawEventId: _billingRawEventIdController.text,
            rawEventIdPrefix: _billingRawEventIdPrefixController.text,
            eventType: _billingEventTypeController.text,
            providerEventId: _billingProviderEventIdController.text,
            providerEventIdPrefix: _billingProviderEventIdPrefixController.text,
            eventCreatedFrom: _billingEventCreatedFromController.text,
            eventCreatedTo: _billingEventCreatedToController.text,
            createdFrom: _billingCreatedFromController.text,
            createdTo: _billingCreatedToController.text,
            sort: _billingSort,
            limit: pageSize,
            offset: offset,
          ),
        );
        all.addAll(response.items);
        if (!response.hasMore || response.nextOffset == null) {
          break;
        }
        offset = response.nextOffset!;
      }
      final rows = <List<String>>[
        <String>['query_summary', _billingEventsQuerySummary()],
        <String>[],
        <String>[
          'id',
          'provider_event_id',
          'provider',
          'raw_event_id',
          'event_type',
          'event_created_at',
          'created_at',
          'is_informational_event',
        ],
        ...all.map(
          (item) => <String>[
            '${item.id}',
            item.providerEventId,
            item.provider ?? '',
            item.rawEventId ?? '',
            item.eventType ?? '',
            item.eventCreatedAt?.toUtc().toIso8601String() ?? '',
            item.createdAt.toUtc().toIso8601String(),
            item.isInformationalEvent ? 'true' : 'false',
          ],
        ),
      ];
      await Clipboard.setData(
        ClipboardData(text: rows.map(_toCsvLine).join('\n')),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制全量 billing 审计 CSV（${all.length} 条）')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _billingEventsError = describeRustApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _exportingAllBillingEvents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '帮助 / 文档',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: '本机客户端偏好（与各主面板标题旁 ⋯ 相同）',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '本机：需要重新显示删除版本、归档、取消导出等高风险二次确认时，请点标题栏 ⋯ 菜单（与服务器配置无关）。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: const Text('刷新'),
              ),
              OutlinedButton(
                onPressed: (_loading || _helpHubConfig == null)
                    ? null
                    : _openHelpHubManageDialog,
                child: const Text('管理入口'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const Text('加载中...'),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          TextField(
            controller: _helpHubSearchController,
            decoration: const InputDecoration(
              labelText: '搜索帮助文档（title / id / url）',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_resp != null) Text(_helpHubInventorySummary()),
          if (_resp != null && _resp!.items.isEmpty)
            Text(
              '当前没有可用的帮助入口，请检查 settings/help/hub 配置。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_resp != null &&
              _resp!.items.isNotEmpty &&
              _filteredHelpHubLinks().isEmpty)
            Text(
              '当前搜索没有命中文档入口，请调整关键词后重试。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_resp != null)
            ..._filteredHelpHubLinks().map(
              (item) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Chip(
                              label: Text(_helpHubCategoryFor(item)),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(item.url),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '复制链接',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: item.url),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('已复制')));
                        },
                        icon: const Icon(Icons.copy),
                      ),
                      IconButton(
                        tooltip: '复制标题+链接',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: '${item.title}\n${item.url}'),
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制文档 handoff')),
                          );
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('出站 Webhook', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookUrlController,
            decoration: const InputDecoration(
              labelText: 'Webhook URL',
              hintText: 'https://example.com/webhook',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookSecretController,
            decoration: const InputDecoration(labelText: 'Secret（可空，留空则服务端生成）'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookWorkspaceIdController,
            decoration: const InputDecoration(
              labelText: 'workspaceId（可空）',
              hintText: '仅投递属于该工作区的事件；须为 UUID',
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '订阅事件（全选=默认全部；可取消不需要的类型）',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 4),
          OutboundWebhookEventChips(
            selected: _createWebhookEventTypes,
            enabled: !_loadingWebhooks,
            onSelectionChanged: (next) {
              setState(() {
                _createWebhookEventTypes
                  ..clear()
                  ..addAll(next);
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookTestEventTypeController,
            decoration: const InputDecoration(
              labelText: '测试 eventType',
              hintText: 'test.ping',
            ),
          ),
          if (_latestCreatedWebhook != null) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '最近创建的 Webhook 凭据',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () {
                            setState(() {
                              _latestCreatedWebhook = null;
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    SelectableText('id: ${_latestCreatedWebhook!.id}'),
                    SelectableText('url: ${_latestCreatedWebhook!.url}'),
                    SelectableText('secret: ${_latestCreatedWebhook!.secret}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.id),
                          ),
                          child: const Text('复制 ID'),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.url),
                          ),
                          child: const Text('复制 URL'),
                        ),
                        OutlinedButton(
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: _latestCreatedWebhook!.secret),
                          ),
                          child: const Text('复制 Secret'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _loadingWebhooks ? null : _createWebhook,
                child: Text(_loadingWebhooks ? '请求中…' : '创建'),
              ),
              OutlinedButton(
                onPressed: _loadingWebhooks ? null : _loadWebhooks,
                child: const Text('刷新列表'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _webhookSearchController,
            decoration: const InputDecoration(
              labelText: '搜索 Webhook（URL / id / createdAt）',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_loadingWebhooks) const Text('加载中...'),
          if (_webhooksError != null)
            Text(_webhooksError!, style: const TextStyle(color: Colors.red)),
          if (_webhooks != null) Text(_webhookInventorySummary()),
          if (_webhookActivity.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('最近操作', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._webhookActivity
                .take(6)
                .map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${entry.action} · ${entry.webhookId}'),
                    subtitle: SelectableText(
                      '${entry.at.toLocal().toIso8601String()}\n${entry.summary}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      tooltip: '复制记录',
                      onPressed: () => _copyBillingAuditText(
                        '${entry.action}\n${entry.webhookId}\n${entry.summary}',
                        ' webhook 操作记录',
                      ),
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ),
                ),
          ],
          if (_webhooks != null &&
              describeOutboundWebhookEmptyState(
                    total: _webhooks!.items.length,
                    filtered: _filteredWebhooks().length,
                  ) !=
                  null)
            Text(
              describeOutboundWebhookEmptyState(
                total: _webhooks!.items.length,
                filtered: _filteredWebhooks().length,
              )!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_webhooks != null)
            ..._filteredWebhooks().map(
              (wh) => Card(
                color: _latestCreatedWebhook?.id == wh.id
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wh.url,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            if (_latestCreatedWebhook?.id == wh.id)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Chip(
                                  label: const Text('最近创建'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            Text('id: ${wh.id}'),
                            Text('createdAt: ${wh.createdAt}'),
                            Text('updatedAt: ${wh.updatedAt ?? wh.createdAt}'),
                            if (!wh.enabled)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Chip(
                                  label: const Text('已停用'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '订阅事件',
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  OutboundWebhookEventChips(
                                    selected: outboundWebhookEffectiveSelection(
                                      wh.eventTypes,
                                    ),
                                    enabled: !_loadingWebhooks &&
                                        _webhookBusyId == null,
                                    onSelectionChanged: (next) {
                                      unawaited(
                                        _patchWebhookEventSubscription(wh, next),
                                      );
                                    },
                                  ),
                                  if (wh.eventTypes.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'API: ${wh.eventTypes.join(', ')}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (wh.workspaceId != null && wh.workspaceId!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'workspaceId: ${wh.workspaceId}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            if (_webhookDeliveries[wh.id] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '最近投递',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              ..._webhookDeliveries[wh.id]!.items
                                  .take(6)
                                  .map(
                                    (d) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${d.eventType} · ${d.status} · HTTP ${d.httpStatus ?? '-'}',
                                      ),
                                      subtitle: SelectableText(
                                        '${d.createdAt}\n${d.error ?? ''}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  ),
                            ],
                            if (_webhookLastTestResultById[wh.id] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatWebhookTestResult(
                                    _webhookLastTestResultById[wh.id]!,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '复制 URL',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: wh.url));
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制 Webhook URL')),
                          );
                        },
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      OutlinedButton(
                        onPressed: _loadingWebhooks || _webhookBusyId != null
                            ? null
                            : () => _testWebhook(wh.id),
                        child: Text(_webhookBusyId == wh.id ? '处理中…' : '测试投递'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed:
                            _loadingWebhooks ||
                                _webhookBusyId != null ||
                                _loadingDeliveriesId != null
                            ? null
                            : () => _loadWebhookDeliveries(wh.id),
                        child: Text(
                          _loadingDeliveriesId == wh.id ? '加载中…' : '投递记录',
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _loadingWebhooks || _webhookBusyId != null
                            ? null
                            : () => _deleteWebhook(wh.id),
                        child: Text(_webhookBusyId == wh.id ? '处理中…' : '删除'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Billing Webhook 审计',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _billingProvider,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('全部')),
                    DropdownMenuItem(value: 'stripe', child: Text('stripe')),
                    DropdownMenuItem(value: 'alipay', child: Text('alipay')),
                    DropdownMenuItem(value: 'paddle', child: Text('paddle')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _billingProvider = value ?? '';
                    });
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _billingSort,
                  decoration: const InputDecoration(labelText: '排序'),
                  items: const [
                    DropdownMenuItem(value: 'id_desc', child: Text('最新优先')),
                    DropdownMenuItem(value: 'id_asc', child: Text('最早优先')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _billingSort = value ?? 'id_desc';
                    });
                  },
                ),
              ),
              FilterChip(
                label: const Text('仅 informational'),
                selected: _billingInformationalOnly == true,
                onSelected: (selected) {
                  setState(() {
                    _billingInformationalOnly = selected ? true : null;
                  });
                },
              ),
              FilterChip(
                label: const Text('仅 stateful'),
                selected: _billingInformationalOnly == false,
                onSelected: (selected) {
                  setState(() {
                    _billingInformationalOnly = selected ? false : null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _billingEventTypeController,
            decoration: const InputDecoration(
              labelText: 'event_type',
              hintText: '例如 invoice.paid / subscription.expired',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _billingProviderEventIdController,
            decoration: const InputDecoration(
              labelText: 'provider_event_id',
              hintText: '例如 stripe:evt_123',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _billingRawEventIdController,
            decoration: const InputDecoration(
              labelText: 'raw_event_id',
              hintText: '例如 evt_123',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _billingProviderEventIdPrefixController,
            decoration: const InputDecoration(
              labelText: 'provider_event_id_prefix',
              hintText: '例如 stripe:evt_',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _billingRawEventIdPrefixController,
            decoration: const InputDecoration(
              labelText: 'raw_event_id_prefix',
              hintText: '例如 evt_',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _billingEventCreatedFromController,
                  decoration: const InputDecoration(
                    labelText: 'event_created_from',
                    hintText: '2026-04-01T00:00:00Z',
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _billingEventCreatedToController,
                  decoration: const InputDecoration(
                    labelText: 'event_created_to',
                    hintText: '2026-04-30T23:59:59Z',
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _billingCreatedFromController,
                  decoration: const InputDecoration(
                    labelText: 'created_from',
                    hintText: '2026-04-01T00:00:00Z',
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _billingCreatedToController,
                  decoration: const InputDecoration(
                    labelText: 'created_to',
                    hintText: '2026-04-30T23:59:59Z',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _loadingBillingEvents ? null : _loadBillingEvents,
                child: Text(_loadingBillingEvents ? '读取中…' : '查询审计'),
              ),
              OutlinedButton(
                onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                    ? null
                    : () {
                        setState(() {
                          _billingProvider = '';
                          _billingInformationalOnly = null;
                          _billingSort = 'id_desc';
                          _billingEventTypeController.clear();
                          _billingProviderEventIdController.clear();
                          _billingProviderEventIdPrefixController.clear();
                          _billingRawEventIdController.clear();
                          _billingRawEventIdPrefixController.clear();
                          _billingEventCreatedFromController.clear();
                          _billingEventCreatedToController.clear();
                          _billingCreatedFromController.clear();
                          _billingCreatedToController.clear();
                        });
                        _loadBillingEvents();
                      },
                child: const Text('重置并刷新'),
              ),
              OutlinedButton(
                onPressed: _billingEvents.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _buildBillingEventsCsv()),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制当前 billing 审计 CSV')),
                        );
                      },
                child: const Text('复制 CSV'),
              ),
              OutlinedButton(
                onPressed: _copyBillingEventsQuerySummary,
                child: const Text('复制查询摘要'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _billingEventsUri().toString()),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制当前查询 URL')));
                },
                child: const Text('复制查询 URL'),
              ),
              OutlinedButton(
                onPressed: _exportingAllBillingEvents
                    ? null
                    : _copyAllBillingEventsCsv,
                child: Text(_exportingAllBillingEvents ? '导出中…' : '复制全量 CSV'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingBillingEvents) const Text('加载 billing 审计中...'),
          if (_billingEventsError != null)
            Text(
              _billingEventsError!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_billingEventsPage != null)
            Text(
              'total=${_billingEventsPage!.total} · loaded=${_billingEvents.length} · has_more=${_billingEventsPage!.hasMore}',
            ),
          if (describeBillingWebhookEmptyState(
                hasPage: _billingEventsPage != null,
                loaded: _billingEvents.length,
                isLoading: _loadingBillingEvents,
                error: _billingEventsError,
              ) !=
              null)
            Text(
              describeBillingWebhookEmptyState(
                hasPage: _billingEventsPage != null,
                loaded: _billingEvents.length,
                isLoading: _loadingBillingEvents,
                error: _billingEventsError,
              )!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_billingEvents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('当前加载摘要', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_billingEventCountsByProvider().entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key} ${entry.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                Chip(
                  label: Text(
                    'informational ${_billingEvents.where((e) => e.isInformationalEvent).length}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    'stateful ${_billingEvents.where((e) => !e.isInformationalEvent).length}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(_billingEventCountsByType().entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .take(8)
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.key} ${entry.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                OutlinedButton(
                  onPressed: _copyBillingEventsSnapshotSummary,
                  child: const Text('复制审计摘要'),
                ),
              ],
            ),
          ],
          ..._billingEvents.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.providerEventId,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(_formatBillingEventMeta(item)),
                    if (item.rawEventId != null && item.rawEventId!.isNotEmpty)
                      SelectableText('raw_event_id=${item.rawEventId}'),
                    SelectableText('id=${item.id}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _copyBillingAuditText(
                            item.providerEventId,
                            ' provider_event_id',
                          ),
                          child: const Text('复制 provider_event_id'),
                        ),
                        if (item.rawEventId != null &&
                            item.rawEventId!.isNotEmpty)
                          OutlinedButton(
                            onPressed: () => _copyBillingAuditText(
                              item.rawEventId!,
                              ' raw_event_id',
                            ),
                            child: const Text('复制 raw_event_id'),
                          ),
                        if (item.provider != null &&
                            item.provider!.trim().isNotEmpty)
                          FilledButton.tonal(
                            onPressed: () => _applyBillingRowFilters(
                              provider: item.provider,
                            ),
                            child: Text('按 ${item.provider} 过滤'),
                          ),
                        if (item.eventType != null &&
                            item.eventType!.trim().isNotEmpty)
                          FilledButton.tonal(
                            onPressed: () => _applyBillingRowFilters(
                              eventType: item.eventType,
                            ),
                            child: Text('按 ${item.eventType} 过滤'),
                          ),
                        FilledButton.tonal(
                          onPressed: () => _applyBillingRowFilters(
                            providerEventId: item.providerEventId,
                            rawEventId: item.rawEventId,
                          ),
                          child: const Text('仅看这一事件'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_billingEventsPage?.hasMore == true)
            OutlinedButton(
              onPressed: _loadingBillingEvents || _loadingMoreBillingEvents
                  ? null
                  : () => _loadBillingEvents(append: true),
              child: Text(_loadingMoreBillingEvents ? '加载中…' : '加载更多审计'),
            ),
        ],
      ),
    );
  }
}
