part of '../../../home_page.dart';

extension _HomePageProjectEditorHttpProjectProbe on _HomePageState {
  List<Widget> _buildProjectProjectProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectDetail detail,
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
                setDialogState(() => projectProbeBusy[0] = true);
                try {
                  final rows = await postProjectGetProject(token);
                  if (!ctx.mounted) return;
                  final line = rows.isEmpty
                      ? '0 项'
                      : rows.map((r) => '#${r.numericId} ${r.name ?? ""}').join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('GET …/projects（compat 列表）：$line')),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => projectProbeBusy[0] = false);
                  }
                }
              },
        child: Text(
          projectProbeBusy[0] ? 'project…' : 'POST project get-project',
        ),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => projectProbeBusy[0] = true);
                final pr = detail.project;
                try {
                  final msg = await postProjectEditProject(
                    token,
                    id: pr.numericId,
                    projectUuid: pr.id,
                    name: pr.name ?? '',
                    intro: pr.intro ?? '',
                    type: pr.mode ?? '',
                    artStyle: pr.artStyle ?? '',
                    directorManual: pr.directorManual ?? '',
                    videoRatio: pr.videoRatio ?? '',
                    imageModel: pr.imageModel ?? '',
                    videoModel: pr.videoModel ?? '',
                    imageQuality: pr.imageQuality ?? '',
                    projectType: pr.projectType ?? '',
                    mode: pr.mode ?? '',
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/project/edit-project noop #${pr.numericId}：$msg',
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
                    setDialogState(() => projectProbeBusy[0] = false);
                  }
                }
              },
        child: Text(projectProbeBusy[0] ? 'project…' : 'POST project edit (noop)'),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => projectProbeBusy[0] = true);
                try {
                  await postProjectDeleteProject(token, 0);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('POST …/project/delete-project：unexpected 200'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (!ctx.mounted) return;
                  if (e.statusCode == 400) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'POST …/project/delete-project id=0 -> 400 (expected)',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => projectProbeBusy[0] = false);
                  }
                }
              },
        child: Text(projectProbeBusy[0] ? 'project…' : 'POST project delete id=0'),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => projectProbeBusy[0] = true);
                try {
                  await postProjectEditProject(
                    token,
                    id: 0,
                    name: '',
                    intro: '',
                    type: '',
                    artStyle: '',
                    directorManual: '',
                    videoRatio: '',
                    imageModel: '',
                    videoModel: '',
                    imageQuality: '',
                    projectType: '',
                    mode: '',
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('POST …/project/edit-project：unexpected 200'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (!ctx.mounted) return;
                  if (e.statusCode == 400) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'POST …/project/edit-project id=0 -> 400 (expected)',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => projectProbeBusy[0] = false);
                  }
                }
              },
        child: Text(projectProbeBusy[0] ? 'project…' : 'POST project edit id=0'),
      ),
      TextButton(
        onPressed:
            generalProbeBusy[0] ||
                tasksProbeBusy[0] ||
                projectProbeBusy[0]
            ? null
            : () async {
                setDialogState(() => projectProbeBusy[0] = true);
                final probeName =
                    '[flutter workbench add-probe] ${DateTime.now().toIso8601String()}';
                try {
                  await postProjectAddProject(
                    token,
                    projectType: '',
                    name: probeName,
                    intro: '',
                    type: '',
                    artStyle: '',
                    directorManual: '',
                    videoRatio: '',
                    imageModel: '',
                    videoModel: '',
                    imageQuality: '',
                    mode: '',
                  );
                  final all = await postProjectGetProject(token);
                  if (!ctx.mounted) return;
                  ProjectRow? match;
                  for (final r in all) {
                    if (r.name == probeName) {
                      match = r;
                      break;
                    }
                  }
                  if (match == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'add-project ok but get-project missing name="$probeName"',
                        ),
                      ),
                    );
                    return;
                  }
                  await postProjectDeleteProject(
                    token,
                    match.numericId,
                    projectUuid: match.id,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST add-project → delete project#${match.numericId} ok',
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
                    setDialogState(() => projectProbeBusy[0] = false);
                  }
                }
              },
        child: Text(projectProbeBusy[0] ? 'project…' : 'POST project add→del'),
      ),
    ];
  }
}
