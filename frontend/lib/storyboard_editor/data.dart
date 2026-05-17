part of '../../home_page.dart';

/// Encapsulates storyboard workbench data loading so the main panel file stays
/// focused on state ownership and section composition.
extension _StoryboardWorkbenchData on _StoryboardWorkbenchPanelState {
  Future<void> _refreshExportJobStatus() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final jobId = _latestExportJobId?.trim();
    if (jobId == null || jobId.isEmpty) {
      throw FormatException(l10n.storyboardWorkbenchErrNoExportJobSubmitted);
    }
    _applyWorkbenchState(() => _loadingExportJob = true);
    try {
      final job = await fetchJob(widget.token, jobId);
      if (!mounted) return;
      final exportUrl = (job.result?['export_url'] as String?)?.trim() ?? '';
      final shouldSyncWriteback =
          job.status == 'completed' &&
          exportUrl.isNotEmpty &&
          !_latestExportWritebackSynced;
      _applyWorkbenchState(() {
        _latestExportJob = job;
      });
      if (shouldSyncWriteback) {
        await _refreshProductionData(syncImageUrl: true);
        if (!mounted) return;
        _applyWorkbenchState(() {
          _latestExportWritebackSynced = true;
          _setWorkbenchFollowUp(
            l10n.storyboardWorkbenchExportCompletedSyncedProduction,
          );
        });
      }
    } finally {
      if (mounted) {
        _applyWorkbenchState(() => _loadingExportJob = false);
      }
    }
  }

  Future<void> _refreshProductionData({
    bool syncImageUrl = false,
    bool syncTrackId = false,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    _applyWorkbenchState(() {
      _loadingProduction = true;
      _productionError = null;
      _setWorkbenchActionNotice(
        actionSummary: l10n.storyboardWorkbenchSyncProductionLoadingSummary,
        recommendedAction:
            StoryboardWorkbenchRecommendedAction.syncProductionData,
        detail: l10n.storyboardWorkbenchSyncProductionLoadingDetail,
      );
    });
    try {
      final productionRow = await postStoryboardGetDataV1(
        widget.token,
        projectUuid: widget.projectId,
        scriptId: widget.scriptNumericId,
        storyboardId: widget.storyNumericId,
      );
      final productionRows = await postProductionGetStoryboardDataV1(
        widget.token,
        projectUuid: widget.projectId,
        scriptId: widget.scriptNumericId,
        clientDataVersion: _cachedStoryboardListDataVersion,
      );
      if (!mounted) return;
      final listRows = productionRows.unchanged
          ? _productionRows
          : productionRows.data;
      if (productionRows.dataVersion != null &&
          productionRows.dataVersion!.isNotEmpty) {
        _cachedStoryboardListDataVersion = productionRows.dataVersion;
      }
      _applyWorkbenchState(() {
        _productionRow = productionRow;
        _productionRows = listRows;
        if (syncImageUrl) {
          _imageUrlCtrl.text = productionRow.url ?? '';
        }
        if (syncTrackId && productionRow.trackId != null) {
          _trackIdCtrl.text = productionRow.trackId!.toString();
        }
        final videoPromptSeed = resolveStoryboardVideoPromptSeed(
          scriptStoryboard: widget.scriptStoryboard,
          productionStoryboard: productionRow,
        );
        if (_videoPromptCtrl.text.trim().isEmpty &&
            videoPromptSeed != null &&
            videoPromptSeed.isNotEmpty) {
          _videoPromptCtrl.text = videoPromptSeed;
          _lastGeneratedVideoPromptText = null;
          _lastGeneratedVideoPromptSignature = null;
          _lastGeneratedAutoNegativePrompt = null;
          _lastGeneratedVideoPromptDiagnostics = null;
          _videoPromptEditedAfterAutoGenerate = false;
        }
        if ((_videoDurationCtrl.text.trim().isEmpty ||
                int.tryParse(_videoDurationCtrl.text.trim()) == null) &&
            (productionRow.duration ?? '').trim().isNotEmpty) {
          _videoDurationCtrl.text = productionRow.duration!.trim();
        }
        _liveActionReferenceShotsCtrl.text = productionRow
            .liveActionReferenceShotUrls
            .join('\n');
        _liveActionPerformanceNotesCtrl.text =
            productionRow.liveActionPerformanceNotes ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      _applyWorkbenchState(() {
        _productionError = normalizeStoryboardWorkbenchErrorMessage(
          l10n,
          describeUserVisibleApiError(l10n, e),
        );
        _setWorkbenchFailureNotice(
          actionSummary: l10n.storyboardWorkbenchSyncProductionFailedSummary,
          recommendedAction:
              StoryboardWorkbenchRecommendedAction.syncProductionData,
          error: e,
          fallbackDetail:
              l10n.storyboardWorkbenchSyncProductionFailedFallbackDetail,
        );
      });
    } finally {
      if (mounted) {
        _applyWorkbenchState(() => _loadingProduction = false);
      }
    }
  }

  Future<void> _refreshWorkbenchData() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    _applyWorkbenchState(() {
      _loadingWorkbench = true;
      _setWorkbenchActionNotice(
        actionSummary: l10n.storyboardWorkbenchRefreshVideoLoadingSummary,
        recommendedAction:
            StoryboardWorkbenchRecommendedAction.refreshVideoData,
        detail: l10n.storyboardWorkbenchRefreshVideoLoadingDetail,
      );
    });
    try {
      final model = await postWorkbenchGetVideoModelDetailV1(widget.token);
      final generateData = await postWorkbenchGetGenerateDataV1(
        widget.token,
        projectUuid: widget.projectId,
        scriptId: widget.scriptNumericId,
      );
      if (!mounted) return;
      _applyWorkbenchState(() {
        _modelDetail = model;
        _generateData = generateData;
        if (!model.resolutions.contains(_resolution)) {
          _resolution = model.resolutions.isEmpty
              ? '1080p'
              : model.resolutions.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      _applyWorkbenchState(() {
        _setWorkbenchFailureNotice(
          actionSummary: l10n.storyboardWorkbenchRefreshVideoFailedSummary,
          recommendedAction:
              StoryboardWorkbenchRecommendedAction.refreshVideoData,
          error: e,
          fallbackDetail:
              l10n.storyboardWorkbenchRefreshVideoFailedFallbackDetail,
        );
      });
    } finally {
      if (mounted) {
        _applyWorkbenchState(() => _loadingWorkbench = false);
      }
    }
  }

  Future<void> _refreshAll({
    bool syncImageUrl = false,
    bool syncTrackId = false,
  }) async {
    await _refreshProductionData(
      syncImageUrl: syncImageUrl,
      syncTrackId: syncTrackId,
    );
    await _refreshWorkbenchData();
    final jobId = _latestExportJobId?.trim();
    if (jobId != null && jobId.isNotEmpty) {
      await _refreshExportJobStatus();
    }
    await _refreshStoryboardShotReadiness();
  }

  Future<void> _refreshStoryboardShotReadiness() async {
    try {
      final pr = await fetchProjectShortVideoReadinessByProjectId(
        widget.token,
        widget.projectId,
      );
      if (!mounted) {
        return;
      }
      StoryboardShortVideoReadiness? mine;
      for (final s in pr.storyboards) {
        if (s.storyboardNumericId == widget.storyNumericId) {
          mine = s;
          break;
        }
      }
      _applyWorkbenchState(() {
        _storyboardShotReadiness = mine;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _applyWorkbenchState(() {
        _storyboardShotReadiness = null;
      });
    }
  }

  List<int> _knownTrackIds() {
    return collectStoryboardTrackIds(
      scriptStoryboard: widget.scriptStoryboard,
      productionStoryboard: _productionRow,
      productionStoryboards: _productionRows,
      generatedVideos: _generateData?.generatedVideos ?? const [],
    );
  }

  List<VideoItem> _storyboardVideos() {
    return storyboardScopedVideos(
      _generateData?.generatedVideos ?? const [],
      widget.storyNumericId,
    );
  }
}
