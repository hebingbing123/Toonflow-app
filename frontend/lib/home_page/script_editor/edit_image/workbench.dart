part of '../../../home_page.dart';

extension _HomePageScriptEditorEditImageWorkbench on _HomePageState {
  Future<void> _openScriptEditImageWorkbenchDialog({
    required String token,
    required int projectNumericId,
    required int scriptNumericId,
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
    bool didAutoRefresh = false;

    Future<void> refresh(StateSetter setState) async {
      final previousStepId = stepIdCtrl.text.trim();
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
          ImageFlowStepV1? selectedStep;
          for (final step in flow.steps) {
            if (step.stepId == previousStepId) {
              selectedStep = step;
              break;
            }
          }
          final focusStep =
              selectedStep ?? (flow.steps.isEmpty ? null : flow.steps.first);
          if (focusStep != null) {
            stepIdCtrl.text = focusStep.stepId;
            stepStatusCtrl.text = focusStep.status;
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
              if (!didAutoRefresh) {
                didAutoRefresh = true;
                Future<void>.microtask(() => refresh(setState));
              }
              return ScriptEditImageWorkbenchDialogView(
                model: ScriptEditImageWorkbenchDialogViewModel(
                  loading: loading,
                  busy: busy,
                  steps: steps,
                  defaultModel: defaultModel,
                  uploadedImageUrl: uploadedImageUrl,
                  statusLine: statusLine,
                  uploadCtrl: uploadCtrl,
                  flowIdCtrl: flowIdCtrl,
                  promptCtrl: promptCtrl,
                  modelCtrl: modelCtrl,
                  stepIdCtrl: stepIdCtrl,
                  stepStatusCtrl: stepStatusCtrl,
                ),
                callbacks: ScriptEditImageWorkbenchDialogViewCallbacks(
                  onRefresh: () => refresh(setState),
                  onUploadSourceImage: () => runMutation(setState, () async {
                    final base64Data = uploadCtrl.text.trim();
                    if (base64Data.isEmpty) {
                      throw const FormatException('请先粘贴源图 base64 或 data URI');
                    }
                    final response = await postProductionEditImageUploadImageV1(
                      token,
                      projectId: projectNumericId,
                      scriptId: scriptNumericId,
                      base64Data: base64Data,
                    );
                    setState(() {
                      uploadedImageUrl = response.url;
                      statusLine = '源图已上传，URL 已返回，可继续生成流程图片';
                    });
                  }),
                  onGenerateFlowImage: () => runMutation(setState, () async {
                    final flowId = flowIdCtrl.text.trim();
                    final prompt = promptCtrl.text.trim();
                    if (flowId.isEmpty || prompt.isEmpty) {
                      throw const FormatException('Flow ID 和生成提示词都不能为空');
                    }
                    final response =
                        await postProductionEditImageGenerateFlowImageV1(
                          token,
                          projectId: projectNumericId,
                          scriptId: scriptNumericId,
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
                  onSaveFlow: () => runMutation(setState, () async {
                    final flowId = flowIdCtrl.text.trim();
                    if (flowId.isEmpty) {
                      throw const FormatException('Flow ID 不能为空');
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
                      statusLine = 'Flow ${response.flowId} 已保存';
                    });
                  }),
                  onSelectStep: (step) {
                    setState(() {
                      stepIdCtrl.text = step.stepId;
                      stepStatusCtrl.text = step.status;
                    });
                  },
                  onUpdateStepStatus: () => runMutation(setState, () async {
                    final flowId = flowIdCtrl.text.trim();
                    final stepId = stepIdCtrl.text.trim();
                    final stepStatus = stepStatusCtrl.text.trim();
                    if (flowId.isEmpty ||
                        stepId.isEmpty ||
                        stepStatus.isEmpty) {
                      throw const FormatException('Flow ID、Step ID 和新状态都不能为空');
                    }
                    final response =
                        await postProductionEditImageUpdateImageFlowV1(
                          token,
                          flowId: flowId,
                          stepId: stepId,
                          updates: <String, dynamic>{'status': stepStatus},
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
                  onClose: () => Navigator.of(dialogCtx).pop(),
                ),
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
