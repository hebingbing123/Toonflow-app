part of '../../home_page.dart';

extension _HomePageProjectEditorDialogBasics on _HomePageState {
  Widget _buildStylePackPickerField({
    required BuildContext ctx,
    required String label,
    required List<_StylePackOption> options,
    required String? selectedPath,
    required ValueChanged<String?> onChanged,
  }) {
    _StylePackOption? selected;
    for (final option in options) {
      if (option.path == selectedPath) {
        selected = option;
        break;
      }
    }
    final hasSelectedOutsideList =
        selectedPath != null && selected == null && selectedPath.isNotEmpty;
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('未选择')),
      ...options.map(
        (option) => DropdownMenuItem<String>(
          value: option.path,
          child: Text('${option.name} · ${option.tag}'),
        ),
      ),
      if (hasSelectedOutsideList)
        DropdownMenuItem<String>(
          value: selectedPath,
          child: Text('$selectedPath · 当前配置'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedPath ?? '',
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: items,
          onChanged: (value) =>
              onChanged((value == null || value.isEmpty) ? null : value),
        ),
        const SizedBox(height: 4),
        Text(
          selected?.description ??
              (hasSelectedOutsideList ? '当前项目已配置旧路径或未收录风格包。' : '未选择'),
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectEditorBasicsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required TextEditingController premiseCtrl,
    required TextEditingController audienceCtrl,
    required TextEditingController toneCtrl,
    required TextEditingController hookCtrl,
    required TextEditingController visualCtrl,
    required TextEditingController brandNameCtrl,
    required TextEditingController brandPromiseCtrl,
    required TextEditingController visualMotifsCtrl,
    required TextEditingController forbiddenCtrl,
    required TextEditingController continuityCtrl,
    required _ProjectEditorDialogState dialogState,
  }) {
    final home = dialogState.homeRef[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (home != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(ctx).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(
                ctx,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('项目首页', style: Theme.of(ctx).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  'Readiness ${home.readinessScore}/100 · ${home.readinessSummary}',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (home.onboarding.nextStep != null)
                  Text(
                    '下一步：${home.onboarding.nextStep}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                ...home.onboarding.checklist.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${item.done ? '✓' : '○'} ${item.label}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        const SizedBox(height: 16),
        Text('项目立项', style: Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: premiseCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Premise'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: audienceCtrl,
          decoration: const InputDecoration(labelText: 'Target audience'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: toneCtrl,
          decoration: const InputDecoration(labelText: 'Emotional tone'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: hookCtrl,
          decoration: const InputDecoration(labelText: 'Core hook'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: visualCtrl,
          decoration: const InputDecoration(labelText: 'Visual direction'),
        ),
        const SizedBox(height: 16),
        Text('品牌圣经', style: Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: brandNameCtrl,
          decoration: const InputDecoration(labelText: 'Brand name'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: brandPromiseCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Brand promise'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: visualMotifsCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Visual motifs (每行一个)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: forbiddenCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Forbidden elements (每行一个)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: continuityCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Continuity rules (每行一个)',
          ),
        ),
        const SizedBox(height: 12),
        _buildStylePackPickerField(
          ctx: ctx,
          label: '画风技能包',
          options: dialogState.artStylePackOptionsRef[0],
          selectedPath: dialogState.selectedArtStylePackRef[0],
          onChanged: (value) {
            setDialogState(
              () => dialogState.selectedArtStylePackRef[0] = value,
            );
          },
        ),
        const SizedBox(height: 12),
        _buildStylePackPickerField(
          ctx: ctx,
          label: '故事风格包',
          options: dialogState.storyStylePackOptionsRef[0],
          selectedPath: dialogState.selectedStoryStylePackRef[0],
          onChanged: (value) {
            setDialogState(
              () => dialogState.selectedStoryStylePackRef[0] = value,
            );
          },
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '旧 general / project / tasks 接口回归入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  ..._buildProjectGeneralProbeActions(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    token: token,
                    p: p,
                    detail: detail,
                    introCtrl: introCtrl,
                    generalProbeBusy: dialogState.generalProbeBusy,
                    tasksProbeBusy: dialogState.tasksProbeBusy,
                    projectProbeBusy: dialogState.projectProbeBusy,
                  ),
                  ..._buildProjectProjectProbeActions(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    token: token,
                    detail: detail,
                    generalProbeBusy: dialogState.generalProbeBusy,
                    tasksProbeBusy: dialogState.tasksProbeBusy,
                    projectProbeBusy: dialogState.projectProbeBusy,
                  ),
                  ..._buildProjectTasksProbeActions(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    token: token,
                    p: p,
                    generalProbeBusy: dialogState.generalProbeBusy,
                    tasksProbeBusy: dialogState.tasksProbeBusy,
                    projectProbeBusy: dialogState.projectProbeBusy,
                  ),
                ],
              ),
            ),
          ],
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
