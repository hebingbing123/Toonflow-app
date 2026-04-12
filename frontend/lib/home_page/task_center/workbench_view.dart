part of 'section.dart';

extension _TaskCenterWorkbenchDialogView on _TaskCenterWorkbenchDialogState {
  AlertDialog _buildTaskCenterWorkbenchDialogView({
    required BuildContext context,
    required String projectSummary,
    required String jobSummary,
    required TextEditingController pageCtrl,
    required TextEditingController limitCtrl,
    required TextEditingController stateCtrl,
    required TextEditingController taskClassCtrl,
    required TextEditingController projectIdCtrl,
    required TextEditingController numericTaskIdCtrl,
    required TextEditingController uuidCtrl,
    required List<TaskCenterTaskClassRow> categories,
    required List<JobRow> jobs,
    required String? categoriesSummary,
    required String? numericIdTaskDetailText,
    required String? uuidDetails,
    required String? statusLine,
    required bool loadingProjects,
    required bool loadingCategories,
    required bool loadingTasks,
    required bool loadingNumericIdTaskDetail,
    required bool loadingUuidDetails,
    required Future<void> Function() onLoadProjects,
    required Future<void> Function() onLoadCategories,
    required Future<void> Function() onLoadTasks,
    required Future<void> Function() onLoadNumericIdTaskDetail,
    required Future<void> Function() onLoadUuidDetails,
    required ValueChanged<String> onPickCategory,
    required ValueChanged<JobRow> onPickJob,
    required VoidCallback onClose,
  }) {
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('任务工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在一个对话框内完成任务项目/分类读取、按项目或分类筛选列表，以及按 numeric task id 或 UUID 查看详情。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Text('筛选与列表', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: loadingProjects ? null : onLoadProjects,
                    child: Text(loadingProjects ? '…' : '刷新任务项目'),
                  ),
                  FilledButton.tonal(
                    onPressed: loadingCategories ? null : onLoadCategories,
                    child: Text(loadingCategories ? '…' : '刷新任务分类'),
                  ),
                  FilledButton.tonal(
                    onPressed: loadingTasks ? null : onLoadTasks,
                    child: Text(loadingTasks ? '…' : '按筛选加载任务'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                projectSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (categoriesSummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  categoriesSummary,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                jobSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pageCtrl,
                      decoration: const InputDecoration(labelText: '页码'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: limitCtrl,
                      decoration: const InputDecoration(labelText: '每页数量'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: projectIdCtrl,
                      decoration: const InputDecoration(
                        labelText: '项目 numeric ID（可空）',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: taskClassCtrl,
                      decoration: const InputDecoration(labelText: '任务分类（可空）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stateCtrl,
                decoration: const InputDecoration(labelText: '任务状态（可空）'),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .take(6)
                      .map(
                        (row) => ActionChip(
                          label: Text(row.taskClass),
                          onPressed: () => onPickCategory(row.taskClass),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (jobs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${jobs.length} 条任务',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...jobs
                    .take(8)
                    .map(
                      (job) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${job.kind} · ${job.status}'),
                        subtitle: Text('#${job.numericTaskId} · ${job.id}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onPickJob(job),
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              Text('任务详情', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: numericTaskIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'numeric task id',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: loadingNumericIdTaskDetail
                        ? null
                        : onLoadNumericIdTaskDetail,
                    child: Text(
                      loadingNumericIdTaskDetail ? '…' : '读取任务详情（numeric ID）',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: uuidCtrl,
                      decoration: const InputDecoration(labelText: '任务 UUID'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: loadingUuidDetails ? null : onLoadUuidDetails,
                    child: Text(loadingUuidDetails ? '…' : '读取 UUID 详情'),
                  ),
                ],
              ),
              if (numericIdTaskDetailText != null) ...[
                const SizedBox(height: 8),
                SelectableText('任务详情（numeric ID）：$numericIdTaskDetailText'),
              ],
              if (uuidDetails != null) ...[
                const SizedBox(height: 8),
                SelectableText('UUID 详情：$uuidDetails'),
              ],
              if (statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  statusLine,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: onClose, child: const Text('关闭'))],
    );
  }
}
