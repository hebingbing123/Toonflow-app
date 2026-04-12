part of '../../../../home_page.dart';

extension _HomePageProjectEditorScriptsSectionView on _HomePageState {
  Widget _buildProjectScriptsSectionView({
    required BuildContext ctx,
    required Color outline,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<bool> scriptTaskBusy,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
    required ScriptBatchWorkbenchDiagnosis overviewDiagnosis,
    required VoidCallback? overviewAction,
    required String overviewActionLabel,
    required VoidCallback onOpenWorkbench,
    required VoidCallback onOpenBatchAddDialog,
    required Future<void> Function() onExportAll,
    required Future<void> Function() onPollAll,
    required Future<void> Function() onExtractAll,
    required Future<void> Function() onCreateEmptyScript,
    required List<Widget> Function() buildProbeActions,
    required void Function(ScriptBrief script) onOpenScriptEditor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${scriptList.length} 条剧本',
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '在项目下管理剧本，并进入剧本详情维护内容与分镜。',
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(
              ctx,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('剧本批量工作台', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '把项目级剧本上下文读取、批量导出、提取状态轮询、素材抽取和批量创建收口到同一工作台，不再只靠全量快捷按钮。',
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: saving[0] || scriptTaskBusy[0]
                    ? null
                    : onOpenWorkbench,
                child: const Text('打开剧本批量工作台'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(
              ctx,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前批量建议', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                overviewDiagnosis.summary,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                overviewDiagnosis.detail,
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: overviewAction,
                child: Text(overviewActionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: saving[0] ? null : onOpenBatchAddDialog,
              child: const Text('批量新增剧本'),
            ),
            TextButton(
              onPressed: saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
                  ? null
                  : onExportAll,
              child: Text(scriptTaskBusy[0] ? '处理中…' : '导出全部剧本'),
            ),
            TextButton(
              onPressed: saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
                  ? null
                  : onPollAll,
              child: const Text('轮询全部提取状态'),
            ),
            TextButton(
              onPressed: saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
                  ? null
                  : onExtractAll,
              child: const Text('提取全部剧本素材'),
            ),
          ],
        ),
        if (scriptTaskLine[0] != null) ...[
          const SizedBox(height: 4),
          Text(
            scriptTaskLine[0]!,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving[0] ? null : onCreateEmptyScript,
            child: const Text('新建空剧本'),
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留旧剧本接口与导出/提取回归入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [...buildProbeActions()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...scriptList.map(
          (s) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '#${s.numericId} ${s.name ?? ""}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: saving[0] ? null : () => onOpenScriptEditor(s),
          ),
        ),
      ],
    );
  }
}
