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
    final l10n = AppLocalizations.of(ctx)!;
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
                      ? l10n.projectEditorProbeGeneralGetSingleZeroRows
                      : rows.map((r) => '#${r.numericId} ${r.name ?? ""}').join('; ');
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeGeneralGetSingleSnack(line),
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
          generalProbeBusy[0]
              ? l10n.projectEditorProbeGeneralBusyLabel
              : l10n.projectEditorProbeGeneralButtonGetSingleProject,
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
                  await postGeneralUpdateProject(
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
                  await postGeneralUpdateProject(
                    token,
                    restoreBody,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorProbeGeneralUpdateProjectSnack,
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
          generalProbeBusy[0]
              ? l10n.projectEditorProbeGeneralBusyLabel
              : l10n.projectEditorProbeGeneralButtonUpdateProject,
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
                        l10n.projectEditorProbeGeneralPatchNameNoopSnack(
                          updated.name ?? '(null)',
                        ),
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
          generalProbeBusy[0]
              ? l10n.projectEditorProbeGeneralBusyLabel
              : l10n.projectEditorProbeGeneralButtonPatchProjectNameNoop,
        ),
      ),
    ];
  }
}
