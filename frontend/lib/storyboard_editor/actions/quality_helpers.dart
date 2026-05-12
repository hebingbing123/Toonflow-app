part of '../../home_page.dart';

extension _StoryboardWorkbenchQualityActions on _StoryboardWorkbenchPanelState {
  Future<void> _notifyStoryboardMutated() async {
    final callback = widget.onStoryboardMutated;
    if (callback == null) {
      return;
    }
    await callback();
  }

  Future<void> _readCurrentPreview() async {
    final l10n = AppLocalizations.of(context)!;
    final preview = await postStoryboardPreviewImageV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    _imageUrlCtrl.text = preview.imageUrl ?? '';
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(
        preview.imageUrl == null
            ? l10n.storyboardActionFollowUpPreviewMissing
            : l10n.storyboardActionFollowUpPreviewRead,
      );
    });
  }

  Future<void> _saveImageUrl() async {
    final l10n = AppLocalizations.of(context)!;
    final imageUrl = _imageUrlCtrl.text.trim();
    if (imageUrl.isEmpty) {
      throw FormatException(l10n.storyboardActionErrImageUrlRequired);
    }
    final response = await postStoryboardUpdateUrlV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      imageUrl: imageUrl,
    );
    _imageUrlCtrl.text = response.imageUrl;
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(l10n.storyboardActionFollowUpImageUrlSaved);
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _saveLiveActionReference() async {
    final l10n = AppLocalizations.of(context)!;
    final referenceShotUrls = _liveActionReferenceShotsCtrl.text
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final performanceNotes = _liveActionPerformanceNotesCtrl.text.trim();
    final response = await postStoryboardUpdateLiveActionReferenceV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      referenceShotUrls: referenceShotUrls,
      performanceNotes: performanceNotes.isEmpty ? null : performanceNotes,
    );
    _liveActionReferenceShotsCtrl.text = response.referenceShotUrls.join('\n');
    _liveActionPerformanceNotesCtrl.text = response.performanceNotes ?? '';
    await _refreshProductionData();
    await _refreshStoryboardShotReadiness();
    if (!mounted) return;
    _applyWorkbenchState(() {
      final count = response.referenceShotUrls.length;
      _setWorkbenchFollowUp(
        count <= 0
            ? l10n.storyboardActionFollowUpLiveActionCleared
            : l10n.storyboardActionFollowUpLiveActionSaved(count),
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _clearCurrentFrame() async {
    final l10n = AppLocalizations.of(context)!;
    await postStoryboardRemoveFrameV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    _imageUrlCtrl.clear();
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(l10n.storyboardActionFollowUpFrameCleared);
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _addTrack() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _trackNameCtrl.text.trim();
    if (name.isEmpty) {
      throw FormatException(l10n.storyboardActionErrTrackNameRequired);
    }
    final response = await postWorkbenchAddTrackV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      trackName: name,
    );
    _trackIdCtrl.text = response.trackId.toString();
    _trackNameCtrl.clear();
    await _refreshAll(syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(
      () => _setWorkbenchFollowUp(
        l10n.storyboardActionFollowUpTrackAdded(response.trackId),
      ),
    );
    await _notifyStoryboardMutated();
  }

  Future<void> _deleteTrack() async {
    final l10n = AppLocalizations.of(context)!;
    final trackId = int.tryParse(_trackIdCtrl.text.trim());
    if (trackId == null || trackId <= 0) {
      throw FormatException(l10n.storyboardActionErrTrackIdInvalid);
    }
    await postWorkbenchDeleteTrackV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      trackId: trackId,
    );
    if (_productionRow?.trackId == trackId) _trackIdCtrl.clear();
    await _refreshAll(syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(
      () => _setWorkbenchFollowUp(
        l10n.storyboardActionFollowUpTrackDeleted(trackId),
      ),
    );
    await _notifyStoryboardMutated();
  }

  Future<void> _generateVideoPrompt() async {
    final l10n = AppLocalizations.of(context)!;
    final request = _buildCurrentVideoPromptRequest();
    final imageUrl = _currentStoryboardSourceImage();
    final generated = await postWorkbenchGenerateVideoPromptV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      autoQualityReview: _autoQualityReviewOnGeneratePrompt,
      imageUrl: imageUrl,
      description: request.description,
      durationHint: request.durationSeconds,
    );
    _applyGeneratedVideoPrompt(
      generated,
      signature: _buildVideoPromptSignature(
        request: request,
        imageUrl: imageUrl,
      ),
    );
    if (!mounted) return;
    final followUp = buildStoryboardPromptGenerationFollowUp(
      l10n,
      generated.diagnostics,
      observationNote: generated.observationNote,
    );
    _applyWorkbenchState(() => _setWorkbenchFollowUp(followUp));
  }

  Future<void> _selectVideo(VideoItem video) async {
    final l10n = AppLocalizations.of(context)!;
    final media = await postWorkbenchStoryboardMediaOpV1(
      widget.token,
      buildStoryboardMediaOpBodyV1(
        base: <String, dynamic>{
          'op': 'selectVideo',
          'scriptId': widget.scriptNumericId,
          'storyboardId': widget.storyNumericId,
          'videoUrl': video.videoUrl!.trim(),
        },
        projectUuid: widget.projectId,
      ),
    );
    final response = media.selectVideo!;
    await _refreshProductionData(syncTrackId: true);
    if (!mounted) return;
    final memorySummary = response.selectedMemory == null
        ? l10n.storyboardActionFollowUpVideoSelectedBase
        : '${l10n.storyboardActionFollowUpVideoSelectedBase}${describeStoryboardSelectedMemoryFeedback(l10n, response.selectedMemory!)}';
    _applyWorkbenchState(() => _setWorkbenchFollowUp(memorySummary));
    await _notifyStoryboardMutated();
  }

  Future<void> _deleteCurrentVideo() async {
    final l10n = AppLocalizations.of(context)!;
    final response = await postWorkbenchDeleteVideoV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    await _refreshProductionData(syncTrackId: true);
    await _refreshWorkbenchData();
    if (!mounted) return;
    final followUp = response.negativeMemory == null
        ? l10n.storyboardActionFollowUpVideoDeletedBase
        : '${l10n.storyboardActionFollowUpVideoDeletedBase}${describeStoryboardRejectedMemoryFeedback(l10n, response.negativeMemory!)}';
    _applyWorkbenchState(() => _setWorkbenchFollowUp(followUp));
    await _notifyStoryboardMutated();
  }

  void _prepareVideoTrack(List<int> knownTrackIds) {
    final l10n = AppLocalizations.of(context)!;
    _applyWorkbenchState(() {
      final currentTrackId = int.tryParse(_trackIdCtrl.text.trim());
      if (currentTrackId != null && currentTrackId > 0) {
        _setWorkbenchFollowUp(l10n.storyboardActionFollowUpTrackReady);
        return;
      }
      if (knownTrackIds.isNotEmpty) {
        _trackIdCtrl.text = knownTrackIds.first.toString();
        _setWorkbenchFollowUp(
          l10n.storyboardActionFollowUpTrackBackfilled(knownTrackIds.first),
        );
        return;
      }
      if (_trackNameCtrl.text.trim().isEmpty) {
        _trackNameCtrl.text = l10n.storyboardActionFollowUpTrackNamePrefilled(
          widget.storyNumericId,
        );
      }
      _setWorkbenchFollowUp(l10n.storyboardActionFollowUpTrackNameHint);
    });
  }

  Future<void> _syncProductionDataAction() async {
    final l10n = AppLocalizations.of(context)!;
    await _refreshProductionData(syncImageUrl: true, syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(l10n.storyboardActionFollowUpSyncProduction);
    });
  }

  Future<void> _refreshVideoDataAction() async {
    final l10n = AppLocalizations.of(context)!;
    await _refreshWorkbenchData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(l10n.storyboardActionFollowUpRefreshVideo);
    });
  }

  Future<void> _refreshProductionInputsAction() async {
    await _refreshProductionData(syncImageUrl: true, syncTrackId: true);
  }
}
