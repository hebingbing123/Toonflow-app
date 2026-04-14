import 'package:flutter/material.dart';

import '../../../rust_api.dart';

class ScriptEditImageWorkbenchDialogViewModel {
  const ScriptEditImageWorkbenchDialogViewModel({
    required this.loading,
    required this.busy,
    required this.steps,
    required this.defaultModel,
    required this.uploadedImageUrl,
    required this.statusLine,
    required this.uploadCtrl,
    required this.flowIdCtrl,
    required this.promptCtrl,
    required this.modelCtrl,
    required this.stepIdCtrl,
    required this.stepStatusCtrl,
  });

  final bool loading;
  final bool busy;
  final List<ImageFlowStepV1> steps;
  final ImageDefaultModelResponseV1? defaultModel;
  final String? uploadedImageUrl;
  final String? statusLine;
  final TextEditingController uploadCtrl;
  final TextEditingController flowIdCtrl;
  final TextEditingController promptCtrl;
  final TextEditingController modelCtrl;
  final TextEditingController stepIdCtrl;
  final TextEditingController stepStatusCtrl;
}

class ScriptEditImageWorkbenchDialogViewCallbacks {
  const ScriptEditImageWorkbenchDialogViewCallbacks({
    required this.onRefresh,
    required this.onUploadSourceImage,
    required this.onGenerateFlowImage,
    required this.onSaveFlow,
    required this.onSelectStep,
    required this.onUpdateStepStatus,
    required this.onClose,
  });

  final Future<void> Function() onRefresh;
  final Future<void> Function() onUploadSourceImage;
  final Future<void> Function() onGenerateFlowImage;
  final Future<void> Function() onSaveFlow;
  final ValueChanged<ImageFlowStepV1> onSelectStep;
  final Future<void> Function() onUpdateStepStatus;
  final VoidCallback onClose;
}

/// 编辑图片工作台视图，承载 flow 同步、源图上传、出图与步骤状态编辑。
class ScriptEditImageWorkbenchDialogView extends StatelessWidget {
  const ScriptEditImageWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ScriptEditImageWorkbenchDialogViewModel model;
  final ScriptEditImageWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return AlertDialog(
      title: const Text('编辑图片工作台'),
      content: SizedBox(
        width: 780,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '直接在脚本工作台内管理 edit-image flow、上传源图并发起生成，不再只停留在 production probe。',
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loading || model.busy
                        ? null
                        : callbacks.onRefresh,
                    child: Text(model.loading ? '同步中…' : '重新同步 Flow'),
                  ),
                  if (model.defaultModel != null)
                    Text(
                      '默认模型 ${model.defaultModel!.model} · ${model.defaultModel!.resolution}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.uploadCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '源图 base64 / data URI',
                  helperText:
                      '粘贴 data:image/png;base64,... 或原始 base64；用于 upload-image。',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    onPressed: model.busy
                        ? null
                        : callbacks.onUploadSourceImage,
                    child: Text(model.busy ? '处理中…' : '上传源图'),
                  ),
                ],
              ),
              if (model.uploadedImageUrl != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  model.uploadedImageUrl!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.flowIdCtrl,
                      decoration: const InputDecoration(labelText: 'Flow ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.modelCtrl,
                      decoration: const InputDecoration(labelText: '生成模型（可选）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.promptCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '生成提示词',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: model.busy
                        ? null
                        : callbacks.onGenerateFlowImage,
                    child: const Text('发起流程出图'),
                  ),
                  TextButton(
                    onPressed: model.busy ? null : callbacks.onSaveFlow,
                    child: const Text('保存当前 Flow'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('步骤状态', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (model.steps.isEmpty)
                Text('暂无步骤，先点击“重新同步 Flow”。', style: theme.textTheme.bodySmall)
              else
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: model.steps.length,
                    itemBuilder: (context, index) {
                      final step = model.steps[index];
                      final selected =
                          step.stepId == model.stepIdCtrl.text.trim();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        selected: selected,
                        title: Text(step.stepName),
                        subtitle: Text('${step.stepId} · ${step.status}'),
                        onTap: model.busy
                            ? null
                            : () => callbacks.onSelectStep(step),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.stepIdCtrl,
                      decoration: const InputDecoration(labelText: 'Step ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.stepStatusCtrl,
                      decoration: const InputDecoration(
                        labelText: '新状态',
                        helperText: '例如 pending / completed / failed',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: model.busy ? null : callbacks.onUpdateStepStatus,
                child: const Text('更新单个步骤状态'),
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 8),
                Text(model.statusLine!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.busy ? null : callbacks.onClose,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
