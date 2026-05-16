part of 'section.dart';

/// Quality review workbench: filters, stats, detail, and manual creation.
class _QualityReviewsWorkbenchDialog extends StatefulWidget {
  const _QualityReviewsWorkbenchDialog({
    required this.accessToken,
    required this.initialProjectNumericId,
    required this.initialProjectUuid,
    required this.initialProjectScopeSummary,
    required this.initialReviews,
    required this.initialReviewDetails,
    required this.initialStatsSummary,
    required this.initialStagePassRateSummary,
    required this.onNavigateDomainDeepLink,
  });

  final String accessToken;
  final int? initialProjectNumericId;
  final String? initialProjectUuid;
  final String? initialProjectScopeSummary;
  final List<QualityReview> initialReviews;
  final String? initialReviewDetails;
  final String? initialStatsSummary;
  final String? initialStagePassRateSummary;
  final void Function(TaskCenterDomainDeepLink link)? onNavigateDomainDeepLink;

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
  List<BadCaseStatItem> _badCaseStatItems = const <BadCaseStatItem>[];
  String? _reviewDetails;
  QualityReview? _selectedReview;
  Map<String, int>? _createDimensionScores;
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

  String? get _suggestedActionFilterValue {
    final value = _ctrls.suggestedActionFilterCtrl.text.trim();
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
    if (_suggestedActionFilterValue != null) {
      query['suggestedAction'] = _suggestedActionFilterValue!;
    }
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

  int? _qualityReviewStoryboardId(QualityReview review) {
    final targetId = review.targetId?.trim();
    final storyboardId = targetId == null ? null : int.tryParse(targetId);
    if (storyboardId != null && storyboardId > 0) {
      return storyboardId;
    }
    final diagnostics = review.modelParams?['diagnostics'];
    if (diagnostics is Map<String, dynamic>) {
      final scopedId = diagnostics['storyboardId'];
      if (scopedId is num && scopedId.toInt() > 0) {
        return scopedId.toInt();
      }
      if (scopedId is String) {
        final parsed = int.tryParse(scopedId);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    return null;
  }

  String? _qualityReviewProjectUuid(QualityReview review) {
    final projectUuid = widget.initialProjectUuid?.trim();
    if (projectUuid == null || projectUuid.isEmpty) {
      return null;
    }
    if (review.projectId != null &&
        widget.initialProjectNumericId != null &&
        review.projectId == widget.initialProjectNumericId) {
      return projectUuid;
    }
    return null;
  }

  TaskCenterDomainDeepLink? _buildSuggestedActionLink(QualityReview review) {
    final action = review.suggestedAction?.trim();
    final projectId = review.projectId ?? widget.initialProjectNumericId;
    final projectUuid = _qualityReviewProjectUuid(review);
    final scriptId = review.scriptId;
    final storyboardId = _qualityReviewStoryboardId(review);
    if (projectId == null && projectUuid == null) {
      return null;
    }
    final storyboardScopedActions = <String>{
      'update_character_anchor',
      'patch_storyboard_items',
      'adjust_video_prompt',
      'retry_video_generation',
      'regenerate_storyboard',
    };
    if (action != null &&
        storyboardScopedActions.contains(action) &&
        storyboardId != null) {
      return TaskCenterDomainDeepLink(
        target: TaskCenterDomainDeepLinkTarget.storyboard,
        projectNumericId: projectId,
        projectUuid: projectUuid,
        scriptNumericId: scriptId,
        storyboardNumericId: storyboardId,
        stage: review.stage?.trim(),
        suggestedAction: action,
      );
    }
    if (scriptId != null) {
      return TaskCenterDomainDeepLink(
        target: TaskCenterDomainDeepLinkTarget.script,
        projectNumericId: projectId,
        projectUuid: projectUuid,
        scriptNumericId: scriptId,
        storyboardNumericId: storyboardId,
        stage: review.stage?.trim(),
        suggestedAction: action,
      );
    }
    return TaskCenterDomainDeepLink(
      target: TaskCenterDomainDeepLinkTarget.project,
      projectNumericId: projectId,
      projectUuid: projectUuid,
      storyboardNumericId: storyboardId,
      stage: review.stage?.trim(),
      suggestedAction: action,
    );
  }

  String _buildSuggestedActionClipboardSummary(
    dynamic l10n,
    QualityReview review,
  ) {
    final parts = <String>[
      'suggestedAction=${review.suggestedAction?.trim().isNotEmpty == true ? review.suggestedAction!.trim() : 'manual_review'}',
      if (review.projectId != null) 'projectId=${review.projectId}',
      if (review.scriptId != null) 'scriptId=${review.scriptId}',
      if (_qualityReviewStoryboardId(review) != null)
        'storyboardId=${_qualityReviewStoryboardId(review)}',
      'targetType=${review.targetType}',
      if ((review.stage ?? '').trim().isNotEmpty)
        'stage=${review.stage!.trim()}',
      if ((review.grade ?? '').trim().isNotEmpty)
        'grade=${review.grade!.trim()}',
      if ((review.comments ?? '').trim().isNotEmpty)
        'comments=${review.comments!.trim()}',
      if (review.isBadCase) l10n.qualityReviewsFilterBadCase,
    ];
    return parts.join('\n');
  }

  Future<void> _applySuggestedAction(QualityReview review) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final action = review.suggestedAction?.trim();
    if (action == null || action.isEmpty) {
      setState(() {
        _statusLine = 'This review has no suggested action to apply.';
      });
      return;
    }
    final link = _buildSuggestedActionLink(review);
    final clipboardSummary = _buildSuggestedActionClipboardSummary(
      l10n,
      review,
    );
    await Clipboard.setData(ClipboardData(text: clipboardSummary));
    if (!mounted) return;
    if (link == null || widget.onNavigateDomainDeepLink == null) {
      setState(() {
        _statusLine = 'Copied rework brief for $action.';
      });
      return;
    }
    widget.onNavigateDomainDeepLink!(link);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opened ${link.target.name} scope for $action.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _loadReviews({
    required bool onlyBadCases,
    bool onlyDeliveryPriority = false,
    bool onlyAutoSource = false,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        suggestedAction: _suggestedActionFilterValue,
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
        if (_suggestedActionFilterValue != null) {
          labels.add('suggested=${_suggestedActionFilterValue!}');
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _loadScopeInsights() async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _loadingScopeInsights = false);
      }
    }
  }

  Future<void> _loadStagePassRate() async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _loadingStagePassRate = false);
      }
    }
  }

  Future<void> _loadBadCaseStats() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _loadingBadCaseStats = true;
      _statusLine = null;
    });
    try {
      final items = await fetchBadCaseStats(widget.accessToken, limit: 5);
      if (!mounted) return;
      setState(() {
        _badCaseStatItems = items;
        _badCaseStatsSummary = items.isEmpty
            ? l10n.qualityReviewsNoBadCaseData
            : items
                  .map(
                    (e) => l10n.qualityReviewsBadCaseStatsLine(
                      e.badCaseCategory ?? l10n.qualityReviewsUncategorized,
                      e.count,
                      e.passRatePercent.toStringAsFixed(1),
                    ),
                  )
                  .join(' | ');
        _statusLine = l10n.qualityReviewsStatusRefreshedBadCaseDistribution;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) setState(() => _loadingBadCaseStats = false);
    }
  }

  Future<void> _loadTokenEfficiency() async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _loadingTokenEfficiency = false);
      }
    }
  }

  Future<void> _loadTokenEfficiencySamples() async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _loadingTokenEfficiencySamples = false);
      }
    }
  }

  Future<void> _loadReviewById() async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        _selectedReview = review;
        _statusLine = l10n.qualityReviewsStatusLoadedReviewDetails;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _loadingReviewById = false);
      }
    }
  }

  Future<void> _createReview() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final targetType = _ctrls.createTargetTypeCtrl.text.trim();
    final source = _ctrls.createSourceCtrl.text.trim();
    final projectId = int.tryParse(_ctrls.createProjectIdCtrl.text.trim());
    final scriptId = int.tryParse(_ctrls.createScriptIdCtrl.text.trim());
    final score = int.tryParse(_ctrls.createScoreCtrl.text.trim());
    final rawTargetId = _ctrls.createTargetIdCtrl.text.trim();
    if (targetType.isEmpty || source.isEmpty) {
      setState(
        () => _statusLine = l10n.qualityReviewsErrTargetTypeSourceRequired,
      );
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
          dimensionScores: _createDimensionScores,
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
        _selectedReview = created;
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusLine = describeUserVisibleApiError(l10n, e));
    } finally {
      if (mounted) {
        setState(() => _creatingReview = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        badCaseStatItems: _badCaseStatItems,
        reviewDetails: _reviewDetails,
        selectedReview: _selectedReview,
        createDimensionScores: _createDimensionScores,
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
        suggestedActionFilterCtrl: _ctrls.suggestedActionFilterCtrl,
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
        onCreateDimensionScoresChanged: (scores) =>
            setState(() => _createDimensionScores = scores),
        onCreatePassedChanged: (value) => setState(() => _createPassed = value),
        onCreateBadCaseChanged: (value) =>
            setState(() => _createBadCase = value),
        onSelectReview: (review) {
          setState(() {
            _ctrls.reviewIdCtrl.text = review.id;
            _reviewDetails = formatQualityReviewDetails(review, l10n: l10n);
            _selectedReview = review;
          });
        },
        onApplySuggestedAction: (review) {
          _applySuggestedAction(review);
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
