// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageBuildProductSections on _HomePageState {
  Widget _buildProductPaneSelector(BuildContext context) {
    final paneEntries = <(ProductWorkspacePane, String)>[
      (ProductWorkspacePane.shortVideoSpace, '短视频 Space'),
      (ProductWorkspacePane.projects, '项目'),
      (ProductWorkspacePane.teamWorkspaces, '团队工作区'),
      (ProductWorkspacePane.scriptWorkspace, '脚本工作区'),
      (ProductWorkspacePane.productionWorkspace, '制作工作区'),
      (ProductWorkspacePane.workspaceActivity, '工作区动态'),
      (ProductWorkspacePane.benchmark, '评测基线'),
      (ProductWorkspacePane.tasks, '任务中心'),
      (ProductWorkspacePane.jobs, '任务作业'),
      (ProductWorkspacePane.quality, '质量评审'),
      (ProductWorkspacePane.helpHub, '帮助'),
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
                    selected:
                        _shellNavigationController.productWorkspacePane == pane,
                    onSelected: (selected) {
                      if (!selected) {
                        return;
                      }
                      _shellNavigationController.selectProductWorkspacePane(
                        pane,
                      );
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 10),
          PlatformShortDramaPipelineStrip(
            onSelectPane: (ProductWorkspacePane pane) {
              _shellNavigationController.selectProductWorkspacePane(pane);
            },
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
      _HelpHubSection(accessToken: _session?.accessToken),
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
          _shellNavigationController.selectProductWorkspacePane(
            ProductWorkspacePane.quality,
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
      _buildAgentWorkspacePane(
        initialPane: AgentWorkspacePane.activity,
        sectionTitle: '执行动态',
        sectionDescription: '集中查看最近 WS 事件、工具回执与回写状态，作为统一执行日志面板。',
      ),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.benchmark)
      BenchmarkSection(accessToken: _session?.accessToken),
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
      JobsSection(controller: _jobsController),
    if (_shellNavigationController.productWorkspacePane ==
        ProductWorkspacePane.quality)
      QualityReviewsSection(
        accessToken: _session?.accessToken,
        controller: _qualityReviewsController,
        initialProjectNumericId: _productScopedProjectNumericId,
      ),
  ];
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
  String? _webhookBusyId;
  final Map<String, OutboundWebhookTestResponseV1> _webhookLastTestResultById =
      <String, OutboundWebhookTestResponseV1>{};
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
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await getSettingsHelpHubLinksV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _resp = resp;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeRustApiError(e);
        _resp = null;
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
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latestCreatedWebhook = created;
        _webhookUrlController.clear();
        _webhookSecretController.clear();
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
          final haystack = '${wh.id} ${wh.url} ${wh.createdAt}'.toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
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
          Text('帮助 / 文档', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const Text('加载中...'),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_resp != null)
            ..._resp!.items.map(
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
                                if (_webhookLastTestResultById[wh.id] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      _formatWebhookTestResult(
                                        _webhookLastTestResultById[wh.id]!,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: '复制 URL',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: wh.url),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('已复制 Webhook URL'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          OutlinedButton(
                            onPressed: _loadingWebhooks || _webhookBusyId != null
                                ? null
                                : () => _testWebhook(wh.id),
                            child: Text(
                              _webhookBusyId == wh.id ? '处理中…' : '测试投递',
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
