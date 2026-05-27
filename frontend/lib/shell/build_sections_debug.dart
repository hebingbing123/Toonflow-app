// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageBuildDebugSections on _HomePageState {
  void _applyDebugPreviewDataIfNeeded() {
    _applyDemoCatalogIfNeeded();
  }

  Future<void> _openComplianceOpsTarget(
    ContentComplianceReportItemV1 item,
  ) async {
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final messenger = ScaffoldMessenger.of(context);
    _shellNavigationController.selectHomeSectionMode(HomeSectionMode.debug);
    switch (item.targetType) {
      case 'user':
        await _adminConsoleController.loadUser(item.targetId);
        return;
      case 'project':
        await _adminConsoleController.loadProject(item.targetId);
        return;
      default:
        if ((item.projectId ?? '').isNotEmpty) {
          await _adminConsoleController.loadProject(item.projectId!);
          return;
        }
        if ((item.workspaceId ?? '').isNotEmpty) {
          await _adminConsoleController.loadWorkspace(item.workspaceId!);
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.productComplianceNoProjectContext)),
        );
    }
  }

  List<Widget> _buildDebugSections() => [
    if (kInternalOpsToken.isNotEmpty)
      AdminConsoleSection(controller: _adminConsoleController),
    if (kInternalOpsToken.isNotEmpty) const SizedBox(height: StudioSpacing.sm),
    ContentComplianceSection(
      controller: _contentComplianceController,
      onOpenTarget: _openComplianceOpsTarget,
      onOpenOpsTarget: _openComplianceOpsTarget,
    ),
    const SizedBox(height: StudioSpacing.sm),
    HarnessSection(
      loadingHarnessTools: _skillsHarnessController.loadingHarnessTools,
      loadingUserWasmValidate: _skillsHarnessController.loadingUserWasmValidate,
      loadingUserWasmPersist: _skillsHarnessController.loadingUserWasmPersist,
      loadingUserWasmList: _skillsHarnessController.loadingUserWasmList,
      loadingUserWasmRevoke: _skillsHarnessController.loadingUserWasmRevoke,
      loadingSkillsSummary: _skillsHarnessController.loadingSkillsSummary,
      loadingSkillList: _skillsHarnessController.loadingSkillList,
      loadingSkillPreview: _skillsHarnessController.loadingSkillPreview,
      loadingSkillVersions: _skillsHarnessController.loadingSkillVersions,
      loadingSkillPut: _skillsHarnessController.loadingSkillPut,
      loadingSkillPost: _skillsHarnessController.loadingSkillPost,
      loadingSkillDelete: _skillsHarnessController.loadingSkillDelete,
      rollingBackSkillVersion: _skillsHarnessController.rollingBackSkillVersion,
      wsProbesBusy: _workspaceWsEventController.wsProbesBusy,
      loadingWs: _loadingWs,
      loadingWsHarness: _loadingWsHarness,
      loadingWsIsolatedEcho: _loadingWsIsolatedEcho,
      loadingWsWasmProbe: _loadingWsWasmProbe,
      loadingWsSkillsRead: _loadingWsSkillsRead,
      loadingWsHarnessAgent: _loadingWsHarnessAgent,
      harnessToolsLine: _skillsHarnessController.harnessToolsLine,
      userWasmValidateLine: _skillsHarnessController.userWasmValidateLine,
      userWasmPersistLine: _skillsHarnessController.userWasmPersistLine,
      userWasmListLine: _skillsHarnessController.userWasmListLine,
      userWasmRevokeTargetId: _skillsHarnessController.userWasmRevokeTargetId,
      userWasmRevokeLine: _skillsHarnessController.userWasmRevokeLine,
      skillsAggregateLine: _skillsHarnessController.skillsAggregateLine,
      skillsListSummary: _skillsHarnessController.skillsListSummary,
      skillMutationLine: _skillsHarnessController.skillMutationLine,
      skillPathController: _skillsHarnessController.skillPathController,
      skillContentController: _skillsHarnessController.skillContentController,
      wsLog: _wsLog,
      onLoadHarnessTools: _skillsHarnessController.loadHarnessTools,
      onValidateUserWasmProbe: _skillsHarnessController.validateUserWasmProbe,
      onPersistUserWasmProbe: _skillsHarnessController.persistUserWasmProbe,
      onLoadUserWasmList: _skillsHarnessController.loadUserWasmList,
      onRevokeUserWasmProbe: () async {
        final confirmed = await showStudioConfirmDialog(
          context: context,
          title: 'Revoke user WASM?',
          message:
              'This will revoke the selected user WASM entry and cannot be undone.',
          confirmLabel: 'Revoke',
          cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          destructive: true,
        );
        if (confirmed != true || !mounted) {
          return;
        }
        await _skillsHarnessController.revokeUserWasmProbe();
      },
      onRevokeUserWasmProbeAndReloadList: () async {
        final confirmed = await showStudioConfirmDialog(
          context: context,
          title: 'Revoke user WASM?',
          message:
              'This will revoke the selected user WASM entry, reload the list, and cannot be undone.',
          confirmLabel: 'Revoke',
          cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          destructive: true,
        );
        if (confirmed != true || !mounted) {
          return;
        }
        await _skillsHarnessController.revokeUserWasmProbeAndReloadList();
      },
      onLoadSkillsAggregate: _skillsHarnessController.loadSkillsAggregate,
      onLoadSkillList: _skillsHarnessController.loadSkillList,
      onPreviewSkillFile: () =>
          _skillsHarnessController.previewSkillFile(context),
      onShowSkillVersionHistory: () =>
          _skillsHarnessController.showSkillVersionHistory(context),
      onPutSkillProbe: _skillsHarnessController.putSkillProbe,
      onPostSkillProbe: _skillsHarnessController.postSkillProbe,
      onDeleteSkillProbe: () =>
          _skillsHarnessController.deleteSkillProbe(context),
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
}
