part of '../home_page.dart';

extension _HomePageProjectEditorLegacyProbes on _HomePageState {
  Widget _buildProjectLegacyProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController introCtrl,
    required List<bool> generalLegacyBusy,
    required List<bool> tasksLegacyBusy,
    required List<bool> projectLegacyBusy,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 4,
        runSpacing: 0,
        children: [
          ..._buildProjectLegacyGeneralProbeActions(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            detail: detail,
            introCtrl: introCtrl,
            generalLegacyBusy: generalLegacyBusy,
            tasksLegacyBusy: tasksLegacyBusy,
            projectLegacyBusy: projectLegacyBusy,
          ),
          ..._buildProjectLegacyProjectProbeActions(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            detail: detail,
            generalLegacyBusy: generalLegacyBusy,
            tasksLegacyBusy: tasksLegacyBusy,
            projectLegacyBusy: projectLegacyBusy,
          ),
          TextButton(
            onPressed:
                generalLegacyBusy[0] ||
                    tasksLegacyBusy[0] ||
                    projectLegacyBusy[0]
                ? null
                : () async {
                    setDialogState(() => tasksLegacyBusy[0] = true);
                    try {
                      final items = await postTasksGetProject(token);
                      if (!ctx.mounted) return;
                      final line = items.isEmpty
                          ? '0 项'
                          : items.map((e) => '#${e.id} ${e.name}').join('; ');
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(
                        SnackBar(
                          content: Text('POST …/tasks/get-project：$line'),
                        ),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => tasksLegacyBusy[0] = false);
                      }
                    }
                  },
            child: Text(
              tasksLegacyBusy[0] ? 'tasks…' : 'POST tasks get-project',
            ),
          ),
          TextButton(
            onPressed:
                generalLegacyBusy[0] ||
                    tasksLegacyBusy[0] ||
                    projectLegacyBusy[0]
                ? null
                : () async {
                    setDialogState(() => tasksLegacyBusy[0] = true);
                    try {
                      final rows = await postTasksGetTaskCategories(token);
                      if (!ctx.mounted) return;
                      final line = rows.isEmpty
                          ? '0 类'
                          : rows.map((e) => e.taskClass).join(', ');
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'POST …/tasks/get-task-categories：$line',
                          ),
                        ),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => tasksLegacyBusy[0] = false);
                      }
                    }
                  },
            child: Text(
              tasksLegacyBusy[0] ? 'tasks…' : 'POST tasks get-task-categories',
            ),
          ),
          TextButton(
            onPressed:
                generalLegacyBusy[0] ||
                    tasksLegacyBusy[0] ||
                    projectLegacyBusy[0]
                ? null
                : () async {
                    setDialogState(() => tasksLegacyBusy[0] = true);
                    try {
                      final r = await postTasksGetTaskApi(
                        token,
                        page: 1,
                        limit: 10,
                        projectId: p.legacyId,
                      );
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'POST …/tasks/get-task-api：total=${r.total} · ${r.data.length} 条本页',
                          ),
                        ),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => tasksLegacyBusy[0] = false);
                      }
                    }
                  },
            child: Text(
              tasksLegacyBusy[0] ? 'tasks…' : 'POST tasks get-task-api',
            ),
          ),
          TextButton(
            onPressed:
                generalLegacyBusy[0] ||
                    tasksLegacyBusy[0] ||
                    projectLegacyBusy[0]
                ? null
                : () async {
                    setDialogState(() => tasksLegacyBusy[0] = true);
                    try {
                      await postTasksTaskDetails(token, 1);
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text('POST …/tasks/task-details：501（预期）'),
                        ),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => tasksLegacyBusy[0] = false);
                      }
                    }
                  },
            child: Text(
              tasksLegacyBusy[0] ? 'tasks…' : 'POST tasks task-details (501)',
            ),
          ),
        ],
      ),
    );
  }
}
