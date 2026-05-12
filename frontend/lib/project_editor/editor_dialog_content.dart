part of '../../home_page.dart';

extension _HomePageProjectEditorDialogContent on _HomePageState {
  Widget _buildProjectEditorDialogContent({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required _ProjectEditorDialogState dialogState,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required TextEditingController premiseCtrl,
    required TextEditingController audienceCtrl,
    required TextEditingController toneCtrl,
    required TextEditingController hookCtrl,
    required TextEditingController visualCtrl,
    required TextEditingController brandNameCtrl,
    required TextEditingController brandPromiseCtrl,
    required TextEditingController visualMotifsCtrl,
    required TextEditingController forbiddenCtrl,
    required TextEditingController continuityCtrl,
    required List<ScriptBrief> scriptList,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProjectEditorBasicsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            detail: detail,
            nameCtrl: nameCtrl,
            introCtrl: introCtrl,
            premiseCtrl: premiseCtrl,
            audienceCtrl: audienceCtrl,
            toneCtrl: toneCtrl,
            hookCtrl: hookCtrl,
            visualCtrl: visualCtrl,
            brandNameCtrl: brandNameCtrl,
            brandPromiseCtrl: brandPromiseCtrl,
            visualMotifsCtrl: visualMotifsCtrl,
            forbiddenCtrl: forbiddenCtrl,
            continuityCtrl: continuityCtrl,
            dialogState: dialogState,
          ),
          const SizedBox(height: 12),
          ProjectMembersPanel(
            accessToken: token,
            projectId: p.id,
            workspaceId: p.workspaceId ?? detail.project.workspaceId,
          ),
          const SizedBox(height: 12),
          ProjectAuditPanel(accessToken: token, projectId: p.id),
          const SizedBox(height: 12),
          _buildProjectEditorNovelsAndEventsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            dialogState: dialogState,
          ),
          const SizedBox(height: 12),
          _buildProjectEditorAssetsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            dialogState: dialogState,
            scriptList: scriptList,
          ),
          const SizedBox(height: 12),
          _buildProjectEditorScriptsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            dialogState: dialogState,
            scriptList: scriptList,
          ),
          const SizedBox(height: 12),
          _buildProjectEditorPublishSection(ctx: ctx, token: token, p: p),
        ],
      ),
    );
  }

  Widget _buildProjectEditorPublishSection({
    required BuildContext ctx,
    required String token,
    required ProjectRow p,
  }) {
    final l10n = AppLocalizations.of(ctx)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          ctx,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.projectEditorPublishSectionTitle, style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.projectEditorPublishSectionBody,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () {
                  // Close dialog first, then navigate.
                  Navigator.of(ctx).pop();
                  _productScopedProjectNumericId = p.numericId;
                  _workspaceInputController.applyProjectScope(
                    p.numericId,
                    projectUuid: p.id,
                    workspaceId: p.workspaceId,
                  );
                  _workspaceInputController.clearScriptScope();
                  _shellNavigationController.selectProductWorkspacePane(
                    ProductWorkspacePane.shortVideoSpace,
                  );
                },
                child: Text(l10n.projectEditorPublishOpenWorkspace),
              ),
              OutlinedButton(
                onPressed: () async {
                  try {
                    final overview = await fetchPublishOverview(token, p.id);
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.projectEditorPublishOverviewSnackbar(
                            overview.drafts.length,
                            overview.jobs.length,
                          ),
                        ),
                      ),
                    );
                  } on RustApiException catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(formatRustApiException(e))),
                    );
                  } catch (e) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.projectEditorPublishOverviewFailed('$e'),
                        ),
                      ),
                    );
                  }
                },
                child: Text(l10n.projectEditorPublishViewOverview),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
