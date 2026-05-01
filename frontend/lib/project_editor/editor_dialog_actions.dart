part of '../../home_page.dart';

extension _HomePageProjectEditorDialogActions on _HomePageState {
  List<Widget> _buildProjectEditorDialogActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required _ProjectEditorDialogState dialogState,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
  }) {
    return [
      TextButton(
        onPressed: dialogState.saving[0] ? null : () => Navigator.of(ctx).pop(),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('删除项目？'),
                    content: Text(
                      '将删除项目 #${p.numericId} 及关联剧本/分镜（数据库级联），且清除该项目的 agent 记忆。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(c).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (ok != true || !ctx.mounted) return;
                setDialogState(() => dialogState.saving[0] = true);
                try {
                  await deleteProjectByProjectId(token, p.id);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _projectsController.loadProjects();
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('项目已删除')));
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
        child: const Text('DELETE'),
      ),
      FilledButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                setDialogState(() => dialogState.saving[0] = true);
                try {
                  final currentProject = dialogState;
                  final selectedArtStylePack =
                      currentProject.selectedArtStylePackRef[0];
                  final selectedStoryStylePack =
                      currentProject.selectedStoryStylePackRef[0];
                  await updateProjectByProjectId(token, p.id, {
                    'name': nameCtrl.text.isEmpty ? null : nameCtrl.text,
                    'intro': introCtrl.text.isEmpty ? null : introCtrl.text,
                  });
                  if (selectedArtStylePack != p.artStylePack ||
                      selectedStoryStylePack != p.storyStylePack) {
                    await patchProjectStyleConfigByProjectId(
                      token,
                      p.id,
                      artStylePack: selectedArtStylePack,
                      storyStylePack: selectedStoryStylePack,
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _projectsController.loadProjects();
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
        child: Text(dialogState.saving[0] ? '保存中…' : 'PATCH 保存'),
      ),
    ];
  }
}
