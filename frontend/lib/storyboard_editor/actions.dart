part of '../../home_page.dart';

/// Encapsulates storyboard workbench mutations so the main panel file
/// stays focused on state ownership and section composition.
extension _StoryboardWorkbenchActions on _StoryboardWorkbenchPanelState {
  Future<void> _runDialogAction(Future<void> Function() action) async {
    _applyWorkbenchState(() => _saving = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (!mounted) return;
      _showWorkbenchFailureSnackBar(
        actionSummary: '当前分镜操作失败。',
        recommendedAction: _currentDiagnosis().recommendedAction,
        error: e,
        fallbackDetail: '建议先完成当前推荐步骤后再重试。',
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      _showWorkbenchFailureSnackBar(
        actionSummary: '当前分镜操作失败。',
        recommendedAction: _currentDiagnosis().recommendedAction,
        error: e,
        fallbackDetail: '建议先完成当前推荐步骤后再重试。',
      );
    } finally {
      if (mounted) {
        _applyWorkbenchState(() => _saving = false);
      }
    }
  }

  Future<void> _submitVideoGeneration() async {
    final sourceImage = resolveStoryboardSourceImageUrl(
      productionStoryboard: _productionRow,
      draftImageUrl: _imageUrlCtrl.text,
    );
    if (sourceImage == null) {
      throw const FormatException('生成视频前需要先提供图片 URL 或当前预览图');
    }
    final trackId = int.tryParse(_trackIdCtrl.text.trim());
    if (trackId == null || trackId <= 0) {
      throw const FormatException('生成视频前请填写有效轨道 ID');
    }
    final duration = int.tryParse(_videoDurationCtrl.text.trim());
    if (duration == null || duration <= 0) {
      throw const FormatException('视频时长必须是正整数');
    }
    final prompt = _videoPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      throw const FormatException('视频提示词不能为空');
    }
    final negativePrompt = _negativeVideoPromptCtrl.text.trim();
    final response = await postProductionWorkbenchGenerateVideoV1(
      widget.token,
      projectId: widget.projectNumericId,
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
    final appliedNegativePrompt = response.storyboardNegativePrompts
        .where((item) => item.storyboardId == widget.storyNumericId)
        .map((item) => item.negativePrompt?.trim() ?? '')
        .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    _negativeVideoPromptCtrl.text = appliedNegativePrompt;
    if (!mounted) return;
    await _refreshWorkbenchData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(
        appliedNegativePrompt.isEmpty
            ? '已提交 ${response.total} 条视频任务。'
            : '已提交 ${response.total} 条视频任务，并回填最终负向提示词。',
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _saveVideoDescription() async {
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
            ? '已清空字幕/旁白文案，导出时会回退到分镜提示词。'
            : '已保存字幕/旁白文案，后续默认视频提示词和导出字幕会优先使用它。',
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _exportCurrentVideoJob() async {
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
      throw const FormatException('当前分镜还没有可导出的已选视频或候选视频 URL');
    }
    final job = await createJob(
      widget.token,
      'video.export',
      payload: <String, dynamic>{
        'source_url': sourceUrl,
        'format': 'mp4',
        'project_numeric_id': widget.projectNumericId,
        'storyboard_numeric_id': widget.storyNumericId,
      },
    );
    if (!mounted) return;
    _applyWorkbenchState(() {
      _latestExportJobId = job.id;
      _latestExportJob = job;
      _latestExportWritebackSynced = false;
      _setWorkbenchFollowUp(
        '已提交视频导出任务（job=${job.id}）。完成后会写回当前分镜视频 URL，可稍后刷新制作数据查看。',
      );
    });
  }

  Future<void> _notifyStoryboardMutated() async {
    final callback = widget.onStoryboardMutated;
    if (callback == null) {
      return;
    }
    await callback();
  }

  Future<void> _readCurrentPreview() async {
    final preview = await postStoryboardPreviewImageV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    _imageUrlCtrl.text = preview.imageUrl ?? '';
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(
        preview.imageUrl == null ? '当前分镜还没有可读取的预览图。' : '已读取当前分镜预览。',
      );
    });
  }

  Future<void> _saveImageUrl() async {
    final imageUrl = _imageUrlCtrl.text.trim();
    if (imageUrl.isEmpty) {
      throw const FormatException('图片 URL 不能为空');
    }
    final response = await postStoryboardUpdateUrlV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      imageUrl: imageUrl,
    );
    _imageUrlCtrl.text = response.imageUrl;
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp('已保存当前图片 URL。');
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _clearCurrentFrame() async {
    await postStoryboardRemoveFrameV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    _imageUrlCtrl.clear();
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp('已清空当前分镜画面。');
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _addTrack() async {
    final name = _trackNameCtrl.text.trim();
    if (name.isEmpty) throw const FormatException('轨道名称不能为空');
    final response = await postWorkbenchAddTrackV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      trackName: name,
    );
    _trackIdCtrl.text = response.trackId.toString();
    _trackNameCtrl.clear();
    await _refreshAll(syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(
      () => _setWorkbenchFollowUp('已新增轨道 #${response.trackId}。'),
    );
    await _notifyStoryboardMutated();
  }

  Future<void> _deleteTrack() async {
    final trackId = int.tryParse(_trackIdCtrl.text.trim());
    if (trackId == null || trackId <= 0) {
      throw const FormatException('请填写有效轨道 ID');
    }
    await postWorkbenchDeleteTrackV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      trackId: trackId,
    );
    if (_productionRow?.trackId == trackId) _trackIdCtrl.clear();
    await _refreshAll(syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(() => _setWorkbenchFollowUp('已删除轨道 #$trackId。'));
    await _notifyStoryboardMutated();
  }

  Future<void> _generateVideoPrompt() async {
    final request = buildStoryboardVideoPromptRequest(
      scriptStoryboard: widget.scriptStoryboard,
      productionStoryboard: _productionRow,
      draftNarration: widget.readVideoDescriptionText(),
      draftPrompt: widget.readPromptText(),
      draftDuration: _videoDurationCtrl.text,
    );
    final generated = await postWorkbenchGenerateVideoPromptV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      imageUrl: resolveStoryboardSourceImageUrl(
        productionStoryboard: _productionRow,
        draftImageUrl: _imageUrlCtrl.text,
      ),
      description: request.description,
      durationHint: request.durationSeconds,
    );
    _videoPromptCtrl.text = generated.prompt;
    _negativeVideoPromptCtrl.text = generated.negativePrompt ?? '';
    _videoDurationCtrl.text = generated.duration.toString();
    if (!mounted) return;
    _applyWorkbenchState(() => _setWorkbenchFollowUp('已生成默认视频提示词并回填时长。'));
  }

  Future<void> _selectVideo(VideoItem video) async {
    await postWorkbenchSelectVideoV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      videoUrl: video.videoUrl!.trim(),
    );
    await _refreshProductionData(syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(() => _setWorkbenchFollowUp('已将当前候选视频设为分镜视频。'));
    await _notifyStoryboardMutated();
  }

  Future<void> _deleteCurrentVideo() async {
    await postWorkbenchDeleteVideoV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    await _refreshProductionData(syncTrackId: true);
    await _refreshWorkbenchData();
    if (!mounted) return;
    _applyWorkbenchState(() => _setWorkbenchFollowUp('已删除当前分镜已选视频。'));
    await _notifyStoryboardMutated();
  }

  void _prepareVideoTrack(List<int> knownTrackIds) {
    _applyWorkbenchState(() {
      final currentTrackId = int.tryParse(_trackIdCtrl.text.trim());
      if (currentTrackId != null && currentTrackId > 0) {
        _setWorkbenchFollowUp('当前轨道 ID 已可直接用于视频生成。');
        return;
      }
      if (knownTrackIds.isNotEmpty) {
        _trackIdCtrl.text = knownTrackIds.first.toString();
        _setWorkbenchFollowUp('已回填轨道 ${knownTrackIds.first}，可继续确认视频参数。');
        return;
      }
      if (_trackNameCtrl.text.trim().isEmpty) {
        _trackNameCtrl.text = '分镜 ${widget.storyNumericId} 视频轨';
      }
      _setWorkbenchFollowUp('已预填新轨道名称，下一步可直接新增轨道。');
    });
  }

  Future<void> _syncProductionDataAction() async {
    await _refreshProductionData(syncImageUrl: true, syncTrackId: true);
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp('已同步当前分镜制作数据。');
    });
  }

  Future<void> _refreshVideoDataAction() async {
    await _refreshWorkbenchData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp('已刷新当前分镜的视频数据。');
    });
  }

  Future<void> _refreshProductionInputsAction() async {
    await _refreshProductionData(syncImageUrl: true, syncTrackId: true);
  }
}
