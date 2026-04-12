part of '../../../../../home_page.dart';

extension _HomePageProjectEditorScriptsWorkbenchDialogView on _HomePageState {
  AlertDialog _buildProjectScriptsWorkbenchDialogView({
    required BuildContext dialogCtx,
    required bool localBusy,
    required String infoLine,
    required TextEditingController filterCtrl,
    required List<ScriptWorkbenchDetailRow> previewRows,
    required TextEditingController selectedIdsCtrl,
    required ScriptBatchWorkbenchDiagnosis diagnosis,
    required Future<void> Function()? recommendedAction,
    required String recommendedActionLabel,
    required TextEditingController groupSizeCtrl,
    required TextEditingController addCountCtrl,
    required TextEditingController addPrefixCtrl,
    required TextEditingController addBodyCtrl,
    required List<ScriptBrief> scriptList,
    required String? scriptTaskLine,
    required VoidCallback onReadContext,
    required VoidCallback onUsePreviewOrAll,
    required VoidCallback onReloadScripts,
    required VoidCallback? onRunRecommendedAction,
    required VoidCallback onExportSelected,
    required VoidCallback onPollSelected,
    required VoidCallback onExtractSelected,
    required VoidCallback onBatchCreate,
    required VoidCallback onClose,
  }) {
    return AlertDialog(
      title: const Text('剧本批量工作台'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(infoLine, style: Theme.of(dialogCtx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: filterCtrl,
                decoration: const InputDecoration(
                  labelText: '剧本名称筛选',
                  helperText:
                      '读取 POST …/projects/{id}/scripts/get-script-api 时按名称过滤，可留空读取全量上下文。',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: localBusy ? null : onReadContext,
                    child: const Text('读取剧本上下文'),
                  ),
                  OutlinedButton(
                    onPressed: localBusy ? null : onUsePreviewOrAll,
                    child: Text(previewRows.isNotEmpty ? '使用当前预览' : '使用全部剧本'),
                  ),
                  OutlinedButton(
                    onPressed: localBusy ? null : onReloadScripts,
                    child: const Text('刷新项目剧本'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: selectedIdsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '目标剧本 numeric ID',
                  helperText: '支持逗号、空格或换行分隔；批量导出、轮询和素材抽取都使用这里的列表。',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogCtx,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diagnosis.summary,
                      style: Theme.of(dialogCtx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diagnosis.detail,
                      style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(dialogCtx).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: localBusy || recommendedAction == null
                          ? null
                          : onRunRecommendedAction,
                      child: Text(recommendedActionLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: groupSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '素材抽取 group size',
                  helperText: '留空则沿用后端默认分组；设置后用于 extract-assets。',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: localBusy ? null : onExportSelected,
                    child: const Text('导出所选剧本'),
                  ),
                  OutlinedButton(
                    onPressed: localBusy ? null : onPollSelected,
                    child: const Text('轮询所选状态'),
                  ),
                  OutlinedButton(
                    onPressed: localBusy ? null : onExtractSelected,
                    child: const Text('提取所选素材'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('批量新增剧本', style: Theme.of(dialogCtx).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: addCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量（1-20）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addPrefixCtrl,
                decoration: const InputDecoration(labelText: '名称前缀'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addBodyCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '剧本默认内容'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: localBusy ? null : onBatchCreate,
                child: const Text('批量创建'),
              ),
              const SizedBox(height: 16),
              Text('上下文预览', style: Theme.of(dialogCtx).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (previewRows.isEmpty)
                Text(
                  scriptList.isEmpty
                      ? '暂无可预览剧本。'
                      : scriptList
                            .take(6)
                            .map(
                              (script) =>
                                  '#${script.numericId} ${script.name ?? ''} · 提取状态 ${script.extractState ?? 0}',
                            )
                            .join('\n'),
                  style: Theme.of(dialogCtx).textTheme.bodySmall,
                )
              else
                ...previewRows
                    .take(6)
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '#${row.numericId} ${row.name ?? ''} · 提取状态 ${row.extractState ?? 0} · 素材 ${summarizeRelatedScriptAssets(row.relatedAssets)}',
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                      ),
                    ),
              if ((scriptTaskLine ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  scriptTaskLine!,
                  style: Theme.of(dialogCtx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: localBusy ? null : onClose,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
