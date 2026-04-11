part of '../../../home_page.dart';

extension _HomePageProjectEditorLegacyProjectProbe on _HomePageState {
  List<Widget> _buildProjectLegacyProjectProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectDetail detail,
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
                setDialogState(() => projectLegacyBusy[0] = true);
                try {
                  final rows = await postProjectGetProject(token);
                  if (!ctx.mounted) return;
                  final line = rows.isEmpty
                      ? '0 项'
                      : rows.map((r) => '#${r.legacyId} ${r.name ?? ""}').join('; ');
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
                    setDialogState(() => projectLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(
          projectLegacyBusy[0] ? 'project…' : 'POST project get-project',
        ),
      ),
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => projectLegacyBusy[0] = true);
                final pr = detail.project;
                try {
                  final msg = await postProjectEditProject(
                    token,
                    id: pr.legacyId,
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
                        'POST …/project/edit-project noop #${pr.legacyId}：$msg',
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
                    setDialogState(() => projectLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(projectLegacyBusy[0] ? 'project…' : 'POST project edit (noop)'),
      ),
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => projectLegacyBusy[0] = true);
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
                    setDialogState(() => projectLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(projectLegacyBusy[0] ? 'project…' : 'POST project delete id=0'),
      ),
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => projectLegacyBusy[0] = true);
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
                    setDialogState(() => projectLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(projectLegacyBusy[0] ? 'project…' : 'POST project edit id=0'),
      ),
      TextButton(
        onPressed:
            generalLegacyBusy[0] ||
                tasksLegacyBusy[0] ||
                projectLegacyBusy[0]
            ? null
            : () async {
                setDialogState(() => projectLegacyBusy[0] = true);
                final probeName =
                    '[flutter legacy add-probe] ${DateTime.now().toIso8601String()}';
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
                  await postProjectDeleteProject(token, match.legacyId);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST add-project → delete legacy#${match.legacyId} ok',
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
                    setDialogState(() => projectLegacyBusy[0] = false);
                  }
                }
              },
        child: Text(projectLegacyBusy[0] ? 'project…' : 'POST project add→del'),
      ),
    ];
  }
}
