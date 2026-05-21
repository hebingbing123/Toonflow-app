part of '../../home_page.dart';

extension _StoryboardWorkbenchPatchActions on _StoryboardWorkbenchPanelState {
  Future<void> _openPatchRegenerationDialog() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final scopeCtrl = TextEditingController(text: 'storyboard_item');
    final idsCtrl = TextEditingController(
      text: widget.storyNumericId.toString(),
    );
    final reasonCtrl = TextEditingController(
      text: widget.scriptStoryboard.reason?.trim().isNotEmpty == true
          ? widget.scriptStoryboard.reason!.trim()
          : l10n.storyboardPatchDefaultReason,
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
    String labelPatchScope(String value) {
      switch (value) {
        case 'episode':
          return l10n.storyboardPatchScopeEpisode;
        case 'scene':
          return l10n.storyboardPatchScopeScene;
        case 'storyboard_item':
          return l10n.storyboardPatchScopeStoryboardItem;
        case 'video_prompt':
          return l10n.storyboardPatchScopeVideoPrompt;
        case 'derive_asset':
          return l10n.storyboardPatchScopeDeriveAsset;
        default:
          return value;
      }
    }

    String labelPatchModelTier(String value) {
      switch (value) {
        case 'low':
          return l10n.storyboardPatchModelTierLow;
        case 'high':
          return l10n.storyboardPatchModelTierHigh;
        default:
          return value;
      }
    }

    try {
      await showStudioDialog<void>(
        context: context,
        builder: (ctx) {
          var submitting = false;
          String? submitSummary;
          String? attributionSummary;
          List<String> repairPriority = const [];
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return StudioAlertDialog(
                title: Text(l10n.storyboardPatchDialogTitle),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StudioDropdownButtonFormField<String>(
                          initialValue: scopeCtrl.text,
                          decoration: InputDecoration(
                            labelText: l10n.storyboardPatchScopeLabel,
                            helperText: l10n.storyboardPatchScopeHelper,
                          ),
                          items: scopeOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(labelPatchScope(value)),
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
                        StudioDropdownButtonFormField<String>(
                          initialValue: modelTierCtrl.text,
                          decoration: InputDecoration(
                            labelText: l10n.storyboardPatchModelTierLabel,
                            helperText: l10n.storyboardPatchModelTierHelper,
                          ),
                          items: modelTierOptions
                              .map(
                                (value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(labelPatchModelTier(value)),
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
                          decoration: InputDecoration(
                            labelText: l10n.storyboardPatchTargetIdsLabel,
                            helperText: l10n.storyboardPatchTargetIdsHelper,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: l10n.storyboardPatchReasonLabel,
                            helperText: l10n.storyboardPatchReasonHelper,
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.storyboardPatchScopeHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: studioPanelMutedColor(context),
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
                            '${l10n.storyboardPatchAttributionLabel} $attributionSummary',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                        if (repairPriority.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.storyboardPatchRepairPriorityHeading,
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
                                      color: studioPanelMutedColor(context),
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
                    child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
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
                                SnackBar(
                                  content: Text(l10n.storyboardPatchSnackNeedTargetId),
                                ),
                              );
                              return;
                            }
                            if (reasonCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.storyboardPatchSnackNeedReason),
                                ),
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
                                buildStoryboardMediaOpBodyV1(
                                  base: <String, dynamic>{
                                    'op': 'patchRegeneration',
                                  'episodesId': widget.scriptNumericId,
                                  'scope': scopeCtrl.text,
                                  'ids': ids,
                                  'reason': reasonCtrl.text.trim(),
                                  'modelTier': modelTierCtrl.text,
                                  },
                                  projectUuid: widget.projectId,
                                ),
                              );
                              final response = media.patchRegeneration!;
                              if (!ctx.mounted) return;
                              final shortPatchId = response.patchId.length > 8
                                  ? response.patchId.substring(0, 8)
                                  : response.patchId;
                              setDialogState(() {
                                submitSummary = l10n.storyboardPatchSubmitLine(
                                  shortPatchId,
                                  response.scope,
                                  response.processedIds.join(','),
                                  response.modelTier,
                                  response.status,
                                  response.consecutiveFailures,
                                  response.savedTokenEstimate,
                                  response.memoryWritten
                                      ? l10n.storyboardPatchMemoryWrittenSuffix
                                      : '',
                                );
                                attributionSummary = response.attributionMode
                                    ? (response.attributionSummary ??
                                          l10n.storyboardPatchAttributionUpstreamHint)
                                    : null;
                                repairPriority = response.repairPriority;
                                submitting = false;
                              });
                              _applyWorkbenchState(() {
                                _setWorkbenchFollowUp(
                                  response.attributionMode
                                      ? l10n.storyboardPatchFollowUpAttribution
                                      : l10n.storyboardPatchFollowUpQueued,
                                );
                              });
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setDialogState(() => submitting = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(describeUserVisibleApiErrorResolved(context, e))),
                              );
                            }
                          },
                    child: Text(
                      submitting
                          ? l10n.storyboardPatchSubmitting
                          : l10n.storyboardPatchSubmit,
                    ),
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
