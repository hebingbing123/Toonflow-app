part of '../../home_page.dart';

class _StoryboardWorkbenchPanel extends StatefulWidget {
  const _StoryboardWorkbenchPanel({
    required this.token,
    required this.projectId,
    required this.storyNumericId,
    required this.scriptNumericId,
    required this.scriptStoryboard,
    required this.readPromptText,
    required this.readVideoDescriptionText,
    required this.videoDescriptionCtrl,
    this.onStoryboardMutated,
  });

  final String token;
  final String projectId;
  final int storyNumericId;
  final int scriptNumericId;
  final StoryboardRow scriptStoryboard;
  final String Function() readPromptText;
  final String Function() readVideoDescriptionText;
  final TextEditingController videoDescriptionCtrl;
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
  late final TextEditingController _negativeVideoPromptCtrl;
  late final TextEditingController _videoDurationCtrl;
  late final TextEditingController _liveActionReferenceShotsCtrl;
  late final TextEditingController _liveActionPerformanceNotesCtrl;

  bool _saving = false;
  bool _loadingProduction = false;
  bool _loadingWorkbench = false;
  bool _loadingExportJob = false;
  StoryboardShortVideoReadiness? _storyboardShotReadiness;
  String? _cachedStoryboardListDataVersion;
  List<ProjectCharacterV1> _projectCharacters = const [];
  bool _loadingCharacters = false;
  ProductionStoryboardItemV1? _productionRow;
  List<ProductionStoryboardItemV1> _productionRows = const [];
  VideoModelDetail? _modelDetail;
  GetGenerateDataResponse? _generateData;
  String? _latestExportJobId;
  JobRow? _latestExportJob;
  bool _latestExportWritebackSynced = false;
  String? _productionError;
  String? _workbenchLine;
  String? _lastGeneratedVideoPromptText;
  String? _lastGeneratedVideoPromptSignature;
  String? _lastGeneratedAutoNegativePrompt;
  GenerateVideoPromptDiagnostics? _lastGeneratedVideoPromptDiagnostics;
  bool _videoPromptEditedAfterAutoGenerate = false;
  bool _syncingGeneratedVideoPrompt = false;
  String _mode = 'standard';
  String _resolution = '1080p';
  bool _audio = false;
  bool _autoQualityReviewOnGeneratePrompt = false;

  StoryboardWorkbenchDiagnosis _currentDiagnosis() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return diagnoseStoryboardWorkbench(
      l10n,
      scriptStoryboard: widget.scriptStoryboard,
      productionStoryboard: _productionRow,
      productionStoryboards: _productionRows,
      generatedVideos: _generateData?.generatedVideos ?? const [],
      generatingJobs: _generateData?.generatingJobs ?? const [],
      videoWritebackSummary: _generateData?.videoWritebackSummary,
      draftImageUrl: _imageUrlCtrl.text,
      trackIdText: _trackIdCtrl.text,
      videoPromptText: _videoPromptCtrl.text,
      videoDurationText: _videoDurationCtrl.text,
    );
  }

  void _setWorkbenchFollowUp(String actionSummary) {
    final l10n = resolveAppLocalizationsForErrors(context);
    _workbenchLine = buildStoryboardWorkbenchFollowUp(
      l10n,
      actionSummary: actionSummary,
      diagnosis: _currentDiagnosis(),
    );
  }

  void _setWorkbenchActionNotice({
    required String actionSummary,
    required StoryboardWorkbenchRecommendedAction recommendedAction,
    required String detail,
  }) {
    final l10n = resolveAppLocalizationsForErrors(context);
    _workbenchLine = buildStoryboardWorkbenchActionNotice(
      l10n,
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
    final l10n = resolveAppLocalizationsForErrors(context);
    _workbenchLine = buildStoryboardWorkbenchFailureNotice(
      l10n,
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final notice = buildStoryboardWorkbenchFailureNotice(
      l10n,
      actionSummary: actionSummary,
      recommendedAction: recommendedAction,
      error: error,
      fallbackDetail: fallbackDetail,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
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
    _negativeVideoPromptCtrl = TextEditingController();
    _videoDurationCtrl = TextEditingController(text: '5');
    _liveActionReferenceShotsCtrl = TextEditingController();
    _liveActionPerformanceNotesCtrl = TextEditingController();
    _videoPromptCtrl.addListener(_handleVideoPromptChanged);
    Future<void>.microtask(() async {
      await _refreshAll(syncImageUrl: true, syncTrackId: true);
      if (!mounted) return;
      await _loadWorkbenchCharacters();
    });
  }

  @override
  void dispose() {
    _videoPromptCtrl.removeListener(_handleVideoPromptChanged);
    _imageUrlCtrl.dispose();
    _trackIdCtrl.dispose();
    _trackNameCtrl.dispose();
    _videoPromptCtrl.dispose();
    _negativeVideoPromptCtrl.dispose();
    _videoDurationCtrl.dispose();
    _liveActionReferenceShotsCtrl.dispose();
    _liveActionPerformanceNotesCtrl.dispose();
    super.dispose();
  }

  void _handleVideoPromptChanged() {
    if (_syncingGeneratedVideoPrompt) {
      return;
    }
    final generated = _lastGeneratedVideoPromptText?.trim();
    if (generated == null || generated.isEmpty) {
      _videoPromptEditedAfterAutoGenerate = false;
      return;
    }
    _videoPromptEditedAfterAutoGenerate =
        _videoPromptCtrl.text.trim() != generated;
  }

  GenerateVideoPromptDiagnostics? _visiblePromptDiagnostics() {
    final diagnostics = _lastGeneratedVideoPromptDiagnostics;
    final generated = _lastGeneratedVideoPromptText?.trim();
    if (diagnostics == null || generated == null || generated.isEmpty) {
      return null;
    }
    if (_videoPromptCtrl.text.trim() != generated) {
      return null;
    }
    return diagnostics;
  }

  String _storyboardProductionMetaLine(
    AppLocalizations l10n,
    ProductionStoryboardItemV1? row,
  ) {
    if (row == null) return l10n.storyboardWorkbenchProductionMetaNotLoaded;
    final parts = <String>[
      if (row.sbIndex != null)
        l10n.storyboardWorkbenchProductionMetaSbIndex(row.sbIndex!),
      if ((row.state ?? '').trim().isNotEmpty)
        l10n.storyboardWorkbenchProductionMetaState(row.state!.trim()),
      if ((row.duration ?? '').trim().isNotEmpty)
        l10n.storyboardWorkbenchProductionMetaDuration(row.duration!.trim()),
      if (row.trackId != null)
        l10n.storyboardWorkbenchProductionMetaTrack(row.trackId!),
    ];
    if (parts.isEmpty) {
      return l10n.storyboardWorkbenchProductionMetaLoadedEmpty;
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final viewState = _buildWorkbenchViewState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoryboardPreviewCard(
          loadingProduction: _loadingProduction,
          scriptStoryboard: widget.scriptStoryboard,
          productionRow: _productionRow,
          metaLine: _storyboardProductionMetaLine(l10n, _productionRow),
        ),
        if (_storyboardShotReadiness != null) ...[
          const SizedBox(height: 12),
          _StoryboardShortVideoReadinessStrip(
            readiness: _storyboardShotReadiness!,
          ),
        ],
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
        const SizedBox(height: 12),
        _StoryboardCharacterSection(
          saving: _saving,
          loadingCharacters: _loadingCharacters,
          characters: _projectCharacters,
          selectedCharacterId: _productionRow?.characterId,
          onCharacterChanged: (characterId) =>
              _runDialogAction(() => _saveStoryboardCharacter(characterId)),
          onReloadCharacters: _loadWorkbenchCharacters,
        ),
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
          videoDescriptionCtrl: widget.videoDescriptionCtrl,
          videoPromptCtrl: _videoPromptCtrl,
          negativeVideoPromptCtrl: _negativeVideoPromptCtrl,
          videoDurationCtrl: _videoDurationCtrl,
          liveActionReferenceShotsCtrl: _liveActionReferenceShotsCtrl,
          liveActionPerformanceNotesCtrl: _liveActionPerformanceNotesCtrl,
          resolution: _resolution,
          mode: _mode,
          audio: _audio,
          autoQualityReviewOnGeneratePrompt: _autoQualityReviewOnGeneratePrompt,
          modelDetail: _modelDetail,
          generateData: _generateData,
          productionRow: _productionRow,
          currentSelectedVideoUrl: widget.scriptStoryboard.filePath,
          workbenchLine: _workbenchLine,
          promptDiagnostics: _visiblePromptDiagnostics(),
          knownTrackIds: viewState.knownTrackIds,
          storyboardVideos: viewState.storyboardVideos,
          onResolutionChanged: _setResolutionValue,
          onModeChanged: _setModeValue,
          onAudioChanged: _setAudioValue,
          onAutoQualityReviewOnGeneratePromptChanged: (value) =>
              _applyWorkbenchState(() {
                _autoQualityReviewOnGeneratePrompt = value;
              }),
          onAddTrack: () => _runDialogAction(_addTrack),
          onDeleteTrack: () => _runDialogAction(_deleteTrack),
          onGenerateVideoPrompt: () => _runDialogAction(_generateVideoPrompt),
          onGenerateVoiceover: () => _runDialogAction(_generateVoiceover),
          onSaveLiveActionReference: () =>
              _runDialogAction(_saveLiveActionReference),
          onOpenPatchRegeneration: _openPatchRegenerationDialog,
          onApplyPromptRepairs: _applyPromptRepairSuggestions,
          onRefreshVideoData: _refreshWorkbenchData,
          loadingExportJob: _loadingExportJob,
          latestExportJob: _latestExportJob,
          onSubmitVideoGeneration: () =>
              _runDialogAction(_submitVideoGeneration),
          onSaveVideoDescription: () => _runDialogAction(_saveVideoDescription),
          onExportCurrentVideo: () => _runDialogAction(_exportCurrentVideoJob),
          onRefreshExportJob: () => _runDialogAction(_refreshExportJobStatus),
          onSelectVideo: (video) => _runDialogAction(() => _selectVideo(video)),
          onDeleteCurrentVideo: () => _runDialogAction(_deleteCurrentVideo),
        ),
      ],
    );
  }
}
