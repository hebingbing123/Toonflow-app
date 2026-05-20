part of '../../home_page.dart';

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

  Widget _buildToggleEditor({
    required AppLocalizations l10n,
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
          title: Text(l10n.platformConfigToggleHelpHubTitle),
          subtitle: Text(l10n.platformConfigToggleHelpHubSubtitle),
        ),
        SwitchListTile(
          value: draft.qualityDashboardEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(qualityDashboardEnabled: v)),
          title: Text(l10n.platformConfigToggleQualityMainTitle),
          subtitle: Text(l10n.platformConfigToggleQualityMainSubtitle),
        ),
        SwitchListTile(
          value: draft.qualityRefreshControlsEnabled,
          onChanged: onChanged == null
              ? null
              : (v) =>
                    onChanged(draft.copyWith(qualityRefreshControlsEnabled: v)),
          title: Text(l10n.platformConfigToggleQualityRefreshTitle),
          subtitle: Text(l10n.platformConfigToggleQualityRefreshSubtitle),
        ),
        SwitchListTile(
          value: draft.platformStatusEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(platformStatusEnabled: v)),
          title: Text(l10n.platformConfigTogglePlatformStatusTitle),
          subtitle: Text(l10n.platformConfigTogglePlatformStatusSubtitle),
        ),
        SwitchListTile(
          value: draft.workspaceActivityEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(workspaceActivityEnabled: v)),
          title: Text(l10n.platformConfigToggleWorkspaceActivityTitle),
          subtitle: Text(l10n.platformConfigToggleWorkspaceActivitySubtitle),
        ),
        SwitchListTile(
          value: draft.benchmarkPaneEnabled,
          onChanged: onChanged == null
              ? null
              : (v) => onChanged(draft.copyWith(benchmarkPaneEnabled: v)),
          title: Text(l10n.platformConfigToggleBenchmarkTitle),
          subtitle: Text(l10n.platformConfigToggleBenchmarkSubtitle),
        ),
        SwitchListTile(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.platformConfigSectionTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.riskyPrefsTooltipSameAsMainPanelHeaders,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.platformConfigSectionSubtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.riskyPrefsMenuDefaultTooltip,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.platformConfigLocalPrefsDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _loading ? null : _load,
              child: Text(
                _loading
                    ? l10n.platformConfigButtonRefreshing
                    : l10n.platformConfigButtonRefresh,
              ),
            ),
            FilledButton(
              onPressed: _savingUser || !userDraftDirty ? null : _saveUser,
              child: Text(
                _savingUser
                    ? l10n.platformConfigButtonSaving
                    : l10n.platformConfigButtonSaveUser,
              ),
            ),
            OutlinedButton(
              onPressed: _savingUser || !(_response?.hasUserOverride ?? false)
                  ? null
                  : _resetUser,
              child: Text(l10n.platformConfigButtonResetUser),
            ),
            FilledButton.tonal(
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
              onPressed: _response == null ? null : _copyConfig,
              child: Text(l10n.platformConfigButtonCopyJson),
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
          Text(
            l10n.platformConfigPlanOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.platformConfigPlanLayerIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'env: OPENFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            _response!.hasPlanOverride
                ? l10n.platformConfigPlanStateActive
                : l10n.platformConfigPlanStateInactive,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_response!.planOverride != null) ...[
            const SizedBox(height: 12),
            _buildToggleEditor(
              l10n: l10n,
              draft: _response!.planOverride!,
              onChanged: null,
            ),
          ],
        ],
        if (workspace != null && workspaceDraft != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigWorkspaceOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            workspace.canManageOverride
                ? l10n.platformConfigWorkspaceEnterpriseIntro
                : l10n.platformConfigWorkspaceViewOnlyIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            (_response?.hasWorkspaceOverride ?? false)
                ? l10n.platformConfigWorkspaceStateWritten
                : l10n.platformConfigWorkspaceStateInherit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildToggleEditor(
            l10n: l10n,
            draft: workspaceDraft,
            onChanged: workspace.canManageOverride
                ? _patchWorkspaceDraft
                : null,
          ),
        ],
        if (workspace != null && workspaceDraft == null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigWorkspaceOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            workspace.workspaceType == 'enterprise'
                ? l10n.platformConfigWorkspaceNoDraftEnterprise
                : l10n.platformConfigWorkspaceNoDraftPersonal,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (userDraft != null) ...[
          const SizedBox(height: 12),
          Text(
            l10n.platformConfigUserOverrideTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.platformConfigUserOverrideIntro,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            (_response?.hasUserOverride ?? false)
                ? l10n.platformConfigUserStateWritten
                : l10n.platformConfigUserStateInherit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _buildToggleEditor(
            l10n: l10n,
            draft: userDraft,
            onChanged: _patchUserDraft,
          ),
        ],
      ],
    );
  }
}
