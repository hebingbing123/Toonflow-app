import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import '../../script_editor/support.dart';

class ProjectScriptsSectionViewModel {
  const ProjectScriptsSectionViewModel({
    required this.saving,
    required this.scriptTaskBusy,
    required this.scriptTaskLine,
    required this.scriptList,
    required this.overviewDiagnosis,
    required this.overviewActionLabel,
    required this.overviewAction,
    required this.probeActions,
  });

  final bool saving;
  final bool scriptTaskBusy;
  final String? scriptTaskLine;
  final List<ScriptBrief> scriptList;
  final ScriptBatchWorkbenchDiagnosis overviewDiagnosis;
  final String overviewActionLabel;
  final VoidCallback? overviewAction;
  final List<Widget> probeActions;
}

class ProjectScriptsSectionViewCallbacks {
  const ProjectScriptsSectionViewCallbacks({
    required this.onOpenWorkbench,
    required this.onOpenPlanWorkbench,
    required this.onOpenBatchAddDialog,
    required this.onExportAll,
    required this.onPollAll,
    required this.onExtractAll,
    required this.onCreateEmptyScript,
    required this.onOpenScriptEditor,
  });

  final VoidCallback? onOpenWorkbench;
  final VoidCallback? onOpenPlanWorkbench;
  final VoidCallback? onOpenBatchAddDialog;
  final VoidCallback? onExportAll;
  final VoidCallback? onPollAll;
  final VoidCallback? onExtractAll;
  final VoidCallback? onCreateEmptyScript;
  final void Function(ScriptBrief script)? onOpenScriptEditor;
}

/// 项目剧本区块视图，承载批量工作台入口、建议卡与剧本列表。
class ProjectScriptsSectionView extends StatelessWidget {
  const ProjectScriptsSectionView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectScriptsSectionViewModel model;
  final ProjectScriptsSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${model.scriptList.length} 条剧本',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '在项目下管理剧本，并进入剧本详情维护内容与分镜。',
          style: theme.textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('剧本批量工作台', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '把项目级剧本上下文读取、批量导出、提取状态轮询、素材抽取和批量创建收口到同一工作台，不再只靠全量快捷按钮。',
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.saving || model.scriptTaskBusy
                        ? null
                        : callbacks.onOpenWorkbench,
                    child: const Text('打开剧本批量工作台'),
                  ),
                  OutlinedButton(
                    onPressed: model.saving || model.scriptTaskBusy
                        ? null
                        : callbacks.onOpenPlanWorkbench,
                    child: const Text('打开骨架工作台'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.28,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前批量建议', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                model.overviewDiagnosis.summary,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                model.overviewDiagnosis.detail,
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.overviewAction,
                child: Text(model.overviewActionLabel),
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
              onPressed: model.saving ? null : callbacks.onOpenBatchAddDialog,
              child: const Text('批量新增剧本'),
            ),
            TextButton(
              onPressed:
                  model.saving ||
                      model.scriptTaskBusy ||
                      model.scriptList.isEmpty
                  ? null
                  : callbacks.onExportAll,
              child: Text(model.scriptTaskBusy ? '处理中…' : '导出全部剧本'),
            ),
            TextButton(
              onPressed:
                  model.saving ||
                      model.scriptTaskBusy ||
                      model.scriptList.isEmpty
                  ? null
                  : callbacks.onPollAll,
              child: const Text('轮询全部提取状态'),
            ),
            TextButton(
              onPressed:
                  model.saving ||
                      model.scriptTaskBusy ||
                      model.scriptList.isEmpty
                  ? null
                  : callbacks.onExtractAll,
              child: const Text('提取全部剧本素材'),
            ),
          ],
        ),
        if (model.scriptTaskLine != null) ...[
          const SizedBox(height: 4),
          Text(
            model.scriptTaskLine!,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: model.saving ? null : callbacks.onCreateEmptyScript,
            child: const Text('新建空剧本'),
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留旧剧本接口与导出/提取回归入口，默认折叠',
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: model.probeActions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...model.scriptList.map(
          (script) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '#${script.numericId} ${script.name ?? ""}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: model.saving || callbacks.onOpenScriptEditor == null
                ? null
                : () => callbacks.onOpenScriptEditor!(script),
          ),
        ),
      ],
    );
  }
}
