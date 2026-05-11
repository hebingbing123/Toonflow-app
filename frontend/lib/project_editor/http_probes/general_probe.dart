part of '../../../home_page.dart';

extension _HomePageProjectEditorHttpGeneralProbe on _HomePageState {
  List<Widget> _buildProjectGeneralProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController introCtrl,
    required List<bool> generalProbeBusy,
    required List<bool> tasksProbeBusy,
    required List<bool> projectProbeBusy,
  }) {
    return [
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => generalProbeBusy[0] = true);
                try {
                  final rows = await postGeneralGetSingleProject(
                    token,
                    p.numericId,
                  );
                  if (!ctx.mounted) return;
                  final line = rows.isEmpty
                      ? '0 行'
                      : rows.map((r) => '#${r.numericId} ${r.name ?? ""}').join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('compat getSingleProject（GET projects 过滤 numeric_id）：$line'),
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
                    setDialogState(() => generalProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          generalProbeBusy[0] ? 'general…' : 'compat getSingleProject',
        ),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => generalProbeBusy[0] = true);
                try {
                  final origIntro = introCtrl.text;
                  final probeIntro = origIntro.isEmpty
                      ? '[flutter general probe]'
                      : '$origIntro [flutter general probe]';
                  final msg1 = await postGeneralUpdateProject(
                    token,
                    <String, dynamic>{
                      'id': p.numericId,
                      'projectUuid': p.id,
                      'intro': probeIntro,
                    },
                  );
                  final restoreBody = <String, dynamic>{
                    'id': p.numericId,
                    'projectUuid': p.id,
                    if (origIntro.isEmpty) 'intro': null else 'intro': origIntro,
                  };
                  final msg2 = await postGeneralUpdateProject(
                    token,
                    restoreBody,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'compat updateProject（PATCH projects）：$msg1 → restored ($msg2)',
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
                    setDialogState(() => generalProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          generalProbeBusy[0] ? 'general…' : 'compat updateProject',
        ),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => generalProbeBusy[0] = true);
                final pr = detail.project;
                try {
                  final updated = await updateProjectByProjectId(
                    token,
                    p.id,
                    <String, dynamic>{'name': pr.name ?? ''},
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'PATCH …/projects/{id} name noop → ${updated.name ?? "(null)"}',
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
                    setDialogState(() => generalProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          generalProbeBusy[0] ? 'general…' : 'PATCH projects/{id} (name noop)',
        ),
      ),
    ];
  }
}
