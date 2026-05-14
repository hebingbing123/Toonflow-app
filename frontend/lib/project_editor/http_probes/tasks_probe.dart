part of '../../../home_page.dart';

extension _HomePageProjectEditorHttpTasksProbe on _HomePageState {
  List<Widget> _buildProjectTasksProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> generalProbeBusy,
    required List<bool> tasksProbeBusy,
    required List<bool> projectProbeBusy,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return [
      TextButton(
        onPressed:
            generalProbeBusy[0] || tasksProbeBusy[0] || projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => tasksProbeBusy[0] = true);
                try {
                  final items = await postTasksGetProject(token);
                  if (!ctx.mounted) return;
                  final line = items.isEmpty
                      ? l10n.projectEditorProbeTasksZeroItems
                      : items.map((e) => '#${e.numericId} ${e.name}').join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorProbeTasksCompatGetProjectResult(line)),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiError(l10n, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          tasksProbeBusy[0]
              ? l10n.projectEditorProbeTasksBusyLabel
              : l10n.projectEditorProbeTasksButtonCompatGetProject,
        ),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] || tasksProbeBusy[0] || projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => tasksProbeBusy[0] = true);
                try {
                  final rows = await postTasksGetTaskCategories(token);
                  if (!ctx.mounted) return;
                  final line = rows.isEmpty
                      ? l10n.projectEditorProbeTasksZeroClasses
                      : rows.map((e) => e.taskClass).join(', ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(l10n.projectEditorProbeTasksCompatCategoriesResult(line)),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiError(l10n, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          tasksProbeBusy[0]
              ? l10n.projectEditorProbeTasksBusyLabel
              : l10n.projectEditorProbeTasksButtonCompatCategories,
        ),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] || tasksProbeBusy[0] || projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => tasksProbeBusy[0] = true);
                try {
                  final r = await postTasksGetTaskApi(
                    token,
                    page: 1,
                    limit: 10,
                    projectId: p.numericId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeTasksCompatGetTaskApi(r.total, r.data.length),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiError(l10n, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          tasksProbeBusy[0]
              ? l10n.projectEditorProbeTasksBusyLabel
              : l10n.projectEditorProbeTasksButtonCompatList,
        ),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] || tasksProbeBusy[0] || projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => tasksProbeBusy[0] = true);
                try {
                  final r = await postTasksGetTaskApi(
                    token,
                    page: 1,
                    limit: 1,
                    projectId: p.numericId,
                  );
                  if (r.data.isEmpty) {
                    throw StateError('no task rows for project ${p.numericId}');
                  }
                  final row = await postTasksTaskDetails(
                    token,
                    r.data.first.numericTaskId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeTasksCompatTaskDetailsResult(
                          row.numericTaskId,
                          row.kind,
                          row.status,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiError(l10n, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          tasksProbeBusy[0]
              ? l10n.projectEditorProbeTasksBusyLabel
              : l10n.projectEditorProbeTasksButtonCompatTaskDetails,
        ),
      ),
    ];
  }
}
