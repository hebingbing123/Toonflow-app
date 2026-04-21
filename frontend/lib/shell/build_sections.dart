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
        _shellNavigationController.isProductMode
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
    final selected = <HomeSectionMode>{
      _shellNavigationController.homeSectionMode,
    };
    final isProduct = _shellNavigationController.isProductMode;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Workspace mode', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<HomeSectionMode>(
            segments: const <ButtonSegment<HomeSectionMode>>[
              ButtonSegment<HomeSectionMode>(
                value: HomeSectionMode.product,
                label: Text('Product workspace'),
              ),
              ButtonSegment<HomeSectionMode>(
                value: HomeSectionMode.debug,
                label: Text('Ops and debug'),
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
                ? '当前聚焦用户工作流：项目、Agent 工作区、任务与质量。'
                : '当前聚焦运维探针：Harness 工具目录、WS 探测与系统诊断。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

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
