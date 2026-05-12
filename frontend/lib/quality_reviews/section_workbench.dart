part of 'section.dart';

/// 质量评审工作台，收拢筛选、统计、详情与手动创建。
class _QualityReviewsWorkbenchDialog extends StatefulWidget {
  const _QualityReviewsWorkbenchDialog({
    required this.accessToken,
    required this.initialProjectNumericId,
    required this.initialProjectScopeSummary,
    required this.initialReviews,
    required this.initialReviewDetails,
    required this.initialStatsSummary,
    required this.initialStagePassRateSummary,
  });

  final String accessToken;
  final int? initialProjectNumericId;
  final String? initialProjectScopeSummary;
  final List<QualityReview> initialReviews;
  final String? initialReviewDetails;
  final String? initialStatsSummary;
  final String? initialStagePassRateSummary;

  @override
  State<_QualityReviewsWorkbenchDialog> createState() =>
      _QualityReviewsWorkbenchDialogState();
}

class _QualityReviewsWorkbenchDialogState
    extends State<_QualityReviewsWorkbenchDialog> {
  late final _QualityReviewsWorkbenchControllers _ctrls;

  List<QualityReview> _reviews = const <QualityReview>[];
  List<StageGradeDistributionRow> _stageGradeRows =
      const <StageGradeDistributionRow>[];
  List<QualityTokenEfficiencyRow> _tokenEfficiencyRows =
      const <QualityTokenEfficiencyRow>[];
  String? _statsSummary;
  String? _scopeInsightsSummary;
  String? _tokenEfficiencySummary;
  String? _tokenEfficiencyActionPlan;
  String? _tokenEfficiencyExecutionChecklist;
  String? _tokenEfficiencySamplesSummary;
  String? _stagePassRateSummary;
  String? _badCaseStatsSummary;
  String? _reviewDetails;
  bool _loadingReviews = false;
  bool _loadingBadCases = false;
  bool _loadingStats = false;
  bool _loadingScopeInsights = false;
  bool _loadingTokenEfficiency = false;
  bool _loadingTokenEfficiencySamples = false;
  bool _loadingStagePassRate = false;
  bool _loadingBadCaseStats = false;
  bool _loadingReviewById = false;
  bool _creatingReview = false;
  bool _filterBadCasesOnly = false;
  bool _filterDeliveryPriorityOnly = false;
  bool _filterAutoSourceOnly = false;
  bool _createPassed = true;
  bool _createBadCase = false;
  String? _statusLine;

  String? get _stageFilterValue {
    final value = _ctrls.stageFilterCtrl.text.trim();
    return value.isEmpty || value == 'all' ? null : value;
  }

  String? get _gradeFilterValue {
    final value = _ctrls.gradeFilterCtrl.text.trim();
    return value.isEmpty || value == 'all' ? null : value;
  }

  String? _activeFilterQuerySummary() {
    final query = <String, String>{};
    final projectId = _ctrls.projectIdFilterCtrl.text.trim();
    final scriptId = _ctrls.scriptIdFilterCtrl.text.trim();
    final targetType = _ctrls.targetTypeFilterCtrl.text.trim();
    final targetId = _ctrls.targetIdFilterCtrl.text.trim();
    final jobId = _ctrls.jobIdFilterCtrl.text.trim();
    if (projectId.isNotEmpty) query['projectId'] = projectId;
    if (scriptId.isNotEmpty) query['scriptId'] = scriptId;
    if (targetType.isNotEmpty) query['targetType'] = targetType;
    if (targetId.isNotEmpty) query['targetId'] = targetId;
    if (jobId.isNotEmpty) query['jobId'] = jobId;
    if (_stageFilterValue != null) query['stage'] = _stageFilterValue!;
    if (_gradeFilterValue != null) query['grade'] = _gradeFilterValue!;
    if (_filterBadCasesOnly) query['isBadCase'] = 'true';
    if (_filterDeliveryPriorityOnly) {
      query['memoryDeliveryPriorityApplied'] = 'true';
    }
    if (_filterAutoSourceOnly) query['source'] = 'auto';
    if (query.isEmpty) return null;
    return query.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
  }

  String? _activeFilterRequestUrl() {
    final query = _activeFilterQuerySummary();
    if (query == null || query.isEmpty) return null;
    return '$kApiBaseUrl/api/v1/quality/reviews?$query';
  }

  @override
  void initState() {
    super.initState();
    _ctrls = _QualityReviewsWorkbenchControllers.create(
      initialProjectNumericId: widget.initialProjectNumericId,
    );
    _reviews = List<QualityReview>.from(widget.initialReviews);
    _statsSummary = widget.initialStatsSummary;
    _stagePassRateSummary = widget.initialStagePassRateSummary;
    _reviewDetails = widget.initialReviewDetails;
    _refreshExecutionChecklist();
    if (_reviews.isNotEmpty) {
      _ctrls.reviewIdCtrl.text = _reviews.first.id;
    }
  }

  @override
  void dispose() {
    _ctrls.dispose();
    super.dispose();
  }

  void _refreshExecutionChecklist() {
    _tokenEfficiencyExecutionChecklist = buildQualityScopedExecutionChecklist(
      reviews: _reviews,
      tokenRows: _tokenEfficiencyRows,
      projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
      scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
    );
  }

  Future<void> _loadReviews({
    required bool onlyBadCases,
    bool onlyDeliveryPriority = false,
    bool onlyAutoSource = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      if (onlyBadCases) {
        _loadingBadCases = true;
      } else {
        _loadingReviews = true;
      }
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityReviews(
        widget.accessToken,
        projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
        scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
        targetType: _ctrls.targetTypeFilterCtrl.text.trim(),
        targetId: _ctrls.targetIdFilterCtrl.text.trim(),
        jobId: _ctrls.jobIdFilterCtrl.text.trim(),
        source: onlyAutoSource ? 'auto' : null,
        isBadCase: onlyBadCases ? true : null,
        memoryDeliveryPriorityApplied: onlyDeliveryPriority ? true : null,
        stage: _stageFilterValue,
        grade: _gradeFilterValue,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _reviews = rows;
        _refreshExecutionChecklist();
        _filterBadCasesOnly = onlyBadCases;
        _filterDeliveryPriorityOnly = onlyDeliveryPriority;
        _filterAutoSourceOnly = onlyAutoSource;
        final labels = <String>[];
        if (onlyBadCases) labels.add(l10n.qualityReviewsFilterBadCase);
        if (onlyDeliveryPriority) {
          labels.add(l10n.qualityReviewsFilterDeliveryPriorityHit);
        }
        if (onlyAutoSource) labels.add('auto');
        if (_stageFilterValue != null) {
          labels.add(l10n.qualityReviewsFilterStage(_stageFilterValue!));
        }
        if (_gradeFilterValue != null) {
          labels.add(l10n.qualityReviewsFilterGrade(_gradeFilterValue!));
        }
        _statusLine = labels.isEmpty
            ? l10n.qualityReviewsStatusLoadedReviews(rows.length)
            : l10n.qualityReviewsStatusLoadedReviewsWithLabels(
                rows.length,
                labels.join(' + '),
              );
        if (_ctrls.reviewIdCtrl.text.trim().isEmpty && rows.isNotEmpty) {
          _ctrls.reviewIdCtrl.text = rows.first.id;
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          if (onlyBadCases) {
            _loadingBadCases = false;
          } else {
            _loadingReviews = false;
          }
        });
      }
    }
  }

  Future<void> _loadStats() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingStats = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityStats(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _statsSummary = summarizeQualityStatsRows(rows, l10n: l10n);
        _statusLine = l10n.qualityReviewsStatusRefreshedStats;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _loadScopeInsights() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingScopeInsights = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityScopeInsights(
        widget.accessToken,
        projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
        scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
        limit: 5,
      );
      if (!mounted) return;
      setState(() {
        _scopeInsightsSummary = summarizeQualityScopeInsightRows(rows);
        _statusLine = l10n.qualityReviewsStatusRefreshedScopeLeaderboard;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingScopeInsights = false);
      }
    }
  }

  Future<void> _loadStagePassRate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingStagePassRate = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityStagePassRate(widget.accessToken);
      final gradeRows = await fetchQualityStageGradeDistribution(
        widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _stagePassRateSummary = summarizeStagePassRateRows(rows, l10n: l10n);
        _stageGradeRows = gradeRows;
        _statusLine = l10n.qualityReviewsStatusRefreshedStageAndGrade;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingStagePassRate = false);
      }
    }
  }

  Future<void> _loadBadCaseStats() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingBadCaseStats = true;
      _statusLine = null;
    });
    try {
      final items = await fetchBadCaseStats(widget.accessToken, limit: 5);
      if (!mounted) return;
      setState(() {
        _badCaseStatsSummary = items.isEmpty
            ? l10n.qualityReviewsNoBadCaseData
            : items
                  .map(
                    (e) =>
                        l10n.qualityReviewsBadCaseStatsLine(
                          e.badCaseCategory ?? l10n.qualityReviewsUncategorized,
                          e.count,
                          e.passRatePercent.toStringAsFixed(1),
                        ),
                  )
                  .join(' | ');
        _statusLine = l10n.qualityReviewsStatusRefreshedBadCaseDistribution;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) setState(() => _loadingBadCaseStats = false);
    }
  }

  Future<void> _loadTokenEfficiency() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingTokenEfficiency = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityTokenEfficiency(
        widget.accessToken,
        projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
        scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _tokenEfficiencyRows = rows;
        _tokenEfficiencySummary = summarizeQualityTokenEfficiencyRows(
          rows,
          l10n: l10n,
        );
        _tokenEfficiencyActionPlan = summarizeQualityTokenEfficiencyActionPlan(
          rows,
          projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
          scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
        );
        _refreshExecutionChecklist();
        _statusLine = l10n.qualityReviewsStatusRefreshedTokenAggregate;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingTokenEfficiency = false);
      }
    }
  }

  Future<void> _loadTokenEfficiencySamples() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingTokenEfficiencySamples = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityTokenEfficiencySamples(
        widget.accessToken,
        projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
        scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
        limit: 4,
        targetType: _ctrls.targetTypeFilterCtrl.text.trim(),
        memoryDeliveryPriorityApplied: _filterDeliveryPriorityOnly
            ? true
            : null,
      );
      if (!mounted) return;
      setState(() {
        _tokenEfficiencySamplesSummary = summarizeQualityTokenEfficiencySamples(
          rows,
          l10n: l10n,
        );
        _statusLine = l10n.qualityReviewsStatusRefreshedTokenSavingSamples;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingTokenEfficiencySamples = false);
      }
    }
  }

  Future<void> _loadReviewById() async {
    final l10n = AppLocalizations.of(context)!;
    final reviewId = _ctrls.reviewIdCtrl.text.trim();
    if (reviewId.isEmpty) {
      setState(() => _statusLine = l10n.qualityReviewsErrInputReviewIdFirst);
      return;
    }
    setState(() {
      _loadingReviewById = true;
      _statusLine = null;
    });
    try {
      final review = await fetchQualityReviewById(widget.accessToken, reviewId);
      if (!mounted) return;
      setState(() {
        _reviewDetails = formatQualityReviewDetails(review, l10n: l10n);
        _statusLine = l10n.qualityReviewsStatusLoadedReviewDetails;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingReviewById = false);
      }
    }
  }

  Future<void> _createReview() async {
    final l10n = AppLocalizations.of(context)!;
    final targetType = _ctrls.createTargetTypeCtrl.text.trim();
    final source = _ctrls.createSourceCtrl.text.trim();
    final projectId = int.tryParse(_ctrls.createProjectIdCtrl.text.trim());
    final scriptId = int.tryParse(_ctrls.createScriptIdCtrl.text.trim());
    final score = int.tryParse(_ctrls.createScoreCtrl.text.trim());
    final rawTargetId = _ctrls.createTargetIdCtrl.text.trim();
    if (targetType.isEmpty || source.isEmpty) {
      setState(() => _statusLine = l10n.qualityReviewsErrTargetTypeSourceRequired);
      return;
    }
    if (scriptId != null && projectId == null) {
      setState(() => _statusLine = l10n.qualityReviewsErrScriptNeedsProject);
      return;
    }
    if (targetType == 'storyboard' &&
        (int.tryParse(rawTargetId) == null ||
            (int.tryParse(rawTargetId) ?? 0) <= 0)) {
      setState(
        () => _statusLine = l10n.qualityReviewsErrStoryboardTargetIdPositive,
      );
      return;
    }
    setState(() {
      _creatingReview = true;
      _statusLine = null;
    });
    try {
      final created = await createQualityReview(
        widget.accessToken,
        CreateQualityReviewBody(
          projectId: projectId,
          scriptId: scriptId,
          targetType: targetType,
          targetId: rawTargetId.isEmpty ? null : rawTargetId,
          source: source,
          overallScore: score,
          stage: _ctrls.createStageCtrl.text.trim().isEmpty
              ? null
              : _ctrls.createStageCtrl.text.trim(),
          grade: _ctrls.createGradeCtrl.text.trim().isEmpty
              ? null
              : _ctrls.createGradeCtrl.text.trim(),
          passed: _createPassed,
          comments: _ctrls.createCommentsCtrl.text.trim().isEmpty
              ? null
              : _ctrls.createCommentsCtrl.text.trim(),
          isBadCase: _createBadCase,
          badCaseCategory: _ctrls.createBadCaseCategoryCtrl.text.trim().isEmpty
              ? null
              : _ctrls.createBadCaseCategoryCtrl.text.trim(),
          modelName: 'manual',
          skillVersion: 'flutter.workbench',
          modelParams: const {'surface': 'quality_reviews_workbench'},
        ),
      );
      if (!mounted) return;
      setState(() {
        _ctrls.reviewIdCtrl.text = created.id;
        _reviewDetails = formatQualityReviewDetails(created, l10n: l10n);
        final writesScopedMemory =
            (projectId != null && scriptId != null) &&
            (_createBadCase ||
                (_createPassed == false && (score == null || score < 7)));
        _statusLine = writesScopedMemory
            ? l10n.qualityReviewsStatusCreatedWithScopedWriteback(created.id)
            : l10n.qualityReviewsStatusCreated(created.id);
      });
      await _loadReviews(
        onlyBadCases: _filterBadCasesOnly,
        onlyDeliveryPriority: _filterDeliveryPriorityOnly,
        onlyAutoSource: _filterAutoSourceOnly,
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _creatingReview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return QualityReviewsWorkbenchDialogView(
      model: QualityReviewsWorkbenchDialogViewModel(
        reviews: _reviews,
        statsSummary: _statsSummary,
        scopeInsightsSummary: _scopeInsightsSummary,
        tokenEfficiencySummary: _tokenEfficiencySummary,
        tokenEfficiencyActionPlan: _tokenEfficiencyActionPlan,
        tokenEfficiencyExecutionChecklist: _tokenEfficiencyExecutionChecklist,
        tokenEfficiencySamplesSummary: _tokenEfficiencySamplesSummary,
        stagePassRateSummary: _stagePassRateSummary,
        stageGradeRows: _stageGradeRows,
        badCaseStatsSummary: _badCaseStatsSummary,
        reviewDetails: _reviewDetails,
        statusLine: _statusLine,
        initialProjectScopeSummary: widget.initialProjectScopeSummary,
        activeFilterQuerySummary: _activeFilterQuerySummary(),
        activeFilterRequestUrl: _activeFilterRequestUrl(),
        filterBadCasesOnly: _filterBadCasesOnly,
        filterDeliveryPriorityOnly: _filterDeliveryPriorityOnly,
        filterAutoSourceOnly: _filterAutoSourceOnly,
        createPassed: _createPassed,
        createBadCase: _createBadCase,
        loadingReviews: _loadingReviews,
        loadingBadCases: _loadingBadCases,
        loadingStats: _loadingStats,
        loadingScopeInsights: _loadingScopeInsights,
        loadingTokenEfficiency: _loadingTokenEfficiency,
        loadingTokenEfficiencySamples: _loadingTokenEfficiencySamples,
        loadingStagePassRate: _loadingStagePassRate,
        loadingBadCaseStats: _loadingBadCaseStats,
        loadingReviewById: _loadingReviewById,
        creatingReview: _creatingReview,
        projectIdFilterCtrl: _ctrls.projectIdFilterCtrl,
        scriptIdFilterCtrl: _ctrls.scriptIdFilterCtrl,
        targetTypeFilterCtrl: _ctrls.targetTypeFilterCtrl,
        targetIdFilterCtrl: _ctrls.targetIdFilterCtrl,
        jobIdFilterCtrl: _ctrls.jobIdFilterCtrl,
        stageFilterCtrl: _ctrls.stageFilterCtrl,
        gradeFilterCtrl: _ctrls.gradeFilterCtrl,
        reviewIdCtrl: _ctrls.reviewIdCtrl,
        createProjectIdCtrl: _ctrls.createProjectIdCtrl,
        createScriptIdCtrl: _ctrls.createScriptIdCtrl,
        createTargetTypeCtrl: _ctrls.createTargetTypeCtrl,
        createTargetIdCtrl: _ctrls.createTargetIdCtrl,
        createSourceCtrl: _ctrls.createSourceCtrl,
        createScoreCtrl: _ctrls.createScoreCtrl,
        createStageCtrl: _ctrls.createStageCtrl,
        createGradeCtrl: _ctrls.createGradeCtrl,
        createCommentsCtrl: _ctrls.createCommentsCtrl,
        createBadCaseCategoryCtrl: _ctrls.createBadCaseCategoryCtrl,
      ),
      callbacks: QualityReviewsWorkbenchDialogViewCallbacks(
        onLoadReviews: () {
          _loadReviews(onlyBadCases: false, onlyDeliveryPriority: false);
        },
        onLoadBadCases: () {
          _loadReviews(
            onlyBadCases: true,
            onlyDeliveryPriority: _filterDeliveryPriorityOnly,
            onlyAutoSource: _filterAutoSourceOnly,
          );
        },
        onLoadDeliveryPriorityReviews: () {
          _loadReviews(
            onlyBadCases: _filterBadCasesOnly,
            onlyDeliveryPriority: true,
            onlyAutoSource: _filterAutoSourceOnly,
          );
        },
        onLoadAutoSourceReviews: () {
          _loadReviews(
            onlyBadCases: _filterBadCasesOnly,
            onlyDeliveryPriority: _filterDeliveryPriorityOnly,
            onlyAutoSource: true,
          );
        },
        onLoadStats: () {
          _loadStats();
        },
        onLoadScopeInsights: () {
          _loadScopeInsights();
        },
        onLoadTokenEfficiency: () {
          _loadTokenEfficiency();
        },
        onLoadTokenEfficiencySamples: () {
          _loadTokenEfficiencySamples();
        },
        onLoadStagePassRate: () {
          _loadStagePassRate();
        },
        onLoadBadCaseStats: () {
          _loadBadCaseStats();
        },
        onLoadReviewById: () {
          _loadReviewById();
        },
        onCreateReview: () {
          _createReview();
        },
        onCreatePassedChanged: (value) => setState(() => _createPassed = value),
        onCreateBadCaseChanged: (value) =>
            setState(() => _createBadCase = value),
        onSelectReview: (review) {
          setState(() {
            _ctrls.reviewIdCtrl.text = review.id;
            _reviewDetails = formatQualityReviewDetails(review, l10n: l10n);
          });
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
