part of '../../../home_page.dart';

extension _HomePageScriptEditorEditImageWorkbenchView on _HomePageState {
  AlertDialog _buildScriptEditImageWorkbenchDialog({
    required BuildContext dialogCtx,
    required bool loading,
    required bool busy,
    required List<ImageFlowStepV1> steps,
    required ImageDefaultModelResponseV1? defaultModel,
    required String? uploadedImageUrl,
    required String? statusLine,
    required TextEditingController uploadCtrl,
    required TextEditingController flowIdCtrl,
    required TextEditingController promptCtrl,
    required TextEditingController modelCtrl,
    required TextEditingController stepIdCtrl,
    required TextEditingController stepStatusCtrl,
    required Future<void> Function() onRefresh,
    required Future<void> Function() onUploadSourceImage,
    required Future<void> Function() onGenerateFlowImage,
    required Future<void> Function() onSaveFlow,
    required ValueChanged<ImageFlowStepV1> onSelectStep,
    required Future<void> Function() onUpdateStepStatus,
    required VoidCallback onClose,
  }) {
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
                style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogCtx).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: loading || busy ? null : onRefresh,
                    child: Text(loading ? '同步中…' : '重新同步 Flow'),
                  ),
                  if (defaultModel != null)
                    Text(
                      '默认模型 ${defaultModel.model} · ${defaultModel.resolution}',
                      style: Theme.of(dialogCtx).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: uploadCtrl,
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
                children: [
                  FilledButton(
                    onPressed: busy ? null : onUploadSourceImage,
                    child: Text(busy ? '处理中…' : '上传源图'),
                  ),
                  if (uploadedImageUrl != null)
                    Expanded(
                      child: SelectableText(
                        uploadedImageUrl,
                        style: Theme.of(dialogCtx).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: flowIdCtrl,
                      decoration: const InputDecoration(labelText: 'Flow ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: modelCtrl,
                      decoration: const InputDecoration(labelText: '生成模型（可选）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: promptCtrl,
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
                    onPressed: busy ? null : onGenerateFlowImage,
                    child: const Text('发起流程出图'),
                  ),
                  TextButton(
                    onPressed: busy ? null : onSaveFlow,
                    child: const Text('保存当前 Flow'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('步骤状态', style: Theme.of(dialogCtx).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (steps.isEmpty)
                Text(
                  '暂无步骤，先点击“加载 flow 模板”。',
                  style: Theme.of(dialogCtx).textTheme.bodySmall,
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: steps.length,
                    itemBuilder: (context, index) {
                      final step = steps[index];
                      final selected = step.stepId == stepIdCtrl.text.trim();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        selected: selected,
                        title: Text(step.stepName),
                        subtitle: Text('${step.stepId} · ${step.status}'),
                        onTap: busy ? null : () => onSelectStep(step),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: stepIdCtrl,
                      decoration: const InputDecoration(labelText: 'Step ID'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stepStatusCtrl,
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
                onPressed: busy ? null : onUpdateStepStatus,
                child: const Text('更新单个步骤状态'),
              ),
              if (statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  statusLine,
                  style: Theme.of(dialogCtx).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: busy ? null : onClose, child: const Text('关闭')),
      ],
    );
  }
}
