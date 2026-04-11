part of '../../../home_page.dart';

extension _HomePageProjectEditorDialogBasics on _HomePageState {
  Widget _buildProjectEditorBasicsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required _ProjectEditorDialogState dialogState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name (empty = clear)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: introCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Intro (empty = clear)'),
        ),
        const SizedBox(height: 8),
        _buildProjectHttpProbeActions(
          ctx: ctx,
          setDialogState: setDialogState,
          token: token,
          p: p,
          detail: detail,
          introCtrl: introCtrl,
          generalLegacyBusy: dialogState.generalLegacyBusy,
          tasksLegacyBusy: dialogState.tasksLegacyBusy,
          projectLegacyBusy: dialogState.projectLegacyBusy,
        ),
        const SizedBox(height: 12),
        if (dialogState.statsRef[0] != null)
          Text(
            'GET …/stats：剧本 ${dialogState.statsRef[0]!.scriptCount} · 分镜 '
            '${dialogState.statsRef[0]!.storyboardCount} · 小说 ${dialogState.statsRef[0]!.novelCount} · 角色/视频 '
            '${dialogState.statsRef[0]!.roleCount}/${dialogState.statsRef[0]!.videoCount}（视频占位）',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            'GET …/stats 未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
      ],
    );
  }
}
