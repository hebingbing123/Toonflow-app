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
                      ? '0 项'
                      : items.map((e) => '#${e.numericId} ${e.name}').join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('compat getProject（GET projects）：$line'),
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
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(tasksProbeBusy[0] ? 'tasks…' : 'compat tasks get-project'),
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
                      ? '0 类'
                      : rows.map((e) => e.taskClass).join(', ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('compat categories（GET jobs/kinds）：$line'),
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
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(tasksProbeBusy[0] ? 'tasks…' : 'compat tasks categories'),
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
                        'compat get-task-api（GET jobs/page）：total=${r.total} · ${r.data.length} 条本页',
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
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(tasksProbeBusy[0] ? 'tasks…' : 'compat tasks list'),
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
                        'compat task-details（GET jobs/task-detail）：#${row.numericTaskId} -> ${row.kind}/${row.status}',
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
                    setDialogState(() => tasksProbeBusy[0] = false);
                  }
                }
              },
        child: Text(tasksProbeBusy[0] ? 'tasks…' : 'compat task-details int'),
      ),
    ];
  }
}
