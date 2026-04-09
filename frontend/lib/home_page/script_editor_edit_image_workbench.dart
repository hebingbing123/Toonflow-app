part of '../home_page.dart';

extension _HomePageScriptEditorEditImageWorkbench on _HomePageState {
  Future<void> _openScriptEditImageWorkbenchDialog({
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
  }) async {
    final uploadCtrl = TextEditingController();
    final flowIdCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final stepIdCtrl = TextEditingController();
    final stepStatusCtrl = TextEditingController();

    List<ImageFlowStepV1> steps = const [];
    ImageDefaultModelResponseV1? defaultModel;
    String? uploadedImageUrl;
    String? statusLine;
    bool loading = false;
    bool busy = false;

    Future<void> refresh(StateSetter setState) async {
      setState(() {
        loading = true;
        statusLine = null;
      });
      try {
        final results = await Future.wait<Object>([
          postProductionEditImageGetImageFlowV1(token),
          postProductionEditImageGetImageDefaultModelV1(token),
        ]);
        final flow = results[0] as ImageFlowResponseV1;
        final model = results[1] as ImageDefaultModelResponseV1;
        setState(() {
          steps = flow.steps;
          defaultModel = model;
          flowIdCtrl.text = flow.flowId;
          if (modelCtrl.text.trim().isEmpty) {
            modelCtrl.text = flow.defaultModel;
          }
          if (stepIdCtrl.text.trim().isEmpty && flow.steps.isNotEmpty) {
            stepIdCtrl.text = flow.steps.first.stepId;
            stepStatusCtrl.text = flow.steps.first.status;
          }
          statusLine =
              '已加载 flow ${flow.flowId}，步骤 ${flow.steps.length}，默认模型 ${model.model}';
        });
      } on RustApiException catch (e) {
        setState(() => statusLine = '读取编辑图片工作台失败：$e');
      } catch (e) {
        setState(() => statusLine = '读取编辑图片工作台失败：$e');
      } finally {
        setState(() => loading = false);
      }
    }

    Future<void> runMutation(
      StateSetter setState,
      Future<void> Function() action,
    ) async {
      setState(() => busy = true);
      try {
        await action();
      } on RustApiException catch (e) {
        setState(() => statusLine = '$e');
      } catch (e) {
        setState(() => statusLine = '$e');
      } finally {
        setState(() => busy = false);
      }
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
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
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: loading || busy
                                  ? null
                                  : () => refresh(setState),
                              child: Text(loading ? '加载中…' : '加载 flow 模板'),
                            ),
                            if (defaultModel != null)
                              Text(
                                '默认模型 ${defaultModel!.model} · ${defaultModel!.resolution}',
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
                              onPressed: busy
                                  ? null
                                  : () => runMutation(setState, () async {
                                      final base64Data = uploadCtrl.text.trim();
                                      if (base64Data.isEmpty) {
                                        throw const FormatException(
                                          '请先粘贴源图 base64 或 data URI',
                                        );
                                      }
                                      final response =
                                          await postProductionEditImageUploadImageV1(
                                            token,
                                            projectId: projectLegacyId,
                                            scriptId: scriptLegacyId,
                                            base64Data: base64Data,
                                          );
                                      setState(() {
                                        uploadedImageUrl = response.url;
                                        statusLine = '源图已上传，URL 已返回，可继续生成流程图片';
                                      });
                                    }),
                              child: Text(busy ? '处理中…' : '上传源图'),
                            ),
                            if (uploadedImageUrl != null)
                              Expanded(
                                child: SelectableText(
                                  uploadedImageUrl!,
                                  style: Theme.of(
                                    dialogCtx,
                                  ).textTheme.bodySmall,
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
                                decoration: const InputDecoration(
                                  labelText: 'Flow ID',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: modelCtrl,
                                decoration: const InputDecoration(
                                  labelText: '生成模型（可选）',
                                ),
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
                              onPressed: busy
                                  ? null
                                  : () => runMutation(setState, () async {
                                      final flowId = flowIdCtrl.text.trim();
                                      final prompt = promptCtrl.text.trim();
                                      if (flowId.isEmpty || prompt.isEmpty) {
                                        throw const FormatException(
                                          'Flow ID 和生成提示词都不能为空',
                                        );
                                      }
                                      final response =
                                          await postProductionEditImageGenerateFlowImageV1(
                                            token,
                                            flowId: flowId,
                                            prompt: prompt,
                                            model: modelCtrl.text.trim().isEmpty
                                                ? null
                                                : modelCtrl.text.trim(),
                                          );
                                      setState(() {
                                        statusLine =
                                            '生成任务已入队：${response.jobId} · ${response.status}';
                                      });
                                    }),
                              child: const Text('发起流程出图'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => runMutation(setState, () async {
                                      final flowId = flowIdCtrl.text.trim();
                                      if (flowId.isEmpty) {
                                        throw const FormatException(
                                          'Flow ID 不能为空',
                                        );
                                      }
                                      final response =
                                          await postProductionEditImageSaveImageFlowV1(
                                            token,
                                            flowId: flowId,
                                            steps: steps
                                                .map((step) => step.toJson())
                                                .toList(growable: false),
                                          );
                                      setState(() {
                                        statusLine =
                                            'Flow ${response.flowId} 已保存';
                                      });
                                    }),
                              child: const Text('保存当前 Flow'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '步骤状态',
                          style: Theme.of(dialogCtx).textTheme.titleSmall,
                        ),
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
                                final selected =
                                    step.stepId == stepIdCtrl.text.trim();
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  selected: selected,
                                  title: Text(step.stepName),
                                  subtitle: Text(
                                    '${step.stepId} · ${step.status}',
                                  ),
                                  onTap: busy
                                      ? null
                                      : () {
                                          setState(() {
                                            stepIdCtrl.text = step.stepId;
                                            stepStatusCtrl.text = step.status;
                                          });
                                        },
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
                                decoration: const InputDecoration(
                                  labelText: 'Step ID',
                                ),
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
                          onPressed: busy
                              ? null
                              : () => runMutation(setState, () async {
                                  final flowId = flowIdCtrl.text.trim();
                                  final stepId = stepIdCtrl.text.trim();
                                  final stepStatus = stepStatusCtrl.text.trim();
                                  if (flowId.isEmpty ||
                                      stepId.isEmpty ||
                                      stepStatus.isEmpty) {
                                    throw const FormatException(
                                      'Flow ID、Step ID 和新状态都不能为空',
                                    );
                                  }
                                  final response =
                                      await postProductionEditImageUpdateImageFlowV1(
                                        token,
                                        flowId: flowId,
                                        stepId: stepId,
                                        updates: <String, dynamic>{
                                          'status': stepStatus,
                                        },
                                      );
                                  final nextSteps = steps
                                      .map(
                                        (step) => step.stepId == stepId
                                            ? ImageFlowStepV1(
                                                stepId: step.stepId,
                                                stepName: step.stepName,
                                                status: stepStatus,
                                              )
                                            : step,
                                      )
                                      .toList(growable: false);
                                  setState(() {
                                    steps = nextSteps;
                                    statusLine = '步骤 ${response.stepId} 已更新';
                                  });
                                }),
                          child: const Text('更新单个步骤状态'),
                        ),
                        if (statusLine != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            statusLine!,
                            style: Theme.of(dialogCtx).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      uploadCtrl.dispose();
      flowIdCtrl.dispose();
      promptCtrl.dispose();
      modelCtrl.dispose();
      stepIdCtrl.dispose();
      stepStatusCtrl.dispose();
    }
  }
}
