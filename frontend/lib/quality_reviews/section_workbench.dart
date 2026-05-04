part of 'section.dart';

/// 质量评审工作台，收拢筛选、统计、详情与手动创建。
class _QualityReviewsWorkbenchDialog extends StatefulWidget {
  const _QualityReviewsWorkbenchDialog({
    required this.accessToken,
    required this.initialReviews,
    required this.initialReviewDetails,
    required this.initialStatsSummary,
    required this.initialStagePassRateSummary,
  });

  final String accessToken;
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
    _ctrls = _QualityReviewsWorkbenchControllers.create();
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
        if (onlyBadCases) labels.add('坏例');
        if (onlyDeliveryPriority) labels.add('命中表演/语气优先');
        if (onlyAutoSource) labels.add('auto');
        if (_stageFilterValue != null) labels.add('阶段 ${_stageFilterValue!}');
        if (_gradeFilterValue != null) labels.add('等级 ${_gradeFilterValue!}');
        _statusLine = labels.isEmpty
            ? '已加载 ${rows.length} 条评审'
            : '已加载 ${rows.length} 条${labels.join(" + ")}评审';
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
    setState(() {
      _loadingStats = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityStats(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _statsSummary = summarizeQualityStatsRows(rows);
        _statusLine = '已刷新质量统计';
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
        _statusLine = '已刷新 scope 榜单';
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
        _stagePassRateSummary = summarizeStagePassRateRows(rows);
        _stageGradeRows = gradeRows;
        _statusLine = '已刷新阶段通过率与等级分布';
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
    setState(() {
      _loadingBadCaseStats = true;
      _statusLine = null;
    });
    try {
      final items = await fetchBadCaseStats(widget.accessToken, limit: 5);
      if (!mounted) return;
      setState(() {
        _badCaseStatsSummary = items.isEmpty
            ? '暂无坏例数据'
            : items
                  .map(
                    (e) =>
                        '${e.badCaseCategory ?? "未分类"} ${e.count}条 pass=${e.passRatePercent.toStringAsFixed(1)}%',
                  )
                  .join(' | ');
        _statusLine = '已刷新坏例分布';
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = e.toString());
    } finally {
      if (mounted) setState(() => _loadingBadCaseStats = false);
    }
  }

  Future<void> _loadTokenEfficiency() async {
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
        _tokenEfficiencySummary = summarizeQualityTokenEfficiencyRows(rows);
        _tokenEfficiencyActionPlan = summarizeQualityTokenEfficiencyActionPlan(
          rows,
          projectId: int.tryParse(_ctrls.projectIdFilterCtrl.text.trim()),
          scriptId: int.tryParse(_ctrls.scriptIdFilterCtrl.text.trim()),
        );
        _refreshExecutionChecklist();
        _statusLine = '已刷新 token 聚合';
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
        );
        _statusLine = '已刷新省 token 样本';
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
    final reviewId = _ctrls.reviewIdCtrl.text.trim();
    if (reviewId.isEmpty) {
      setState(() => _statusLine = '请先输入评审 ID');
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
        _reviewDetails = formatQualityReviewDetails(review);
        _statusLine = '已读取评审详情';
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
    final targetType = _ctrls.createTargetTypeCtrl.text.trim();
    final source = _ctrls.createSourceCtrl.text.trim();
    final projectId = int.tryParse(_ctrls.createProjectIdCtrl.text.trim());
    final scriptId = int.tryParse(_ctrls.createScriptIdCtrl.text.trim());
    final score = int.tryParse(_ctrls.createScoreCtrl.text.trim());
    if (targetType.isEmpty || source.isEmpty) {
      setState(() => _statusLine = 'targetType 和 source 不能为空');
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
          targetId: _ctrls.createTargetIdCtrl.text.trim().isEmpty
              ? null
              : _ctrls.createTargetIdCtrl.text.trim(),
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
        _reviewDetails = formatQualityReviewDetails(created);
        final writesScopedMemory =
            (projectId != null && scriptId != null) &&
            (_createBadCase ||
                (_createPassed == false && (score == null || score < 7)));
        _statusLine = writesScopedMemory
            ? '已创建评审 ${created.id}，本条会回写项目/剧本隔离记忆'
            : '已创建评审 ${created.id}';
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
            _reviewDetails = formatQualityReviewDetails(review);
          });
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
