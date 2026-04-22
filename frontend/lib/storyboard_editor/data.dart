part of '../../home_page.dart';

/// Encapsulates storyboard workbench data loading so the main panel file stays
/// focused on state ownership and section composition.
extension _StoryboardWorkbenchData on _StoryboardWorkbenchPanelState {
  Future<void> _refreshExportJobStatus() async {
    final jobId = _latestExportJobId?.trim();
    if (jobId == null || jobId.isEmpty) {
      throw const FormatException('当前还没有已提交的导出任务');
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
          _setWorkbenchFollowUp('导出任务已完成，已自动同步当前分镜制作数据。');
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
    _applyWorkbenchState(() {
      _loadingProduction = true;
      _productionError = null;
      _setWorkbenchActionNotice(
        actionSummary: '正在同步当前分镜制作数据。',
        recommendedAction:
            StoryboardWorkbenchRecommendedAction.syncProductionData,
        detail: '同步完成后会自动回填当前画面、轨道和可用视频参数。',
      );
    });
    try {
      final productionRow = await postStoryboardGetDataV1(
        widget.token,
        projectId: widget.projectNumericId,
        scriptId: widget.scriptNumericId,
        storyboardId: widget.storyNumericId,
      );
      final productionRows = await postProductionGetStoryboardDataV1(
        widget.token,
        projectId: widget.projectNumericId,
        scriptId: widget.scriptNumericId,
      );
      if (!mounted) return;
      _applyWorkbenchState(() {
        _productionRow = productionRow;
        _productionRows = productionRows.data;
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
        }
        if ((_videoDurationCtrl.text.trim().isEmpty ||
                int.tryParse(_videoDurationCtrl.text.trim()) == null) &&
            (productionRow.duration ?? '').trim().isNotEmpty) {
          _videoDurationCtrl.text = productionRow.duration!.trim();
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      _applyWorkbenchState(() {
        _productionError = normalizeStoryboardWorkbenchErrorMessage(
          e.toString(),
        );
        _setWorkbenchFailureNotice(
          actionSummary: '同步当前分镜制作数据失败。',
          recommendedAction:
              StoryboardWorkbenchRecommendedAction.syncProductionData,
          error: e,
          fallbackDetail: '可先检查当前分镜是否已在 production 侧生成，再重新同步。',
        );
      });
    } catch (e) {
      if (!mounted) return;
      _applyWorkbenchState(() {
        _productionError = normalizeStoryboardWorkbenchErrorMessage(
          e.toString(),
        );
        _setWorkbenchFailureNotice(
          actionSummary: '同步当前分镜制作数据失败。',
          recommendedAction:
              StoryboardWorkbenchRecommendedAction.syncProductionData,
          error: e,
          fallbackDetail: '可先检查当前分镜是否已在 production 侧生成，再重新同步。',
        );
      });
    } finally {
      if (mounted) {
        _applyWorkbenchState(() => _loadingProduction = false);
      }
    }
  }

  Future<void> _refreshWorkbenchData() async {
    _applyWorkbenchState(() {
      _loadingWorkbench = true;
      _setWorkbenchActionNotice(
        actionSummary: '正在刷新当前分镜的视频数据。',
        recommendedAction:
            StoryboardWorkbenchRecommendedAction.refreshVideoData,
        detail: '刷新完成后会同步模型信息、已生成视频和进行中的任务。',
      );
    });
    try {
      final model = await postWorkbenchGetVideoModelDetailV1(widget.token);
      final generateData = await postWorkbenchGetGenerateDataV1(
        widget.token,
        projectId: widget.projectNumericId,
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
    } on RustApiException catch (e) {
      if (!mounted) return;
      _applyWorkbenchState(() {
        _setWorkbenchFailureNotice(
          actionSummary: '刷新当前分镜的视频数据失败。',
          recommendedAction:
              StoryboardWorkbenchRecommendedAction.refreshVideoData,
          error: e,
          fallbackDetail: '可稍后重试，或先继续维护图片和轨道信息。',
        );
      });
    } catch (e) {
      if (!mounted) return;
      _applyWorkbenchState(() {
        _setWorkbenchFailureNotice(
          actionSummary: '刷新当前分镜的视频数据失败。',
          recommendedAction:
              StoryboardWorkbenchRecommendedAction.refreshVideoData,
          error: e,
          fallbackDetail: '可稍后重试，或先继续维护图片和轨道信息。',
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
