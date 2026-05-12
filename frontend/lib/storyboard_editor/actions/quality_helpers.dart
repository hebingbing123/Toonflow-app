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
    final preview = await postStoryboardPreviewImageV1(
      widget.token,
      projectId: widget.projectNumericId,
      projectUuid: widget.projectId,
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
      projectUuid: widget.projectId,
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

  Future<void> _saveLiveActionReference() async {
    final referenceShotUrls = _liveActionReferenceShotsCtrl.text
        .split(RegExp(r'[\n,]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final performanceNotes = _liveActionPerformanceNotesCtrl.text.trim();
    final response = await postStoryboardUpdateLiveActionReferenceV1(
      widget.token,
      projectId: widget.projectNumericId,
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
            ? '已清空真人参考镜头与表演约束。'
            : '已保存 $count 条真人参考镜头，并同步表演/口播约束。',
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _clearCurrentFrame() async {
    await postStoryboardRemoveFrameV1(
      widget.token,
      projectId: widget.projectNumericId,
      projectUuid: widget.projectId,
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
      projectUuid: widget.projectId,
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
      projectUuid: widget.projectId,
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
    final request = _buildCurrentVideoPromptRequest();
    final imageUrl = _currentStoryboardSourceImage();
    final generated = await postWorkbenchGenerateVideoPromptV1(
      widget.token,
      projectId: widget.projectNumericId,
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
      generated.diagnostics,
      observationNote: generated.observationNote,
    );
    _applyWorkbenchState(() => _setWorkbenchFollowUp(followUp));
  }

  Future<void> _selectVideo(VideoItem video) async {
    final media = await postWorkbenchStoryboardMediaOpV1(
      widget.token,
      buildStoryboardMediaOpBodyV1(
        base: <String, dynamic>{
          'op': 'selectVideo',
          'scriptId': widget.scriptNumericId,
          'storyboardId': widget.storyNumericId,
          'videoUrl': video.videoUrl!.trim(),
        },
        projectId: widget.projectNumericId,
        projectUuid: widget.projectId,
      ),
    );
    final response = media.selectVideo!;
    await _refreshProductionData(syncTrackId: true);
    if (!mounted) return;
    final memorySummary = response.selectedMemory == null
        ? '已将当前候选视频设为分镜视频。'
        : '已将当前候选视频设为分镜视频。${describeStoryboardSelectedMemoryFeedback(response.selectedMemory!)}';
    _applyWorkbenchState(() => _setWorkbenchFollowUp(memorySummary));
    await _notifyStoryboardMutated();
  }

  Future<void> _deleteCurrentVideo() async {
    final response = await postWorkbenchDeleteVideoV1(
      widget.token,
      projectId: widget.projectNumericId,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
    );
    await _refreshProductionData(syncTrackId: true);
    await _refreshWorkbenchData();
    if (!mounted) return;
    final followUp = response.negativeMemory == null
        ? '已删除当前分镜已选视频。'
        : '已删除当前分镜已选视频。${describeStoryboardRejectedMemoryFeedback(response.negativeMemory!)}';
    _applyWorkbenchState(() => _setWorkbenchFollowUp(followUp));
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
