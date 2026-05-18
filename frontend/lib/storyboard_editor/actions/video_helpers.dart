part of '../../home_page.dart';

extension _StoryboardWorkbenchVideoActions on _StoryboardWorkbenchPanelState {
  String? _currentStoryboardSourceImage() {
    return resolveStoryboardSourceImageUrl(
      productionStoryboard: _productionRow,
      draftImageUrl: _imageUrlCtrl.text,
    );
  }

  String _buildVideoPromptSignature({
    required StoryboardVideoPromptRequest request,
    required String? imageUrl,
  }) {
    final description = request.description?.trim() ?? '';
    final duration = request.durationSeconds?.toString() ?? '';
    final image = imageUrl?.trim() ?? '';
    return '$description|$duration|$image';
  }

  bool _videoPromptNeedsAutoRefresh({
    required String currentPrompt,
    required StoryboardVideoPromptRequest request,
    required String? imageUrl,
  }) {
    if (currentPrompt.isEmpty) {
      return true;
    }
    final defaultSeed =
        resolveStoryboardVideoPromptSeed(
          scriptStoryboard: widget.scriptStoryboard,
          productionStoryboard: _productionRow,
          draftNarration: widget.readVideoDescriptionText(),
          draftPrompt: widget.readPromptText(),
        )?.trim() ??
        '';
    if (defaultSeed.isNotEmpty && currentPrompt == defaultSeed) {
      return true;
    }
    if (_videoPromptEditedAfterAutoGenerate) {
      return false;
    }
    final generatedPrompt = _lastGeneratedVideoPromptText?.trim();
    if (generatedPrompt == null || generatedPrompt.isEmpty) {
      return false;
    }
    if (currentPrompt != generatedPrompt) {
      return false;
    }
    return _lastGeneratedVideoPromptSignature !=
        _buildVideoPromptSignature(request: request, imageUrl: imageUrl);
  }

  void _applyGeneratedVideoPrompt(
    GenerateVideoPromptResponse generated, {
    required String signature,
  }) {
    _syncingGeneratedVideoPrompt = true;
    _videoPromptCtrl.text = generated.prompt;
    _negativeVideoPromptCtrl.text = generated.negativePrompt ?? '';
    _videoDurationCtrl.text = generated.duration.toString();
    _syncingGeneratedVideoPrompt = false;
    _lastGeneratedVideoPromptText = generated.prompt.trim();
    _lastGeneratedVideoPromptSignature = signature;
    _lastGeneratedAutoNegativePrompt = generated.negativePrompt?.trim();
    _lastGeneratedVideoPromptDiagnostics = generated.diagnostics;
    _videoPromptEditedAfterAutoGenerate = false;
  }

  StoryboardVideoPromptRepairResult? _repairCurrentPromptFromDiagnostics() {
    final diagnostics = _visiblePromptDiagnostics();
    if (diagnostics == null) {
      return null;
    }
    final repaired = applyStoryboardVideoPromptRepairs(
      diagnostics: diagnostics,
      prompt: _videoPromptCtrl.text,
      negativePrompt: _negativeVideoPromptCtrl.text,
      automaticNegativePrompt: _lastGeneratedAutoNegativePrompt,
    );
    _syncingGeneratedVideoPrompt = true;
    _videoPromptCtrl.text = repaired.prompt;
    _negativeVideoPromptCtrl.text = repaired.negativePrompt;
    _syncingGeneratedVideoPrompt = false;
    _lastGeneratedVideoPromptDiagnostics = null;
    _videoPromptEditedAfterAutoGenerate = true;
    return repaired;
  }

  void _applyPromptRepairSuggestions() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final repaired = _repairCurrentPromptFromDiagnostics();
    if (repaired == null) {
      return;
    }
    _applyWorkbenchState(() {
      _setWorkbenchActionNotice(
        actionSummary: repaired.changed
            ? l10n.storyboardActionRepairAppliedSummary
            : l10n.storyboardActionRepairNoChangeSummary,
        recommendedAction:
            StoryboardWorkbenchRecommendedAction.submitVideoGeneration,
        detail: repaired.changed
            ? l10n.storyboardActionRepairDetailTrimmed(
                repaired.removedPromptFragmentCount,
                repaired.removedNegativeFragmentCount,
              )
            : l10n.storyboardActionRepairDetailLean,
      );
    });
  }

  Future<void> _refreshVideoPromptBeforeSubmitIfNeeded() async {
    final currentPrompt = _videoPromptCtrl.text.trim();
    final request = _buildCurrentVideoPromptRequest();
    final imageUrl = _currentStoryboardSourceImage();
    if (!_videoPromptNeedsAutoRefresh(
      currentPrompt: currentPrompt,
      request: request,
      imageUrl: imageUrl,
    )) {
      return;
    }

    final generated = await postWorkbenchGenerateVideoPromptV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      autoQualityReview: _autoQualityReviewOnGeneratePrompt,
      imageUrl: imageUrl,
      description: request.description,
      durationHint: request.durationSeconds,
      skipIfUnchanged: true,
    );
    _applyGeneratedVideoPrompt(
      generated,
      signature: _buildVideoPromptSignature(
        request: request,
        imageUrl: imageUrl,
      ),
    );
  }

  Future<void> _submitVideoGeneration() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final est = _videoEstimate;
    if (est != null && mounted) {
      final ok = await showStudioCostConfirmSheet(
        context: context,
        estimate: est,
      );
      if (!ok || !mounted) return;
    }
    await assertStoryboardReadyForVideoGeneration(
      accessToken: widget.token,
      projectUuid: widget.projectId,
      storyboardNumericId: widget.storyNumericId,
      l10n: l10n,
    );
    final sourceImage = _currentStoryboardSourceImage();
    if (sourceImage == null) {
      throw FormatException(l10n.storyboardActionErrNeedSourceImageOrPreview);
    }
    var trackId = int.tryParse(_trackIdCtrl.text.trim());
    if (trackId == null || trackId <= 0) {
      final knownTrackIds = _knownTrackIds();
      if (knownTrackIds.length == 1) {
        trackId = knownTrackIds.first;
        _trackIdCtrl.text = trackId.toString();
      }
    }
    if (trackId == null || trackId <= 0) {
      throw FormatException(l10n.storyboardActionErrTrackIdRequired);
    }
    final duration = int.tryParse(_videoDurationCtrl.text.trim());
    if (duration == null || duration <= 0) {
      throw FormatException(l10n.storyboardActionErrDurationPositiveInteger);
    }
    await _refreshVideoPromptBeforeSubmitIfNeeded();
    final repairedBeforeSubmit = _repairCurrentPromptFromDiagnostics();
    final prompt = _videoPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      throw FormatException(l10n.storyboardActionErrVideoPromptEmpty);
    }
    final rawNegativePrompt = _negativeVideoPromptCtrl.text.trim();
    final compactedManualNegative = compactStoryboardManualNegativePrompt(
      manualPrompt: rawNegativePrompt,
      automaticPrompt: _lastGeneratedAutoNegativePrompt,
    );
    final negativePrompt = compactedManualNegative.manualPrompt.trim();
    late final WorkbenchGenerateVideoResponse response;
    try {
      response = await postProductionWorkbenchGenerateVideoV1(
        widget.token,
        projectUuid: widget.projectId,
        scriptId: widget.scriptNumericId,
        uploadData: [
          <String, dynamic>{'id': widget.storyNumericId, 'sources': sourceImage},
        ],
        prompt: prompt,
        negativePrompt: negativePrompt.isEmpty ? null : negativePrompt,
        model: _modelDetail?.modelId ?? 'kling-v1',
        mode: _mode,
        resolution: _resolution,
        duration: duration,
        audio: _audio,
        trackId: trackId,
      );
    } on RustApiException catch (e) {
      final blocked = formatGenerationBlockedFromRustApiException(l10n, e);
      if (blocked != null && blocked.isNotEmpty) {
        throw FormatException(blocked);
      }
      rethrow;
    }
    final appliedNegativePrompt = response.storyboardNegativePrompts
        .where((item) => item.storyboardId == widget.storyNumericId)
        .map((item) => item.negativePrompt?.trim() ?? '')
        .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    _negativeVideoPromptCtrl.text = appliedNegativePrompt;
    if (!mounted) return;
    await _refreshWorkbenchData();
    if (!mounted) return;
    final repaired = repairedBeforeSubmit;
    final repairedCh = repaired != null && repaired.changed;
    final promptRm = repaired?.removedPromptFragmentCount ?? 0;
    final negRm = repaired?.removedNegativeFragmentCount ?? 0;
    final dedupe = compactedManualNegative.removedFragmentCount;
    final emptyNeg = appliedNegativePrompt.isEmpty;
    final duplicateNotice = response.skippedDuplicateCount > 0
        ? l10n.storyboardActionVideoSkippedDuplicates(
            response.skippedDuplicateCount,
            '${response.skippedDuplicateStoryboardIds.take(6).join(', ')}${response.skippedDuplicateStoryboardIds.length > 6 ? '…' : ''}',
          )
        : '';
    _applyWorkbenchState(() {
      final msg = emptyNeg
          ? repairedCh
                ? l10n.storyboardActionVideoJobsSubmittedRepairOnly(
                    response.total,
                    promptRm,
                    negRm,
                  )
                : dedupe > 0
                ? l10n.storyboardActionVideoJobsSubmittedDedupeOnly(
                    response.total,
                    dedupe,
                  )
                : l10n.storyboardActionVideoJobsSubmittedTotalOnly(
                    response.total,
                  )
          : repairedCh
          ? l10n.storyboardActionVideoJobsSubmittedRepairFinal(
              response.total,
              promptRm,
              negRm,
            )
          : dedupe > 0
          ? l10n.storyboardActionVideoJobsSubmittedDedupeFinal(
              response.total,
              dedupe,
            )
          : l10n.storyboardActionVideoJobsSubmittedFinalOnly(response.total);
      _setWorkbenchFollowUp(
        duplicateNotice.isEmpty ? msg : '$msg · $duplicateNotice',
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _generateVoiceover() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final response = await postWorkbenchGenerateVoiceoverV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardIds: [widget.storyNumericId],
    );
    await _refreshProductionData();
    if (!mounted) return;
    final queuedIds = response.enqueuedJobIds;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(
        queuedIds.isEmpty
            ? l10n.storyboardActionVoiceoverJobsSubmitted(response.total)
            : l10n.storyboardActionVoiceoverJobsSubmittedWithJob(
                response.total,
                queuedIds.first,
              ),
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _saveVideoDescription() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final response = await updateStoryboardByProjectAndNumericId(
      widget.token,
      widget.projectId,
      widget.storyNumericId,
      <String, dynamic>{
        'video_desc': widget.videoDescriptionCtrl.text.trim().isEmpty
            ? null
            : widget.videoDescriptionCtrl.text.trim(),
      },
    );
    widget.videoDescriptionCtrl.text = response.videoDesc ?? '';
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(
        widget.videoDescriptionCtrl.text.trim().isEmpty
            ? l10n.storyboardActionVideoDescCleared
            : l10n.storyboardActionVideoDescSaved,
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _exportCurrentVideoJob() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final candidates = _storyboardVideos();
    final selected = widget.scriptStoryboard.filePath;
    final sourceUrl = (selected ?? '').trim().isNotEmpty
        ? selected!.trim()
        : (candidates
              .map((v) => v.videoUrl)
              .whereType<String>()
              .map((s) => s.trim())
              .firstWhere((s) => s.isNotEmpty, orElse: () => ''));
    if (sourceUrl.isEmpty) {
      throw FormatException(l10n.storyboardActionErrNoExportableVideoUrl);
    }
    final media = await postWorkbenchStoryboardMediaOpV1(
      widget.token,
      buildStoryboardMediaOpBodyV1(
        base: <String, dynamic>{
          'op': 'enqueueVideoExport',
          'scriptId': widget.scriptNumericId,
          'storyboardId': widget.storyNumericId,
          'sourceUrl': sourceUrl,
          'format': 'mp4',
        },
        projectUuid: widget.projectId,
      ),
    );
    final job = media.enqueueVideoExport!.job;
    if (!mounted) return;
    _applyWorkbenchState(() {
      _latestExportJobId = job.id;
      _latestExportJob = job;
      _latestExportWritebackSynced = false;
      _setWorkbenchFollowUp(l10n.storyboardActionExportJobEnqueued(job.id));
    });
  }
}
