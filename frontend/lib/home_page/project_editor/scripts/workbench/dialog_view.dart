import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../../../script_editor/support.dart';

class ProjectScriptsWorkbenchDialogViewModel {
  const ProjectScriptsWorkbenchDialogViewModel({
    required this.localBusy,
    required this.infoLine,
    required this.filterCtrl,
    required this.previewRows,
    required this.selectedIdsCtrl,
    required this.diagnosis,
    required this.recommendedActionLabel,
    required this.groupSizeCtrl,
    required this.addCountCtrl,
    required this.addPrefixCtrl,
    required this.addBodyCtrl,
    required this.scriptList,
    required this.scriptTaskLine,
  });

  final bool localBusy;
  final String infoLine;
  final TextEditingController filterCtrl;
  final List<ScriptWorkbenchDetailRow> previewRows;
  final TextEditingController selectedIdsCtrl;
  final ScriptBatchWorkbenchDiagnosis diagnosis;
  final String recommendedActionLabel;
  final TextEditingController groupSizeCtrl;
  final TextEditingController addCountCtrl;
  final TextEditingController addPrefixCtrl;
  final TextEditingController addBodyCtrl;
  final List<ScriptBrief> scriptList;
  final String? scriptTaskLine;
}

class ProjectScriptsWorkbenchDialogViewCallbacks {
  const ProjectScriptsWorkbenchDialogViewCallbacks({
    required this.onReadContext,
    required this.onUsePreviewOrAll,
    required this.onReloadScripts,
    required this.onRunRecommendedAction,
    required this.onExportSelected,
    required this.onPollSelected,
    required this.onExtractSelected,
    required this.onBatchCreate,
    required this.onClose,
  });

  final VoidCallback? onReadContext;
  final VoidCallback? onUsePreviewOrAll;
  final VoidCallback? onReloadScripts;
  final VoidCallback? onRunRecommendedAction;
  final VoidCallback? onExportSelected;
  final VoidCallback? onPollSelected;
  final VoidCallback? onExtractSelected;
  final VoidCallback? onBatchCreate;
  final VoidCallback? onClose;
}

class ProjectScriptsWorkbenchDialogView extends StatelessWidget {
  const ProjectScriptsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectScriptsWorkbenchDialogViewModel model;
  final ProjectScriptsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('剧本批量工作台'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.infoLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.filterCtrl,
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
                    onPressed: model.localBusy ? null : callbacks.onReadContext,
                    child: const Text('读取剧本上下文'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onUsePreviewOrAll,
                    child: Text(
                      model.previewRows.isNotEmpty ? '使用当前预览' : '使用全部剧本',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onReloadScripts,
                    child: const Text('刷新项目剧本'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: model.selectedIdsCtrl,
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
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.diagnosis.summary,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.diagnosis.detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: const Key(
                        'project-scripts-workbench-recommended-action',
                      ),
                      onPressed: model.localBusy
                          ? null
                          : callbacks.onRunRecommendedAction,
                      child: Text(model.recommendedActionLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.groupSizeCtrl,
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
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onExportSelected,
                    child: const Text('导出所选剧本'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onPollSelected,
                    child: const Text('轮询所选状态'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onExtractSelected,
                    child: const Text('提取所选素材'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('批量新增剧本', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: model.addCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量（1-20）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.addPrefixCtrl,
                decoration: const InputDecoration(labelText: '名称前缀'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.addBodyCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '剧本默认内容'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.localBusy ? null : callbacks.onBatchCreate,
                child: const Text('批量创建'),
              ),
              const SizedBox(height: 16),
              Text('上下文预览', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (model.previewRows.isEmpty)
                Text(
                  model.scriptList.isEmpty
                      ? '暂无可预览剧本。'
                      : model.scriptList
                            .take(6)
                            .map(
                              (script) =>
                                  '#${script.numericId} ${script.name ?? ''} · 提取状态 ${script.extractState ?? 0}',
                            )
                            .join('\n'),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...model.previewRows
                    .take(6)
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '#${row.numericId} ${row.name ?? ''} · 提取状态 ${row.extractState ?? 0} · 素材 ${summarizeRelatedScriptAssets(row.relatedAssets)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
              if ((model.scriptTaskLine ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  model.scriptTaskLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.localBusy ? null : callbacks.onClose,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
