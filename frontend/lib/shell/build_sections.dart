import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageBuildSections on _HomePageState {
  List<Widget> _buildHomePageSections(BuildContext context, Session? session) {
    final signedIn = session != null;
    final widgets = <Widget>[
      _buildOverviewSection(),
      const SizedBox(height: 16),
      _buildLocaleSection(context),
      if (kInternalOpsToken.isNotEmpty) ...[
        const SizedBox(height: 16),
        const JobQueueStatsCard(),
      ],
      _buildAuthSection(session, signedIn),
    ];

    if (signedIn) {
      widgets.add(_buildWorkspaceContextSection(context));
      widgets.add(_buildWorkspaceModeSection(context));
      widgets.addAll(
        _shellNavigationController.isProductMode
            ? _buildProductSections(context)
            : _buildDebugSections(),
      );
    }

    widgets.addAll(_buildErrorSection(context));
    return widgets;
  }

  Widget _buildLocaleSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }
    final notifier = AppLocaleNotifier.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.localeSectionTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: notifier,
              builder: (BuildContext context, _) {
                return StudioDropdownButton<String>(
                  isExpanded: true,
                  value: notifier.code,
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'system',
                      child: Text(l10n.localeSystem),
                    ),
                    DropdownMenuItem<String>(
                      value: 'en',
                      child: Text(l10n.localeEnglish),
                    ),
                    DropdownMenuItem<String>(
                      value: 'zh',
                      child: Text(l10n.localeChinese),
                    ),
                  ],
                  onChanged: (String? v) {
                    if (v != null) {
                      notifier.setLocaleCode(v);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
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
    emailController: _authController.emailController,
    passwordController: _authController.passwordController,
    loadingMe: _accountProbesController.loadingMe,
    loadingDevSwitchProbe: _accountProbesController.loadingDevSwitchProbe,
    loadingMemoryConfigProbe: _accountProbesController.loadingMemoryConfigProbe,
    loadingAboutProbe: _accountProbesController.loadingAboutProbe,
    loadingUsageSummary: _accountProbesController.loadingUsageSummary,
    loadingPromptsProbe: _contentProbesController.loadingPromptsProbe,
    loadingVisualManualProbe: _contentProbesController.loadingVisualManualProbe,
    loadingDirectorManualProbe:
        _contentProbesController.loadingDirectorManualProbe,
    loadingSkillsBinaryProbe: _contentProbesController.loadingSkillsBinaryProbe,
    loadingModelsCatalog: _modelsCatalogController.loadingModelsCatalog,
    loadingTextModelDefault: _contentProbesController.loadingTextModelDefault,
    loadingModelDetail: _contentProbesController.loadingModelDetail,
    meBody: _accountProbesController.meBody,
    devSwitchProbeBody: _accountProbesController.devSwitchProbeBody,
    memoryConfigProbeBody: _accountProbesController.memoryConfigProbeBody,
    aboutProbeBody: _accountProbesController.aboutProbeBody,
    usageSummaryBody: _accountProbesController.usageSummaryBody,
    promptsProbeBody: _contentProbesController.promptsProbeBody,
    visualManualProbeBody: _contentProbesController.visualManualProbeBody,
    directorManualProbeBody: _contentProbesController.directorManualProbeBody,
    skillsBinaryProbeBody: _contentProbesController.skillsBinaryProbeBody,
    modelsCatalogBody: _modelsCatalogController.modelsCatalogBody,
    textModelDefaultBody: _contentProbesController.textModelDefaultBody,
    modelDetailBody: _contentProbesController.modelDetailBody,
    onSignIn: _authController.signIn,
    onSignUp: _authController.signUp,
    onSignOut: _authController.signOut,
    onCallMe: _accountProbesController.callMe,
    onCallDevSwitchProbe: _accountProbesController.callDevSwitchProbe,
    onCallMemoryConfigProbe: _accountProbesController.callMemoryConfigProbe,
    onCallAboutProbe: _accountProbesController.callAboutProbe,
    onCallUsageSummary: _accountProbesController.callUsageSummary,
    onCallPromptsProbe: _contentProbesController.callPromptsProbe,
    onCallVisualManualProbe: _contentProbesController.callVisualManualProbe,
    onCallDirectorManualProbe: _contentProbesController.callDirectorManualProbe,
    onCallSkillsBinaryProbe: _contentProbesController.callSkillsBinaryProbe,
    onCallModelsCatalog: _modelsCatalogController.callModelsCatalog,
    onCallTextModelDefault: _contentProbesController.callTextModelDefault,
    onCallModelDetail: _contentProbesController.callModelDetail,
  );

  Widget _buildWorkspaceModeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }
    final selected = <HomeSectionMode>{
      _shellNavigationController.homeSectionMode,
    };
    final isProduct = _shellNavigationController.isProductMode;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.workspaceModeTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<HomeSectionMode>(
            segments: <ButtonSegment<HomeSectionMode>>[
              ButtonSegment<HomeSectionMode>(
                value: HomeSectionMode.product,
                label: Text(l10n.workspaceModeProduct),
              ),
              ButtonSegment<HomeSectionMode>(
                value: HomeSectionMode.debug,
                label: Text(l10n.workspaceModeDebug),
              ),
            ],
            selected: selected,
            onSelectionChanged: (selection) {
              final nextMode = selection.firstOrNull;
              _shellNavigationController.selectHomeSectionMode(nextMode);
            },
          ),
          const SizedBox(height: 8),
          Text(
            isProduct
                ? l10n.workspaceModeDescriptionProduct
                : l10n.workspaceModeDescriptionDebug,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceContextSection(
    BuildContext context, {
    bool compact = false,
    bool inline = false,
  }) {
    final workspace = _sessionMe?.currentWorkspace;
    final projects = _projectsController.projects;
    final projectUuid =
        _workspaceInputController.projectUuidController.text.trim().isEmpty
        ? null
        : _workspaceInputController.projectUuidController.text.trim();
    final l10n = AppLocalizations.of(context)!;
    final projectLabel = productWorkspaceProjectLabel(
      l10n: l10n,
      projects: projects,
      projectNumericId: _productScopedProjectNumericId,
      projectUuid: projectUuid,
    );

    // Task 6.2: Extract workspace billing info from v2 response
    final meV2 = _sessionMeV2;
    final billingScope = meV2?.billingScope;
    final workspaceBilling = meV2?.currentWorkspaceBilling;

    return WorkspaceContextView(
      loading: _loadingSessionMe,
      workspaceName: workspace?.name,
      workspaceType: workspace?.workspaceType,
      projectLabel: projectLabel,
      billingScope: billingScope,
      workspacePlanTier: workspaceBilling?.planTier,
      workspaceDailyJobQuota: workspaceBilling?.dailyJobQuota,
      workspaceJobsToday: workspaceBilling?.jobsToday,
      compact: compact,
      inline: inline,
    );
  }

  List<Widget> _buildErrorSection(BuildContext context) {
    if (_error == null) return const [];
    final err = _error!;
    final line = resolveAppLocalizationsForErrors(context).errorLine(err);
    return [
      const SizedBox(height: 16),
      Text(line, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ];
  }
}
