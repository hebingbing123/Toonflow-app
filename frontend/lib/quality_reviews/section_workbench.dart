part of 'section.dart';

/// 质量评审工作台，收拢筛选、统计、详情与手动创建。
class _QualityReviewsWorkbenchDialog extends StatefulWidget {
  const _QualityReviewsWorkbenchDialog({
    required this.accessToken,
    required this.initialReviews,
    required this.initialReviewDetails,
    required this.initialStatsSummary,
    required this.initialStagePassRateSummary,
    required this.initialTokenEfficiencySummary,
  });

  final String accessToken;
  final List<QualityReview> initialReviews;
  final String? initialReviewDetails;
  final String? initialStatsSummary;
  final String? initialStagePassRateSummary;
  final String? initialTokenEfficiencySummary;

  @override
  State<_QualityReviewsWorkbenchDialog> createState() =>
      _QualityReviewsWorkbenchDialogState();
}

class _QualityReviewsWorkbenchDialogState
    extends State<_QualityReviewsWorkbenchDialog> {
  late final _QualityReviewsWorkbenchControllers _ctrls;

  List<QualityReview> _reviews = const <QualityReview>[];
  String? _statsSummary;
  String? _stagePassRateSummary;
  String? _tokenEfficiencySummary;
  String? _reviewDetails;
  bool _loadingReviews = false;
  bool _loadingBadCases = false;
  bool _loadingStats = false;
  bool _loadingStagePassRate = false;
  bool _loadingTokenEfficiency = false;
  bool _loadingReviewById = false;
  bool _creatingReview = false;
  bool _filterBadCasesOnly = false;
  bool _filterDeliveryPriorityOnly = false;
  bool _filterAutoSourceOnly = false;
  bool _createPassed = true;
  bool _createBadCase = false;
  String? _statusLine;

  @override
  void initState() {
    super.initState();
    _ctrls = _QualityReviewsWorkbenchControllers.create();
    _reviews = List<QualityReview>.from(widget.initialReviews);
    _statsSummary = widget.initialStatsSummary;
    _stagePassRateSummary = widget.initialStagePassRateSummary;
    _tokenEfficiencySummary = widget.initialTokenEfficiencySummary;
    _reviewDetails = widget.initialReviewDetails;
    if (_reviews.isNotEmpty) {
      _ctrls.reviewIdCtrl.text = _reviews.first.id;
    }
  }

  @override
  void dispose() {
    _ctrls.dispose();
    super.dispose();
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
        targetType: _ctrls.targetTypeFilterCtrl.text.trim(),
        targetId: _ctrls.targetIdFilterCtrl.text.trim(),
        jobId: _ctrls.jobIdFilterCtrl.text.trim(),
        source: onlyAutoSource ? 'auto' : null,
        isBadCase: onlyBadCases ? true : null,
        memoryDeliveryPriorityApplied: onlyDeliveryPriority ? true : null,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _reviews = rows;
        _filterBadCasesOnly = onlyBadCases;
        _filterDeliveryPriorityOnly = onlyDeliveryPriority;
        _filterAutoSourceOnly = onlyAutoSource;
        final labels = <String>[];
        if (onlyBadCases) labels.add('坏例');
        if (onlyDeliveryPriority) labels.add('命中表演/语气优先');
        if (onlyAutoSource) labels.add('auto');
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

  Future<void> _loadStagePassRate() async {
    setState(() {
      _loadingStagePassRate = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityStagePassRate(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _stagePassRateSummary = summarizeStagePassRateRows(rows);
        _statusLine = '已刷新阶段通过率';
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

  Future<void> _loadTokenEfficiency() async {
    setState(() {
      _loadingTokenEfficiency = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchQualityTokenEfficiency(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _tokenEfficiencySummary = summarizeQualityTokenEfficiencyRows(rows);
        _statusLine = '已刷新 token 效率';
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
          targetType: targetType,
          targetId: _ctrls.createTargetIdCtrl.text.trim().isEmpty
              ? null
              : _ctrls.createTargetIdCtrl.text.trim(),
          source: source,
          overallScore: score,
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
        _statusLine = '已创建评审 ${created.id}';
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
        stagePassRateSummary: _stagePassRateSummary,
        tokenEfficiencySummary: _tokenEfficiencySummary,
        reviewDetails: _reviewDetails,
        statusLine: _statusLine,
        filterBadCasesOnly: _filterBadCasesOnly,
        filterDeliveryPriorityOnly: _filterDeliveryPriorityOnly,
        filterAutoSourceOnly: _filterAutoSourceOnly,
        createPassed: _createPassed,
        createBadCase: _createBadCase,
        loadingReviews: _loadingReviews,
        loadingBadCases: _loadingBadCases,
        loadingStats: _loadingStats,
        loadingStagePassRate: _loadingStagePassRate,
        loadingTokenEfficiency: _loadingTokenEfficiency,
        loadingReviewById: _loadingReviewById,
        creatingReview: _creatingReview,
        targetTypeFilterCtrl: _ctrls.targetTypeFilterCtrl,
        targetIdFilterCtrl: _ctrls.targetIdFilterCtrl,
        jobIdFilterCtrl: _ctrls.jobIdFilterCtrl,
        reviewIdCtrl: _ctrls.reviewIdCtrl,
        createTargetTypeCtrl: _ctrls.createTargetTypeCtrl,
        createTargetIdCtrl: _ctrls.createTargetIdCtrl,
        createSourceCtrl: _ctrls.createSourceCtrl,
        createScoreCtrl: _ctrls.createScoreCtrl,
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
        onLoadStagePassRate: () {
          _loadStagePassRate();
        },
        onLoadTokenEfficiency: () {
          _loadTokenEfficiency();
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
