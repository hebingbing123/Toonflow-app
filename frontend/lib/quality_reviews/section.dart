import 'package:flutter/material.dart';

import 'controller.dart';
import 'previews.dart';
import 'support.dart';
import 'workbench_view.dart';
import '../../rust_api.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
    required this.controller,
  });

  final String? accessToken;
  final QualityReviewsController controller;

  Future<void> _openQualityWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取质量评审')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _QualityReviewsWorkbenchDialog(
        accessToken: token,
        initialReviews: controller.qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: controller.qualityReviewByIdLine,
        initialStatsSummary: controller.qualityStatsLine,
        initialStagePassRateSummary: controller.qualityStagePassRateLine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final reviewSummary = controller.qualityReviews == null
        ? '尚未加载评审列表'
        : summarizeQualityReviews(controller.qualityReviews!);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('质量评审', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '查看评审列表、坏例与阶段通过率，并按 ID 打开单条记录。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 8),
          QualityReviewsActionsBar(
            loadingQualityReviews: controller.loadingQualityReviews,
            loadingQualityBadCases: controller.loadingQualityBadCases,
            loadingQualityStats: controller.loadingQualityStats,
            loadingQualityStagePassRate: controller.loadingQualityStagePassRate,
            onOpenWorkbench: () => _openQualityWorkbench(context),
            onLoadQualityReviews: controller.loadQualityReviews,
            onLoadQualityBadCases: controller.loadQualityBadCases,
            onLoadQualityStats: controller.loadQualityStats,
            onLoadQualityStagePassRate: controller.loadQualityStagePassRate,
          ),
          const SizedBox(height: 8),
          QualityReviewsSummaryPreview(
            outlineColor: outline,
            reviewSummary: reviewSummary,
          ),
          const SizedBox(height: 8),
          QualityReviewsCompatibilityPanel(
            outlineColor: outline,
            creatingQualityReview: controller.creatingQualityReview,
            onCreateQualityReviewProbe: controller.createQualityReviewProbe,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.qualityReviewIdController,
            onChanged: controller.onQualityReviewIdChanged,
            decoration: const InputDecoration(labelText: '评审 ID（点下方列表可自动填入）'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed:
                (controller.loadingQualityReviewById ||
                    controller.qualityReviewIdController.text.trim().isEmpty)
                ? null
                : controller.fetchSelectedQualityReview,
            child: Text(controller.loadingQualityReviewById ? '…' : '查看评审详情'),
          ),
          if (controller.qualityReviewByIdLine != null) ...[
            const SizedBox(height: 8),
            SelectableText('评审详情：${controller.qualityReviewByIdLine}'),
          ],
          if (controller.qualityStatsLine != null) ...[
            const SizedBox(height: 8),
            SelectableText('质量统计：${controller.qualityStatsLine}'),
          ],
          if (controller.qualityStagePassRateLine != null) ...[
            const SizedBox(height: 8),
            SelectableText('阶段通过率：${controller.qualityStagePassRateLine}'),
          ],
          if (controller.qualityReviews != null) ...[
            QualityReviewsListPreview(
              reviews: controller.qualityReviews!,
              onSelectQualityReview: controller.selectQualityReview,
            ),
          ],
        ],
      ),
    );
  }
}

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
  late final TextEditingController _targetTypeFilterCtrl;
  late final TextEditingController _targetIdFilterCtrl;
  late final TextEditingController _jobIdFilterCtrl;
  late final TextEditingController _reviewIdCtrl;
  late final TextEditingController _createTargetTypeCtrl;
  late final TextEditingController _createTargetIdCtrl;
  late final TextEditingController _createSourceCtrl;
  late final TextEditingController _createScoreCtrl;
  late final TextEditingController _createCommentsCtrl;
  late final TextEditingController _createBadCaseCategoryCtrl;

  List<QualityReview> _reviews = const <QualityReview>[];
  String? _statsSummary;
  String? _stagePassRateSummary;
  String? _reviewDetails;
  bool _loadingReviews = false;
  bool _loadingBadCases = false;
  bool _loadingStats = false;
  bool _loadingStagePassRate = false;
  bool _loadingReviewById = false;
  bool _creatingReview = false;
  bool _filterBadCasesOnly = false;
  bool _createPassed = true;
  bool _createBadCase = false;
  String? _statusLine;

  @override
  void initState() {
    super.initState();
    _targetTypeFilterCtrl = TextEditingController();
    _targetIdFilterCtrl = TextEditingController();
    _jobIdFilterCtrl = TextEditingController();
    _reviewIdCtrl = TextEditingController();
    _createTargetTypeCtrl = TextEditingController(text: 'output');
    _createTargetIdCtrl = TextEditingController(
      text: 'flutter-workbench-${DateTime.now().millisecondsSinceEpoch}',
    );
    _createSourceCtrl = TextEditingController(text: 'manual');
    _createScoreCtrl = TextEditingController(text: '85');
    _createCommentsCtrl = TextEditingController(
      text: 'quality workbench review',
    );
    _createBadCaseCategoryCtrl = TextEditingController();
    _reviews = List<QualityReview>.from(widget.initialReviews);
    _statsSummary = widget.initialStatsSummary;
    _stagePassRateSummary = widget.initialStagePassRateSummary;
    _reviewDetails = widget.initialReviewDetails;
    if (_reviews.isNotEmpty) {
      _reviewIdCtrl.text = _reviews.first.id;
    }
  }

  @override
  void dispose() {
    _targetTypeFilterCtrl.dispose();
    _targetIdFilterCtrl.dispose();
    _jobIdFilterCtrl.dispose();
    _reviewIdCtrl.dispose();
    _createTargetTypeCtrl.dispose();
    _createTargetIdCtrl.dispose();
    _createSourceCtrl.dispose();
    _createScoreCtrl.dispose();
    _createCommentsCtrl.dispose();
    _createBadCaseCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews({required bool onlyBadCases}) async {
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
        targetType: _targetTypeFilterCtrl.text.trim(),
        targetId: _targetIdFilterCtrl.text.trim(),
        jobId: _jobIdFilterCtrl.text.trim(),
        isBadCase: onlyBadCases ? true : null,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _reviews = rows;
        _filterBadCasesOnly = onlyBadCases;
        _statusLine = onlyBadCases
            ? '已加载 ${rows.length} 条坏例评审'
            : '已加载 ${rows.length} 条评审';
        if (_reviewIdCtrl.text.trim().isEmpty && rows.isNotEmpty) {
          _reviewIdCtrl.text = rows.first.id;
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

  Future<void> _loadReviewById() async {
    final reviewId = _reviewIdCtrl.text.trim();
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
    final targetType = _createTargetTypeCtrl.text.trim();
    final source = _createSourceCtrl.text.trim();
    final score = int.tryParse(_createScoreCtrl.text.trim());
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
          targetId: _createTargetIdCtrl.text.trim().isEmpty
              ? null
              : _createTargetIdCtrl.text.trim(),
          source: source,
          overallScore: score,
          passed: _createPassed,
          comments: _createCommentsCtrl.text.trim().isEmpty
              ? null
              : _createCommentsCtrl.text.trim(),
          isBadCase: _createBadCase,
          badCaseCategory: _createBadCaseCategoryCtrl.text.trim().isEmpty
              ? null
              : _createBadCaseCategoryCtrl.text.trim(),
          modelName: 'manual',
          skillVersion: 'flutter.workbench',
          modelParams: const {'surface': 'quality_reviews_workbench'},
        ),
      );
      if (!mounted) return;
      setState(() {
        _reviewIdCtrl.text = created.id;
        _reviewDetails = formatQualityReviewDetails(created);
        _statusLine = '已创建评审 ${created.id}';
      });
      await _loadReviews(onlyBadCases: _filterBadCasesOnly);
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
        reviewDetails: _reviewDetails,
        statusLine: _statusLine,
        filterBadCasesOnly: _filterBadCasesOnly,
        createPassed: _createPassed,
        createBadCase: _createBadCase,
        loadingReviews: _loadingReviews,
        loadingBadCases: _loadingBadCases,
        loadingStats: _loadingStats,
        loadingStagePassRate: _loadingStagePassRate,
        loadingReviewById: _loadingReviewById,
        creatingReview: _creatingReview,
        targetTypeFilterCtrl: _targetTypeFilterCtrl,
        targetIdFilterCtrl: _targetIdFilterCtrl,
        jobIdFilterCtrl: _jobIdFilterCtrl,
        reviewIdCtrl: _reviewIdCtrl,
        createTargetTypeCtrl: _createTargetTypeCtrl,
        createTargetIdCtrl: _createTargetIdCtrl,
        createSourceCtrl: _createSourceCtrl,
        createScoreCtrl: _createScoreCtrl,
        createCommentsCtrl: _createCommentsCtrl,
        createBadCaseCategoryCtrl: _createBadCaseCategoryCtrl,
      ),
      callbacks: QualityReviewsWorkbenchDialogViewCallbacks(
        onLoadReviews: () {
          _loadReviews(onlyBadCases: false);
        },
        onLoadBadCases: () {
          _loadReviews(onlyBadCases: true);
        },
        onLoadStats: () {
          _loadStats();
        },
        onLoadStagePassRate: () {
          _loadStagePassRate();
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
            _reviewIdCtrl.text = review.id;
            _reviewDetails = formatQualityReviewDetails(review);
          });
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
