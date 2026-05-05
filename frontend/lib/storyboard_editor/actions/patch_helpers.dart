part of '../../home_page.dart';

extension _StoryboardWorkbenchPatchActions on _StoryboardWorkbenchPanelState {
  Future<void> _openPatchRegenerationDialog() async {
    final scopeCtrl = TextEditingController(text: 'storyboard_item');
    final idsCtrl = TextEditingController(
      text: widget.storyNumericId.toString(),
    );
    final reasonCtrl = TextEditingController(
      text: widget.scriptStoryboard.reason?.trim().isNotEmpty == true
          ? widget.scriptStoryboard.reason!.trim()
          : '请修复当前分镜的内容质量、连续性或情绪表达问题',
    );
    final modelTierCtrl = TextEditingController(text: 'high');
    final scopeOptions = <String>[
      'episode',
      'scene',
      'storyboard_item',
      'video_prompt',
      'derive_asset',
    ];
    final modelTierOptions = <String>['low', 'high'];
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          var submitting = false;
          String? submitSummary;
          String? attributionSummary;
          List<String> repairPriority = const [];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: const Text('局部返工面板'),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: scopeCtrl.text,
                          decoration: const InputDecoration(
                            labelText: 'scope',
                            helperText:
                                'episode / scene / storyboard_item / video_prompt / derive_asset',
                          ),
                          items: scopeOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: submitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  scopeCtrl.text = value;
                                },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: modelTierCtrl.text,
                          decoration: const InputDecoration(
                            labelText: 'model tier',
                            helperText: 'low 用于格式修复，high 用于内容质量修复',
                          ),
                          items: modelTierOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: submitting
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  modelTierCtrl.text = value;
                                },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: idsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'target ids',
                            helperText: '逗号分隔。默认带当前 storyboard numeric ID。',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '返工原因',
                            helperText: '建议明确写出人物、情绪、镜头、连续性、台词或视觉穿帮问题。',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '提示：优先选择最小 scope；如果只是当前分镜的表演、镜头或提示词问题，先用 storyboard_item / video_prompt，不要直接放大到整集。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                        if (submitSummary != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            submitSummary!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (attributionSummary != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'attribution mode: $attributionSummary',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                        if (repairPriority.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '返工优先级：',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          for (final item in repairPriority)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final ids = idsCtrl.text
                                .split(',')
                                .map((item) => int.tryParse(item.trim()))
                                .whereType<int>()
                                .toList(growable: false);
                            if (ids.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('请至少填写一个合法 target id'),
                                ),
                              );
                              return;
                            }
                            if (reasonCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('请填写返工原因')),
                              );
                              return;
                            }
                            setDialogState(() {
                              submitting = true;
                              submitSummary = null;
                              attributionSummary = null;
                              repairPriority = const [];
                            });
                            try {
                              final media = await postWorkbenchStoryboardMediaOpV1(
                                widget.token,
                                <String, dynamic>{
                                  'op': 'patchRegeneration',
                                  'projectId': widget.projectNumericId,
                                  'episodesId': widget.scriptNumericId,
                                  'scope': scopeCtrl.text,
                                  'ids': ids,
                                  'reason': reasonCtrl.text.trim(),
                                  'modelTier': modelTierCtrl.text,
                                },
                              );
                              final response = media.patchRegeneration!;
                              if (!ctx.mounted) return;
                              final shortPatchId = response.patchId.length > 8
                                  ? response.patchId.substring(0, 8)
                                  : response.patchId;
                              setDialogState(() {
                                submitSummary =
                                    '已提交 patch #$shortPatchId · scope=${response.scope} · ids=${response.processedIds.join(",")} · model=${response.modelTier} · status=${response.status} · 连续失败 ${response.consecutiveFailures} 次 · 预计节省 ${response.savedTokenEstimate} token${response.memoryWritten ? " · 已写入归因记忆" : ""}';
                                attributionSummary = response.attributionMode
                                    ? (response.attributionSummary ??
                                          '当前请求已进入问题归因模式，请先处理上游原因。')
                                    : null;
                                repairPriority = response.repairPriority;
                                submitting = false;
                              });
                              _applyWorkbenchState(() {
                                _setWorkbenchFollowUp(
                                  response.attributionMode
                                      ? '局部返工已提交，并进入 attribution mode。优先按面板里的 P1/P2 顺序处理，不要直接整段重跑。'
                                      : '局部返工已提交，当前按最小范围排队处理。',
                                );
                              });
                            } on RustApiException catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() => submitting = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() => submitting = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                    child: Text(submitting ? '提交中…' : '提交返工'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      scopeCtrl.dispose();
      idsCtrl.dispose();
      reasonCtrl.dispose();
      modelTierCtrl.dispose();
    }
  }

  StoryboardVideoPromptRequest _buildCurrentVideoPromptRequest() {
    return buildStoryboardVideoPromptRequest(
      scriptStoryboard: widget.scriptStoryboard,
      productionStoryboard: _productionRow,
      draftNarration: widget.readVideoDescriptionText(),
      draftPrompt: widget.readPromptText(),
      draftDuration: _videoDurationCtrl.text,
    );
  }
}
