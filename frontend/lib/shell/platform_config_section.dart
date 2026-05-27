part of '../../home_page.dart';

class _PlatformConfigSection extends StatefulWidget {
  const _PlatformConfigSection({
    required this.accessToken,
    required this.currentWorkspaceId,
    required this.initialConfig,
    required this.onConfigSaved,
    this.debugResponse,
  });

  final String? accessToken;
  final String? currentWorkspaceId;
  final PlatformConfigToggleSetV1 initialConfig;
  final ValueChanged<PlatformConfigToggleSetV1> onConfigSaved;
  final PlatformConfigResponseV1? debugResponse;

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
    final debug = widget.debugResponse;
    if (debug != null) {
      _userDraft = debug.userOverride;
      _workspaceDraft = _workspaceDraftForResponse(debug);
      _response = debug;
      return;
    }
    _userDraft = widget.initialConfig;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_load());
    });
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
    if (widget.debugResponse != null) {
      return;
    }
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    final token = widget.accessToken;
    final workspaceId = widget.currentWorkspaceId;
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _error = l10n.platformConfigPleaseSignIn;
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
    } catch (e) {
      if (!_isCurrentLoadRequest(requestEpoch, token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackUserSaved,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackUserReset,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackWorkspaceSaved,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            resolveAppLocalizationsForErrors(
              context,
            ).platformConfigSnackWorkspaceReset,
          ),
        ),
      );
    } catch (e) {
      if (!_isCurrentMutationContext(token, workspaceId)) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
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
    final loc = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.platformConfigSnackCopyJsonDone)),
    );
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

  Widget _buildStudioHeader(BuildContext context, AppLocalizations l10n) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: studioShadowColor(context, alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.platformConfigSectionTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(
              l10n.platformConfigSectionSubtitle,
              style: studioSectionIntroStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsetConfigSection(
    BuildContext context, {
    required String title,
    String? intro,
    String? stateLine,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: studioCardTitleStyle(context)),
            if (intro != null) ...<Widget>[
              const SizedBox(height: StudioLayoutSpacing.titleTight),
              Text(intro, style: studioSectionIntroStyle(context)),
            ],
            if (stateLine != null) ...<Widget>[
              const SizedBox(height: StudioLayoutSpacing.titleTight),
              Text(stateLine, style: studioSectionIntroStyle(context)),
            ],
            const SizedBox(height: StudioSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildToggleEditor({
    required AppLocalizations l10n,
    required PlatformConfigToggleSetV1 draft,
    required ValueChanged<PlatformConfigToggleSetV1>? onChanged,
  }) {
    return Column(
      children: [
        StudioSwitchListRow(
          value: draft.helpHubEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(helpHubEnabled: v)),
          title: Text(l10n.platformConfigToggleHelpHubTitle),
          subtitle: Text(l10n.platformConfigToggleHelpHubSubtitle),
        ),
        StudioSwitchListRow(
          value: draft.qualityDashboardEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(qualityDashboardEnabled: v)),
          title: Text(l10n.platformConfigToggleQualityMainTitle),
          subtitle: Text(l10n.platformConfigToggleQualityMainSubtitle),
        ),
        StudioSwitchListRow(
          value: draft.qualityRefreshControlsEnabled,
          onChanged: onChanged == null
              ? null
              : (v) =>
                    onChanged(draft.copyWith(qualityRefreshControlsEnabled: v)),
          title: Text(l10n.platformConfigToggleQualityRefreshTitle),
          subtitle: Text(l10n.platformConfigToggleQualityRefreshSubtitle),
        ),
        StudioSwitchListRow(
          value: draft.platformStatusEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(platformStatusEnabled: v)),
          title: Text(l10n.platformConfigTogglePlatformStatusTitle),
          subtitle: Text(l10n.platformConfigTogglePlatformStatusSubtitle),
        ),
        StudioSwitchListRow(
          value: draft.workspaceActivityEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(workspaceActivityEnabled: v)),
          title: Text(l10n.platformConfigToggleWorkspaceActivityTitle),
          subtitle: Text(l10n.platformConfigToggleWorkspaceActivitySubtitle),
        ),
        StudioSwitchListRow(
          value: draft.benchmarkPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(benchmarkPaneEnabled: v)),
          title: Text(l10n.platformConfigToggleBenchmarkTitle),
          subtitle: Text(l10n.platformConfigToggleBenchmarkSubtitle),
        ),
        StudioSwitchListRow(
          value: draft.jobsPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(jobsPaneEnabled: v)),
          title: Text(l10n.platformConfigToggleJobsTitle),
          subtitle: Text(l10n.platformConfigToggleJobsSubtitle),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildStudioHeader(context, l10n),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          _buildInsetConfigSection(
            context,
            title: l10n.riskyPrefsMenuDefaultTooltip,
            intro: l10n.platformConfigLocalPrefsDescription,
            child: const SizedBox.shrink(),
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          StudioCollapsibleFilterPanel(
            collapsible: true,
            title: l10n.platformConfigButtonRefresh,
            subtitle: _loading
                ? l10n.platformConfigButtonRefreshing
                : null,
            child: StudioFilterRow(
              wideLayout: StudioFilterWideLayout.toolbarRow,
              wideBreakpoint: 560,
              children: <Widget>[
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: _loading ? null : _load,
                  child: Text(
                    _loading
                        ? l10n.platformConfigButtonRefreshing
                        : l10n.platformConfigButtonRefresh,
                  ),
                ),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(context),
                  onPressed: _savingUser || !userDraftDirty ? null : _saveUser,
                  child: Text(
                    _savingUser
                        ? l10n.platformConfigButtonSaving
                        : l10n.platformConfigButtonSaveUser,
                  ),
                ),
                OutlinedButton(
                  style: studioFormSecondaryButtonStyle(context),
                  onPressed:
                      _savingUser || !(_response?.hasUserOverride ?? false)
                      ? null
                      : _resetUser,
                  child: Text(l10n.platformConfigButtonResetUser),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed:
                      _savingWorkspace ||
                          !workspaceDraftDirty ||
                          workspace == null ||
                          !workspace.canManageOverride
                      ? null
                      : _saveWorkspace,
                  child: Text(
                    _savingWorkspace
                        ? l10n.platformConfigButtonSaving
                        : l10n.platformConfigButtonSaveWorkspace,
                  ),
                ),
                OutlinedButton(
                  style: studioFormSecondaryButtonStyle(context),
                  onPressed:
                      _savingWorkspace ||
                          workspace == null ||
                          !workspace.canManageOverride ||
                          !(_response?.hasWorkspaceOverride ?? false)
                      ? null
                      : _resetWorkspace,
                  child: Text(l10n.platformConfigButtonResetWorkspace),
                ),
                OutlinedButton(
                  style: studioFormSecondaryButtonStyle(context),
                  onPressed: _response == null ? null : _copyConfig,
                  child: Text(l10n.platformConfigButtonCopyJson),
                ),
              ],
            ),
          ),
          StudioAsyncDataView(
            loading: _loading && _response == null,
            error: _response == null && !_loading ? _error : null,
            onRetry: _load,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_error != null && _response != null) ...<Widget>[
                  const SizedBox(height: StudioLayoutSpacing.stackMedium),
                  StudioApiErrorCallout(
                    error: _error!,
                    onRetry: _load,
                    emphasis: StudioApiErrorCalloutEmphasis.subtle,
                  ),
                ],
                if (_response != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            DecoratedBox(
              decoration: studioInsetPanelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(
                  StudioLayoutSpacing.insetComfortable,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SelectableText(
                      'scope=${_response!.scope} · schema=v${_response!.schemaVersion}',
                    ),
                    const SizedBox(height: StudioLayoutSpacing.titleTight),
                    SelectableText(
                      'plan_tier=${_response!.planTier} · has_plan_override=${_response!.hasPlanOverride}',
                    ),
                    if (workspace != null) ...<Widget>[
                      const SizedBox(height: StudioLayoutSpacing.titleTight),
                      SelectableText(
                        'current_workspace=${workspace.name} (${workspace.workspaceType}) · role=${workspace.role} · can_manage_override=${workspace.canManageOverride}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            _buildInsetConfigSection(
              context,
              title: l10n.platformConfigPlanOverrideTitle,
              intro: l10n.platformConfigPlanLayerIntro,
              stateLine: _response!.hasPlanOverride
                  ? l10n.platformConfigPlanStateActive
                  : l10n.platformConfigPlanStateInactive,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'env: OPENFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON',
                    style: studioSectionIntroStyle(context),
                  ),
                  if (_response!.planOverride != null) ...<Widget>[
                    const SizedBox(height: StudioSpacing.sm),
                    _buildToggleEditor(
                      l10n: l10n,
                      draft: _response!.planOverride!,
                      onChanged: null,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (workspace != null && workspaceDraft != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            _buildInsetConfigSection(
              context,
              title: l10n.platformConfigWorkspaceOverrideTitle,
              intro: workspace.canManageOverride
                  ? l10n.platformConfigWorkspaceEnterpriseIntro
                  : l10n.platformConfigWorkspaceViewOnlyIntro,
              stateLine: (_response?.hasWorkspaceOverride ?? false)
                  ? l10n.platformConfigWorkspaceStateWritten
                  : l10n.platformConfigWorkspaceStateInherit,
              child: _buildToggleEditor(
                l10n: l10n,
                draft: workspaceDraft,
                onChanged: workspace.canManageOverride
                    ? _patchWorkspaceDraft
                    : null,
              ),
            ),
          ],
          if (workspace != null && workspaceDraft == null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            _buildInsetConfigSection(
              context,
              title: l10n.platformConfigWorkspaceOverrideTitle,
              intro: workspace.workspaceType == 'enterprise'
                  ? l10n.platformConfigWorkspaceNoDraftEnterprise
                  : l10n.platformConfigWorkspaceNoDraftPersonal,
              child: const SizedBox.shrink(),
            ),
          ],
          if (userDraft != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            _buildInsetConfigSection(
              context,
              title: l10n.platformConfigUserOverrideTitle,
              intro: l10n.platformConfigUserOverrideIntro,
              stateLine: (_response?.hasUserOverride ?? false)
                  ? l10n.platformConfigUserStateWritten
                  : l10n.platformConfigUserStateInherit,
              child: _buildToggleEditor(
                l10n: l10n,
                draft: userDraft,
                onChanged: _patchUserDraft,
              ),
            ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
