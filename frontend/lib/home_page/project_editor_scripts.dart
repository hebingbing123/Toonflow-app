part of '../home_page.dart';

extension _HomePageProjectEditorScripts on _HomePageState {
  Widget _buildProjectScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${scriptList.length} script(s)'),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ..._buildProjectScriptsProbeActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              saving: saving,
              scriptProbeBusy: scriptProbeBusy,
              scriptList: scriptList,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving[0]
                ? null
                : () async {
                    setDialogState(() => saving[0] = true);
                    try {
                      final s = await createScriptUnderProjectLegacy(
                        token,
                        p.legacyId,
                      );
                      if (!ctx.mounted) return;
                      scriptList.add(
                        ScriptBrief(
                          legacyId: s.legacyId,
                          name: s.name,
                          extractState: s.extractState,
                        ),
                      );
                      try {
                        statsRef[0] = await fetchProjectStatsByLegacyId(
                          token,
                          p.legacyId,
                        );
                      } catch (_) {}
                      if (!ctx.mounted) return;
                      setDialogState(() => saving[0] = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('已创建剧本 legacy #${s.legacyId}')),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() => saving[0] = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() => saving[0] = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
            child: const Text('POST 空剧本'),
          ),
        ),
        const SizedBox(height: 8),
        ...scriptList.map(
          (s) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '#${s.legacyId} ${s.name ?? ""}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: saving[0]
                ? null
                : () => _openScriptEditor(
                    token,
                    s.legacyId,
                    onScriptTreeMutated: () async {
                      final d = await fetchProjectByLegacyId(token, p.legacyId);
                      if (!ctx.mounted) return;
                      scriptList
                        ..clear()
                        ..addAll(d.scripts);
                      try {
                        statsRef[0] = await fetchProjectStatsByLegacyId(
                          token,
                          p.legacyId,
                        );
                      } catch (_) {}
                      setDialogState(() {});
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
