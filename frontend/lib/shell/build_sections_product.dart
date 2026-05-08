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

class _HelpHubSectionState extends State<_HelpHubSection> {
  bool _loading = false;
  String? _error;
  HelpHubLinksResponseV1? _resp;
  bool _loadingWebhooks = false;
  String? _webhooksError;
  OutboundWebhookListResponseV1? _webhooks;
  final _webhookUrlController = TextEditingController();

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
        _error = e.toString();
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
  }

  @override
  void dispose() {
    _webhookUrlController.dispose();
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
        _webhooksError = e.toString();
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
        OutboundWebhookCreateBodyV1(url: url),
      );
      if (!mounted) {
        return;
      }
      _webhookUrlController.clear();
      await Clipboard.setData(ClipboardData(text: created.secret));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建；secret 已复制到剪贴板')),
      );
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = e.toString();
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
    setState(() {
      _loadingWebhooks = true;
      _webhooksError = null;
    });
    try {
      await deleteSettingsOutboundWebhookV1(token, id);
      if (!mounted) {
        return;
      }
      await _loadWebhooks();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webhooksError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
        });
      }
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
    });
    try {
      final res = await postSettingsOutboundWebhookTestV1(
        token,
        id,
        const OutboundWebhookTestBodyV1(eventType: 'test.ping'),
      );
      if (!mounted) {
        return;
      }
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
        _webhooksError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWebhooks = false;
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
                            Text(item.title,
                                style: Theme.of(context).textTheme.titleSmall),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制')),
                          );
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
          if (_loadingWebhooks) const Text('加载中...'),
          if (_webhooksError != null)
            Text(_webhooksError!, style: const TextStyle(color: Colors.red)),
          if (_webhooks != null)
            ..._webhooks!.items.map(
              (wh) => Card(
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
                            Text('id: ${wh.id}'),
                            Text('createdAt: ${wh.createdAt}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _loadingWebhooks ? null : () => _testWebhook(wh.id),
                        child: const Text('测试投递'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed:
                            _loadingWebhooks ? null : () => _deleteWebhook(wh.id),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
