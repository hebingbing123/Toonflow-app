part of '../home_page.dart';

extension _HomePageProjectEditorLegacyGeneralProbe on _HomePageState {
  List<Widget> _buildProjectLegacyGeneralProbeActions({
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
    return [
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => generalLegacyBusy[0] = true);
                try {
                  final rows = await postGeneralGetSingleProject(
                    token,
                    p.legacyId,
                  );
                  if (!ctx.mounted) return;
                  final line = rows.isEmpty
                      ? '0 行'
                      : rows.map((r) => '#${r.legacyId} ${r.name ?? ""}').join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('POST …/general/get-single-project：$line'),
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
                    setDialogState(() => generalLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(
          generalLegacyBusy[0] ? 'general…' : 'POST general get-single-project',
        ),
      ),
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => generalLegacyBusy[0] = true);
                try {
                  final origIntro = introCtrl.text;
                  final probeIntro = origIntro.isEmpty
                      ? '[flutter general probe]'
                      : '$origIntro [flutter general probe]';
                  final msg1 = await postGeneralUpdateProject(
                    token,
                    <String, dynamic>{
                      'id': p.legacyId,
                      'intro': probeIntro,
                    },
                  );
                  final restoreBody = <String, dynamic>{
                    'id': p.legacyId,
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
                        'POST …/general/update-project：$msg1 → restored ($msg2)',
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
                    setDialogState(() => generalLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(
          generalLegacyBusy[0] ? 'general…' : 'POST general update-project',
        ),
      ),
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => generalLegacyBusy[0] = true);
                final pr = detail.project;
                try {
                  final updated = await updateProjectByLegacyId(
                    token,
                    p.legacyId,
                    <String, dynamic>{'name': pr.name ?? ''},
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'PATCH …/projects/legacy/${p.legacyId} name noop → ${updated.name ?? "(null)"}',
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
                    setDialogState(() => generalLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(
          generalLegacyBusy[0] ? 'general…' : 'PATCH projects/legacy (name noop)',
        ),
      ),
    ];
  }
}
