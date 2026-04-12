part of '../../home_page.dart';

class _StoryboardWorkbenchPanel extends StatefulWidget {
  const _StoryboardWorkbenchPanel({
    required this.token,
    required this.storyNumericId,
    required this.projectNumericId,
    required this.scriptNumericId,
    required this.scriptStoryboard,
    required this.readPromptText,
    required this.readVideoDescriptionText,
    this.onStoryboardMutated,
  });

  final String token;
  final int storyNumericId;
  final int projectNumericId;
  final int scriptNumericId;
  final StoryboardRow scriptStoryboard;
  final String Function() readPromptText;
  final String Function() readVideoDescriptionText;
  final Future<void> Function()? onStoryboardMutated;

  @override
  State<_StoryboardWorkbenchPanel> createState() =>
      _StoryboardWorkbenchPanelState();
}

class _StoryboardWorkbenchPanelState extends State<_StoryboardWorkbenchPanel> {
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _trackIdCtrl;
  late final TextEditingController _trackNameCtrl;
  late final TextEditingController _videoPromptCtrl;
  late final TextEditingController _videoDurationCtrl;

  bool _saving = false;
  bool _loadingProduction = false;
  bool _loadingWorkbench = false;
  ProductionStoryboardItemV1? _productionRow;
  List<ProductionStoryboardItemV1> _productionRows = const [];
  VideoModelDetail? _modelDetail;
  GetGenerateDataResponse? _generateData;
  String? _productionError;
  String? _workbenchLine;
  String _mode = 'standard';
  String _resolution = '1080p';
  bool _audio = false;

  StoryboardWorkbenchDiagnosis _currentDiagnosis() {
    return diagnoseStoryboardWorkbench(
      scriptStoryboard: widget.scriptStoryboard,
      productionStoryboard: _productionRow,
      productionStoryboards: _productionRows,
      generatedVideos: _generateData?.generatedVideos ?? const [],
      generatingJobs: _generateData?.generatingJobs ?? const [],
      draftImageUrl: _imageUrlCtrl.text,
      trackIdText: _trackIdCtrl.text,
      videoPromptText: _videoPromptCtrl.text,
      videoDurationText: _videoDurationCtrl.text,
    );
  }

  void _setWorkbenchFollowUp(String actionSummary) {
    _workbenchLine = buildStoryboardWorkbenchFollowUp(
      actionSummary: actionSummary,
      diagnosis: _currentDiagnosis(),
    );
  }

  void _setWorkbenchActionNotice({
    required String actionSummary,
    required StoryboardWorkbenchRecommendedAction recommendedAction,
    required String detail,
  }) {
    _workbenchLine = buildStoryboardWorkbenchActionNotice(
      actionSummary: actionSummary,
      recommendedAction: recommendedAction,
      detail: detail,
    );
  }

  void _setWorkbenchFailureNotice({
    required String actionSummary,
    required StoryboardWorkbenchRecommendedAction recommendedAction,
    required Object error,
    required String fallbackDetail,
  }) {
    _workbenchLine = buildStoryboardWorkbenchFailureNotice(
      actionSummary: actionSummary,
      recommendedAction: recommendedAction,
      error: error,
      fallbackDetail: fallbackDetail,
    );
  }

  void _showWorkbenchFailureSnackBar({
    required String actionSummary,
    required StoryboardWorkbenchRecommendedAction recommendedAction,
    required Object error,
    required String fallbackDetail,
  }) {
    final notice = buildStoryboardWorkbenchFailureNotice(
      actionSummary: actionSummary,
      recommendedAction: recommendedAction,
      error: error,
      fallbackDetail: fallbackDetail,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(notice)));
  }

  void _applyWorkbenchState(VoidCallback action) {
    setState(action);
  }

  @override
  void initState() {
    super.initState();
    _imageUrlCtrl = TextEditingController();
    _trackIdCtrl = TextEditingController();
    _trackNameCtrl = TextEditingController();
    _videoPromptCtrl = TextEditingController();
    _videoDurationCtrl = TextEditingController(text: '5');
    Future<void>.microtask(
      () => _refreshAll(syncImageUrl: true, syncTrackId: true),
    );
  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _trackIdCtrl.dispose();
    _trackNameCtrl.dispose();
    _videoPromptCtrl.dispose();
    _videoDurationCtrl.dispose();
    super.dispose();
  }

  String _storyboardProductionMetaLine(ProductionStoryboardItemV1? row) {
    if (row == null) return '制作视图尚未加载';
    final parts = <String>[
      if (row.sbIndex != null) '序号 ${row.sbIndex}',
      if ((row.state ?? '').trim().isNotEmpty) '状态 ${row.state}',
      if ((row.duration ?? '').trim().isNotEmpty) '时长 ${row.duration}',
      if (row.trackId != null) '轨道 ${row.trackId}',
    ];
    if (parts.isEmpty) {
      return '制作视图已加载';
    }
    return parts.join(' · ');
  }

  Future<void> _refreshProductionData({
    bool syncImageUrl = false,
    bool syncTrackId = false,
  }) async {
    setState(() {
      _loadingProduction = true;
      _productionError = null;
      _setWorkbenchActionNotice(
        actionSummary: '正在同步当前分镜制作数据。',
        recommendedAction: StoryboardWorkbenchRecommendedAction.syncProductionData,
        detail: '同步完成后会自动回填当前画面、轨道和可用视频参数。',
      );
    });
    try {
      final productionRow = await postStoryboardGetDataV1(
        widget.token,
        storyboardId: widget.storyNumericId,
      );
      final productionRows = await postProductionGetStoryboardDataV1(
        widget.token,
        projectId: widget.projectNumericId,
        scriptId: widget.scriptNumericId,
      );
      if (!mounted) return;
      setState(() {
        _productionRow = productionRow;
        _productionRows = productionRows.data;
        if (syncImageUrl) {
          _imageUrlCtrl.text = productionRow.url ?? '';
        }
        if (syncTrackId && productionRow.trackId != null) {
          _trackIdCtrl.text = productionRow.trackId!.toString();
        }
        if (_videoPromptCtrl.text.trim().isEmpty &&
            (productionRow.prompt ?? '').trim().isNotEmpty) {
          _videoPromptCtrl.text = productionRow.prompt!.trim();
        }
        if ((_videoDurationCtrl.text.trim().isEmpty ||
                int.tryParse(_videoDurationCtrl.text.trim()) == null) &&
            (productionRow.duration ?? '').trim().isNotEmpty) {
          _videoDurationCtrl.text = productionRow.duration!.trim();
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _productionError = normalizeStoryboardWorkbenchErrorMessage(
          e.toString(),
        );
        _setWorkbenchFailureNotice(
          actionSummary: '同步当前分镜制作数据失败。',
          recommendedAction: StoryboardWorkbenchRecommendedAction.syncProductionData,
          error: e,
          fallbackDetail: '可先检查当前分镜是否已在 production 侧生成，再重新同步。',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productionError = normalizeStoryboardWorkbenchErrorMessage(
          e.toString(),
        );
        _setWorkbenchFailureNotice(
          actionSummary: '同步当前分镜制作数据失败。',
          recommendedAction: StoryboardWorkbenchRecommendedAction.syncProductionData,
          error: e,
          fallbackDetail: '可先检查当前分镜是否已在 production 侧生成，再重新同步。',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingProduction = false);
      }
    }
  }

  Future<void> _refreshWorkbenchData() async {
    setState(() {
      _loadingWorkbench = true;
      _setWorkbenchActionNotice(
        actionSummary: '正在刷新当前分镜的视频数据。',
        recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
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
      setState(() {
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
      setState(() {
        _setWorkbenchFailureNotice(
          actionSummary: '刷新当前分镜的视频数据失败。',
          recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
          error: e,
          fallbackDetail: '可稍后重试，或先继续维护图片和轨道信息。',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _setWorkbenchFailureNotice(
          actionSummary: '刷新当前分镜的视频数据失败。',
          recommendedAction: StoryboardWorkbenchRecommendedAction.refreshVideoData,
          error: e,
          fallbackDetail: '可稍后重试，或先继续维护图片和轨道信息。',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loadingWorkbench = false);
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

  void _setResolutionValue(String value) {
    setState(() => _resolution = value);
  }

  void _setModeValue(String value) {
    setState(() => _mode = value);
  }

  void _setAudioValue(bool value) {
    setState(() => _audio = value);
  }

  ({VoidCallback? recommendedAction, String recommendedActionLabel})
  _recommendedActionState(
    StoryboardWorkbenchDiagnosis diagnosis,
    List<int> knownTrackIds,
  ) {
    VoidCallback? recommendedAction;
    var recommendedActionLabel =
        describeStoryboardWorkbenchRecommendedAction(
          diagnosis.recommendedAction,
        );
    switch (diagnosis.recommendedAction) {
      case StoryboardWorkbenchRecommendedAction.syncProductionData:
        recommendedAction = _saving || _loadingProduction
            ? null
            : () => _runDialogAction(_syncProductionDataAction);
      case StoryboardWorkbenchRecommendedAction.readCurrentPreview:
        recommendedAction = _saving
            ? null
            : () => _runDialogAction(_readCurrentPreview);
      case StoryboardWorkbenchRecommendedAction.prepareVideoTrack:
        recommendedAction = _saving ? null : () => _prepareVideoTrack(knownTrackIds);
      case StoryboardWorkbenchRecommendedAction.generateDefaultVideoPrompt:
        recommendedAction = _saving
            ? null
            : () => _runDialogAction(_generateVideoPrompt);
      case StoryboardWorkbenchRecommendedAction.refreshVideoData:
        recommendedAction = _saving || _loadingWorkbench
            ? null
            : () => _runDialogAction(_refreshVideoDataAction);
        if (_loadingWorkbench) {
          recommendedActionLabel = '刷新中…';
        }
      case StoryboardWorkbenchRecommendedAction.submitVideoGeneration:
        recommendedAction = _saving
            ? null
            : () => _runDialogAction(_submitVideoGeneration);
        if (_saving) {
          recommendedActionLabel = '提交中…';
        }
    }
    return (
      recommendedAction: recommendedAction,
      recommendedActionLabel: recommendedActionLabel,
    );
  }

  ({
    List<int> knownTrackIds,
    List<VideoItem> storyboardVideos,
    StoryboardWorkbenchDiagnosis diagnosis,
    VoidCallback? recommendedAction,
    String recommendedActionLabel,
  })
  _buildWorkbenchViewState() {
    final knownTrackIds = _knownTrackIds();
    final storyboardVideos = _storyboardVideos();
    final diagnosis = _currentDiagnosis();
    final recommended = _recommendedActionState(diagnosis, knownTrackIds);
    return (
      knownTrackIds: knownTrackIds,
      storyboardVideos: storyboardVideos,
      diagnosis: diagnosis,
      recommendedAction: recommended.recommendedAction,
      recommendedActionLabel: recommended.recommendedActionLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewState = _buildWorkbenchViewState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoryboardPreviewCard(
          loadingProduction: _loadingProduction,
          productionRow: _productionRow,
          metaLine: _storyboardProductionMetaLine(_productionRow),
        ),
        const SizedBox(height: 12),
        _StoryboardDiagnosisCard(
          diagnosis: viewState.diagnosis,
          recommendedAction: viewState.recommendedAction,
          recommendedActionLabel: viewState.recommendedActionLabel,
        ),
        if (_productionError != null) ...[
          const SizedBox(height: 8),
          Text(
            _productionError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _StoryboardImageSection(
          saving: _saving,
          loadingProduction: _loadingProduction,
          imageUrlCtrl: _imageUrlCtrl,
          onReadCurrentPreview: () => _runDialogAction(_readCurrentPreview),
          onSaveImageUrl: () => _runDialogAction(_saveImageUrl),
          onClearFrame: () => _runDialogAction(_clearCurrentFrame),
          onRefreshProductionData: _refreshProductionInputsAction,
        ),
        const SizedBox(height: 16),
        _StoryboardVideoSection(
          saving: _saving,
          loadingWorkbench: _loadingWorkbench,
          trackIdCtrl: _trackIdCtrl,
          trackNameCtrl: _trackNameCtrl,
          videoPromptCtrl: _videoPromptCtrl,
          videoDurationCtrl: _videoDurationCtrl,
          resolution: _resolution,
          mode: _mode,
          audio: _audio,
          modelDetail: _modelDetail,
          generateData: _generateData,
          productionRow: _productionRow,
          workbenchLine: _workbenchLine,
          knownTrackIds: viewState.knownTrackIds,
          storyboardVideos: viewState.storyboardVideos,
          onResolutionChanged: _setResolutionValue,
          onModeChanged: _setModeValue,
          onAudioChanged: _setAudioValue,
          onAddTrack: () => _runDialogAction(_addTrack),
          onDeleteTrack: () => _runDialogAction(_deleteTrack),
          onGenerateVideoPrompt: () => _runDialogAction(_generateVideoPrompt),
          onRefreshVideoData: _refreshWorkbenchData,
          onSubmitVideoGeneration: () =>
              _runDialogAction(_submitVideoGeneration),
          onSelectVideo: (video) => _runDialogAction(() => _selectVideo(video)),
          onDeleteCurrentVideo: () => _runDialogAction(_deleteCurrentVideo),
        ),
      ],
    );
  }
}
