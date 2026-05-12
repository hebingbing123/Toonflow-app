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
    final repaired = _repairCurrentPromptFromDiagnostics();
    if (repaired == null) {
      return;
    }
    _applyWorkbenchState(() {
      _setWorkbenchActionNotice(
        actionSummary: repaired.changed ? '已应用当前生成前建议。' : '当前建议已经基本落实，无需再裁剪。',
        recommendedAction:
            StoryboardWorkbenchRecommendedAction.submitVideoGeneration,
        detail: repaired.changed
            ? '本次精简了 ${repaired.removedPromptFragmentCount} 条低收益提示词片段，并去掉 ${repaired.removedNegativeFragmentCount} 条重复负向约束。'
            : '当前分镜的 prompt/negative prompt 已经比较精简，可直接继续生成。',
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
    );
    _applyGeneratedVideoPrompt(
      generated,
      signature: _buildVideoPromptSignature(
        request: request,
        imageUrl: imageUrl,
      ),
    );
  }

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
    final sourceImage = _currentStoryboardSourceImage();
    if (sourceImage == null) {
      throw const FormatException('生成视频前需要先提供图片 URL 或当前预览图');
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
      throw const FormatException('生成视频前请填写有效轨道 ID');
    }
    final duration = int.tryParse(_videoDurationCtrl.text.trim());
    if (duration == null || duration <= 0) {
      throw const FormatException('视频时长必须是正整数');
    }
    await _refreshVideoPromptBeforeSubmitIfNeeded();
    final repairedBeforeSubmit = _repairCurrentPromptFromDiagnostics();
    final prompt = _videoPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      throw const FormatException('视频提示词不能为空');
    }
    final rawNegativePrompt = _negativeVideoPromptCtrl.text.trim();
    final compactedManualNegative = compactStoryboardManualNegativePrompt(
      manualPrompt: rawNegativePrompt,
      automaticPrompt: _lastGeneratedAutoNegativePrompt,
    );
    final negativePrompt = compactedManualNegative.manualPrompt.trim();
    final response = await postProductionWorkbenchGenerateVideoV1(
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
            ? repairedBeforeSubmit != null && repairedBeforeSubmit.changed
                  ? '已提交 ${response.total} 条视频任务，并在提交前自动精简 ${repairedBeforeSubmit.removedPromptFragmentCount} 条低收益 prompt 片段与 ${repairedBeforeSubmit.removedNegativeFragmentCount} 条重复负向约束。'
                  : compactedManualNegative.removedFragmentCount > 0
                  ? '已提交 ${response.total} 条视频任务，并自动剔除 ${compactedManualNegative.removedFragmentCount} 条重复负向约束。'
                  : '已提交 ${response.total} 条视频任务。'
            : repairedBeforeSubmit != null && repairedBeforeSubmit.changed
            ? '已提交 ${response.total} 条视频任务，提交前自动精简了 ${repairedBeforeSubmit.removedPromptFragmentCount} 条低收益 prompt 片段、${repairedBeforeSubmit.removedNegativeFragmentCount} 条重复负向约束，并回填最终负向提示词。'
            : compactedManualNegative.removedFragmentCount > 0
            ? '已提交 ${response.total} 条视频任务，自动剔除 ${compactedManualNegative.removedFragmentCount} 条重复负向约束，并回填最终负向提示词。'
            : '已提交 ${response.total} 条视频任务，并回填最终负向提示词。',
      );
    });
    await _notifyStoryboardMutated();
  }

  Future<void> _generateVoiceover() async {
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
            ? '已提交 ${response.total} 条配音任务，可稍后刷新制作数据查看状态。'
            : '已提交 ${response.total} 条配音任务（job=${queuedIds.first}），可稍后刷新制作数据查看状态。',
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
      _setWorkbenchFollowUp(
        '已提交视频导出任务（job=${job.id}）。完成后会写回当前分镜视频 URL，可稍后刷新制作数据查看。',
      );
    });
  }
}
