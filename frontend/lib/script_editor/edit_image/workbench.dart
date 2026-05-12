part of '../../../home_page.dart';

extension _HomePageScriptEditorEditImageWorkbench on _HomePageState {
  Future<void> _openScriptEditImageWorkbenchDialog({
    required String token,
    required String projectId,
    required int scriptNumericId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
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
          statusLine = l10n.scriptEditorEditImageWorkbenchFlowLoaded(
            flow.flowId,
            flow.steps.length,
            model.model,
          );
        });
      } on RustApiException catch (e) {
        setState(
          () =>
              statusLine = l10n.scriptEditorEditImageWorkbenchLoadFailed(
                e.toString(),
              ),
        );
      } catch (e) {
        setState(
          () =>
              statusLine = l10n.scriptEditorEditImageWorkbenchLoadFailed(
                e.toString(),
              ),
        );
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
                      throw FormatException(
                        l10n.scriptEditorEditImageWorkbenchErrPasteSource,
                      );
                    }
                    final response = await postProductionEditImageUploadImageV1(
                      token,
                      projectUuid: projectId,
                      scriptId: scriptNumericId,
                      base64Data: base64Data,
                    );
                    setState(() {
                      uploadedImageUrl = response.url;
                      statusLine =
                          l10n.scriptEditorEditImageWorkbenchSourceUploaded;
                    });
                  }),
                  onGenerateFlowImage: () => runMutation(setState, () async {
                    final flowId = flowIdCtrl.text.trim();
                    final prompt = promptCtrl.text.trim();
                    if (flowId.isEmpty || prompt.isEmpty) {
                      throw FormatException(
                        l10n.scriptEditorEditImageWorkbenchErrFlowAndPromptEmpty,
                      );
                    }
                    final response =
                        await postProductionEditImageGenerateFlowImageV1(
                          token,
                          projectUuid: projectId,
                          scriptId: scriptNumericId,
                          flowId: flowId,
                          prompt: prompt,
                          model: modelCtrl.text.trim().isEmpty
                              ? null
                              : modelCtrl.text.trim(),
                        );
                    setState(() {
                      statusLine =
                          l10n.scriptEditorEditImageWorkbenchJobEnqueued(
                            response.jobId,
                            response.status,
                          );
                    });
                  }),
                  onSaveFlow: () => runMutation(setState, () async {
                    final flowId = flowIdCtrl.text.trim();
                    if (flowId.isEmpty) {
                      throw FormatException(
                        l10n.scriptEditorEditImageWorkbenchErrFlowIdEmpty,
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
                      statusLine = l10n.scriptEditorEditImageWorkbenchFlowSaved(
                        response.flowId,
                      );
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
                      throw FormatException(
                        l10n.scriptEditorEditImageWorkbenchErrFlowStepStatusEmpty,
                      );
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
                      statusLine =
                          l10n.scriptEditorEditImageWorkbenchStepUpdated(
                            response.stepId,
                          );
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
