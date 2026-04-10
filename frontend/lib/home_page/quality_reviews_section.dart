import 'package:flutter/material.dart';

import 'quality_reviews_workbench_support.dart';
import '../rust_api.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
    required this.loadingQualityReviews,
    required this.loadingQualityBadCases,
    required this.loadingQualityStats,
    required this.loadingQualityStagePassRate,
    required this.creatingQualityReview,
    required this.loadingQualityReviewById,
    required this.qualityReviewIdController,
    required this.qualityReviews,
    required this.qualityStatsLine,
    required this.qualityStagePassRateLine,
    required this.qualityReviewByIdLine,
    required this.onQualityReviewIdChanged,
    required this.onLoadQualityReviews,
    required this.onLoadQualityBadCases,
    required this.onLoadQualityStats,
    required this.onLoadQualityStagePassRate,
    required this.onCreateQualityReviewProbe,
    required this.onFetchQualityReviewById,
    required this.onSelectQualityReview,
  });

  final String? accessToken;
  final bool loadingQualityReviews;
  final bool loadingQualityBadCases;
  final bool loadingQualityStats;
  final bool loadingQualityStagePassRate;
  final bool creatingQualityReview;
  final bool loadingQualityReviewById;
  final TextEditingController qualityReviewIdController;
  final List<QualityReview>? qualityReviews;
  final String? qualityStatsLine;
  final String? qualityStagePassRateLine;
  final String? qualityReviewByIdLine;
  final ValueChanged<String> onQualityReviewIdChanged;
  final VoidCallback onLoadQualityReviews;
  final VoidCallback onLoadQualityBadCases;
  final VoidCallback onLoadQualityStats;
  final VoidCallback onLoadQualityStagePassRate;
  final VoidCallback onCreateQualityReviewProbe;
  final VoidCallback onFetchQualityReviewById;
  final ValueChanged<QualityReview> onSelectQualityReview;

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
        initialReviews: qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: qualityReviewByIdLine,
        initialStatsSummary: qualityStatsLine,
        initialStagePassRateSummary: qualityStagePassRateLine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final reviewSummary = qualityReviews == null
        ? '尚未加载评审列表'
        : summarizeQualityReviews(qualityReviews!);
    return Column(
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: () => _openQualityWorkbench(context),
              child: const Text('打开质量工作台'),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityReviews ? null : onLoadQualityReviews,
              child: Text(loadingQualityReviews ? '…' : '加载评审列表'),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityBadCases ? null : onLoadQualityBadCases,
              child: Text(loadingQualityBadCases ? '…' : '查看坏例'),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityStats ? null : onLoadQualityStats,
              child: Text(loadingQualityStats ? '…' : '查看质量统计'),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityStagePassRate
                  ? null
                  : onLoadQualityStagePassRate,
              child: Text(loadingQualityStagePassRate ? '…' : '查看阶段通过率'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          reviewSummary,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留质量评审回归创建入口，默认折叠',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Legacy review probe',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: outline),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: creatingQualityReview
                      ? null
                      : onCreateQualityReviewProbe,
                  child: Text(creatingQualityReview ? '…' : '创建回归评审'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: qualityReviewIdController,
          onChanged: onQualityReviewIdChanged,
          decoration: const InputDecoration(labelText: '评审 ID（点下方列表可自动填入）'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              (loadingQualityReviewById ||
                  qualityReviewIdController.text.trim().isEmpty)
              ? null
              : onFetchQualityReviewById,
          child: Text(loadingQualityReviewById ? '…' : '查看评审详情'),
        ),
        if (qualityReviewByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('评审详情：$qualityReviewByIdLine'),
        ],
        if (qualityStatsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('质量统计：$qualityStatsLine'),
        ],
        if (qualityStagePassRateLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('阶段通过率：$qualityStagePassRateLine'),
        ],
        if (qualityReviews != null) ...[
          const SizedBox(height: 8),
          Text(
            '${qualityReviews!.length} 条评审',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...qualityReviews!
              .take(8)
              .map(
                (review) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
                  ),
                  subtitle: Text(
                    [
                      review.id,
                      if (review.targetId != null &&
                          review.targetId!.isNotEmpty)
                        'target=${review.targetId}',
                      if (review.passed != null) 'passed=${review.passed}',
                      if (review.isBadCase) 'bad_case',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelectQualityReview(review),
                ),
              ),
        ],
      ],
    );
  }
}

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
    _createCommentsCtrl = TextEditingController(text: 'quality workbench review');
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
          badCaseCategory:
              _createBadCaseCategoryCtrl.text.trim().isEmpty
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
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('质量工作台'),
      content: SizedBox(
        width: 840,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _reviews.isEmpty
                    ? '用同一入口完成评审筛选、坏例查看、统计读取、详情查询和手动创建。'
                    : summarizeQualityReviews(_reviews),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Text('筛选与读取', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _targetTypeFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 targetType'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetIdFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 targetId'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _jobIdFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 jobId'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingReviews || _creatingReview
                        ? null
                        : () => _loadReviews(onlyBadCases: false),
                    child: Text(_loadingReviews ? '加载中…' : '加载评审列表'),
                  ),
                  OutlinedButton(
                    onPressed: _loadingBadCases || _creatingReview
                        ? null
                        : () => _loadReviews(onlyBadCases: true),
                    child: Text(_loadingBadCases ? '加载中…' : '只看坏例'),
                  ),
                  OutlinedButton(
                    onPressed: _loadingStats ? null : _loadStats,
                    child: Text(_loadingStats ? '统计中…' : '读取质量统计'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _loadingStagePassRate ? null : _loadStagePassRate,
                    child: Text(
                      _loadingStagePassRate ? '读取中…' : '读取阶段通过率',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('详情查询', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewIdCtrl,
                decoration: const InputDecoration(labelText: '评审 ID'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed:
                    _loadingReviewById || _creatingReview ? null : _loadReviewById,
                child: Text(_loadingReviewById ? '读取中…' : '查看评审详情'),
              ),
              const SizedBox(height: 12),
              Text('创建评审', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _createTargetTypeCtrl,
                decoration: const InputDecoration(labelText: 'targetType'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _createTargetIdCtrl,
                decoration: const InputDecoration(labelText: 'targetId'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _createSourceCtrl,
                decoration: const InputDecoration(labelText: 'source'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _createScoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'overallScore'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _createCommentsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'comments'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('passed'),
                value: _createPassed,
                onChanged: _creatingReview
                    ? null
                    : (value) => setState(() => _createPassed = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('isBadCase'),
                value: _createBadCase,
                onChanged: _creatingReview
                    ? null
                    : (value) => setState(() => _createBadCase = value),
              ),
              TextField(
                controller: _createBadCaseCategoryCtrl,
                decoration: const InputDecoration(labelText: 'badCaseCategory'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _creatingReview ? null : _createReview,
                child: Text(_creatingReview ? '创建中…' : '创建评审'),
              ),
              if (_statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText('状态：$_statusLine'),
              ],
              if (_reviewDetails != null) ...[
                const SizedBox(height: 12),
                SelectableText('评审详情：$_reviewDetails'),
              ],
              if (_statsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('质量统计：$_statsSummary'),
              ],
              if (_stagePassRateSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('阶段通过率：$_stagePassRateSummary'),
              ],
              if (_reviews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _filterBadCasesOnly
                      ? '坏例 ${_reviews.length} 条'
                      : '评审 ${_reviews.length} 条',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ..._reviews.take(8).map(
                  (review) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
                    ),
                    subtitle: Text(formatQualityReviewDetails(review)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        _reviewIdCtrl.text = review.id;
                        _reviewDetails = formatQualityReviewDetails(review);
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
