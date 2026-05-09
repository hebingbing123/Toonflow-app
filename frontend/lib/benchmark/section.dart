import 'dart:convert';

import 'package:flutter/material.dart';

import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'support.dart';

class BenchmarkSection extends StatefulWidget {
  const BenchmarkSection({super.key, required this.accessToken});

  final String? accessToken;

  @override
  State<BenchmarkSection> createState() => _BenchmarkSectionState();
}

class _BenchmarkSectionState extends State<BenchmarkSection> {
  final _projectIdCtrl = TextEditingController();
  final _qualityReviewIdCtrl = TextEditingController();
  final _promoteSummaryCtrl = TextEditingController();
  final _promoteTagsCtrl = TextEditingController();
  final _experimentIdCtrl = TextEditingController();
  final _experimentNameCtrl = TextEditingController();
  final _stageScopeCtrl = TextEditingController(
    text: 'storyboard_table,storyboard_panel,video_prompt',
  );
  final _baselineLabelCtrl = TextEditingController(text: 'baseline');
  final _variantsJsonCtrl = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert([
      {
        'label': 'baseline',
        'skillSnapshot': {
          'skillFiles': [
            {
              'path': 'data/skills/script_agent_supervision.md',
              'hash': 'baseline',
            },
          ],
          'versionTag': 'baseline',
        },
        'promptSnapshot': {
          'templates': [
            {
              'stage': 'video_prompt',
              'templateContent': 'baseline template',
              'hash': 'baseline-template',
            },
          ],
          'versionTag': 'baseline',
        },
        'memoryBudgetSnapshot': {
          'budgetTier': 'lean',
          'compressionRules': {},
          'retentionBuckets': {},
          'observationNoteLimit': 100,
        },
        'observationPolicySnapshot': {
          'negativeConstraints': ['avoid stiff emotion'],
          'observationNoteLimit': 100,
          'policyVersion': 'v1',
        },
        'modelRouteSnapshot': {
          'modelName': 'gpt-4o-mini',
          'temperature': 0.6,
          'maxTokens': 1200,
        },
      },
    ]),
  );
  final _gateVariantIdCtrl = TextEditingController();
  final _gateDecisionCtrl = TextEditingController();
  final _gateNoteCtrl = TextEditingController();
  final _reviewQueueIdCtrl = TextEditingController();
  final _reviewScoreJsonCtrl = TextEditingController(
    text: const JsonEncoder.withIndent('  ').convert({
      'overallScore': 82,
      'passed': true,
      'requiresRework': false,
      'recommendation': 'approved',
    }),
  );
  final _reviewSkipReasonCtrl = TextEditingController();
  final _abCompareCasesCtrl = TextEditingController(
    text: 'video_prompt_case_001,00000000-0000-0000-0000-000000000001,00000000-0000-0000-0000-000000000002',
  );
  final _abMinTokenReductionCtrl = TextEditingController(text: '10');
  final _abMaxQualityDropCtrl = TextEditingController(text: '5');
  final _abMinQualityScoreCtrl = TextEditingController(text: '70');
  final _abSignificanceCtrl = TextEditingController(text: '0.05');
  final _abCompareNameCtrl = TextEditingController(text: 'token-opt-compare');

  bool _busy = false;
  String? _statusLine;
  String _sampleTier = 'smoke';
  String _promoteCaseType = 'bad_case';
  bool _promoteToBaseline = false;
  List<BenchmarkCaseV1> _cases = const [];
  List<ExperimentRunV1> _experiments = const [];
  List<ReviewQueueItemV1> _reviewQueue = const [];
  MemoryProfilesResponseV1? _memoryProfiles;
  ExperimentDetailV1? _experimentDetail;
  RoiEvidenceSummaryV1? _roiSummary;
  GateDecisionEnvelopeV1? _gateSummary;
  BenchmarkTrendsResponseV1? _trends;
  ABCompareResponseV1? _abCompare;
  List<ABCompareRunRowV1> _abRuns = const [];
  ABCompareRunDetailV1? _abRunDetail;
  String? _selectedAbRunId;

  String? get _token => widget.accessToken;

  List<ABCompareCaseV1> _parseAbCompareCases() {
    return _abCompareCasesCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(',').map((e) => e.trim()).toList();
          if (parts.length != 3) {
            throw FormatException('无效案例行：$line');
          }
          return ABCompareCaseV1(
            testCaseId: parts[0],
            baselineJobId: parts[1],
            optimizedJobId: parts[2],
          );
        })
        .toList(growable: false);
  }

  ABCompareConfigV1 _parseAbCompareConfig() {
    final minToken = double.tryParse(_abMinTokenReductionCtrl.text.trim());
    final maxDrop = double.tryParse(_abMaxQualityDropCtrl.text.trim());
    final minScore = double.tryParse(_abMinQualityScoreCtrl.text.trim());
    final p = double.tryParse(_abSignificanceCtrl.text.trim());
    if (minToken == null || maxDrop == null || minScore == null || p == null) {
      throw const FormatException('A/B 阈值参数格式错误');
    }
    return ABCompareConfigV1(
      minTokenReductionPct: minToken,
      maxQualityDrop: maxDrop,
      minQualityScore: minScore,
      significanceThreshold: p,
    );
  }

  Future<void> _runAction(
    String label,
    Future<void> Function(String token) action,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _statusLine = '当前未登录，无法执行 $label';
      });
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '正在执行：$label';
    });
    try {
      await action(token);
      if (!mounted) return;
      setState(() {
        _statusLine = '已完成：$label';
      });
    } on RustApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusLine = '失败：$label（${error.statusCode ?? '-'} ${error.message}）';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusLine = '失败：$label（$error）';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  List<String> _parseCommaValues(TextEditingController ctrl) {
    return ctrl.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _projectIdCtrl.dispose();
    _qualityReviewIdCtrl.dispose();
    _promoteSummaryCtrl.dispose();
    _promoteTagsCtrl.dispose();
    _experimentIdCtrl.dispose();
    _experimentNameCtrl.dispose();
    _stageScopeCtrl.dispose();
    _baselineLabelCtrl.dispose();
    _variantsJsonCtrl.dispose();
    _gateVariantIdCtrl.dispose();
    _gateDecisionCtrl.dispose();
    _gateNoteCtrl.dispose();
    _reviewQueueIdCtrl.dispose();
    _reviewScoreJsonCtrl.dispose();
    _reviewSkipReasonCtrl.dispose();
    _abCompareCasesCtrl.dispose();
    _abMinTokenReductionCtrl.dispose();
    _abMaxQualityDropCtrl.dispose();
    _abMinQualityScoreCtrl.dispose();
    _abSignificanceCtrl.dispose();
    _abCompareNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final projectId = int.tryParse(_projectIdCtrl.text.trim());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '质量基线与实验',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: '本机客户端偏好',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '在同一入口管理样本池、实验运行、人工复核、ROI、放行门和趋势，避免后续质量优化只靠感觉判断。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction('读取样本池', (token) async {
                        _cases = await fetchBenchmarkCases(
                          token,
                          projectId: projectId,
                        );
                      }),
                child: const Text('读取样本池'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction('读取实验', (token) async {
                        _experiments = await fetchBenchmarkExperiments(token);
                      }),
                child: const Text('读取实验'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction('读取复核队列', (token) async {
                        _reviewQueue = await fetchBenchmarkReviewQueue(token);
                      }),
                child: const Text('读取复核队列'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction('读取记忆预算档', (token) async {
                        _memoryProfiles = await fetchBenchmarkMemoryProfiles(
                          token,
                        );
                      }),
                child: const Text('读取记忆档'),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction('读取趋势', (token) async {
                        _trends = await fetchBenchmarkTrends(token);
                      }),
                child: const Text('读取趋势'),
              ),
            ],
          ),
          if (_statusLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(_statusLine!),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _projectIdCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '项目 ID（可选，用于样本筛选）'),
          ),
          const SizedBox(height: 12),
          _buildPromoteCard(context),
          const SizedBox(height: 12),
          _buildExperimentCard(context),
          const SizedBox(height: 12),
          _buildReviewCard(context),
          const SizedBox(height: 12),
          _buildGateCard(context),
          const SizedBox(height: 12),
          _buildABCompareCard(context),
          const SizedBox(height: 12),
          SelectableText(
            summarizeBenchmarkCases(_cases),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_cases.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._cases
                .take(6)
                .map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item.caseType} · P${item.projectId} · ${item.stage}',
                    ),
                    subtitle: Text(
                      '${item.summary} · 权重 ${item.weight} · 标签 ${item.issueTags.join('/')}',
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          SelectableText(
            summarizeBenchmarkExperiments(_experiments),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_experiments.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._experiments
                .take(6)
                .map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item.name} · ${item.status}'),
                    subtitle: Text(
                      '${item.sampleTier} · 阶段 ${item.stageScope.join(', ')} · ${item.id}',
                    ),
                    onTap: () {
                      _experimentIdCtrl.text = item.id;
                      setState(() {});
                    },
                  ),
                ),
          ],
          const SizedBox(height: 12),
          SelectableText(
            summarizeBenchmarkReviewQueue(_reviewQueue),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_reviewQueue.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._reviewQueue
                .take(5)
                .map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item.reviewType} · ${item.status} · P${item.priority}',
                    ),
                    subtitle: Text(item.prompt),
                    onTap: () {
                      _reviewQueueIdCtrl.text = item.id;
                      setState(() {});
                    },
                  ),
                ),
          ],
          if (_memoryProfiles != null) ...[
            const SizedBox(height: 12),
            Text(
              '记忆预算档：${_memoryProfiles!.profiles.map((item) => '${item.budgetTier}/${item.profileVersion ?? '-'}').join('，')}',
            ),
          ],
          if (_experimentDetail != null) ...[
            const SizedBox(height: 12),
            Text(
              '实验详情：${_experimentDetail!.experiment.name} · ${_experimentDetail!.variants.length} 个变体',
            ),
            const SizedBox(height: 6),
            ..._experimentDetail!.variants.map(
              (variant) => Text(
                '${variant.label} · baseline=${variant.isBaseline} · budget=${variant.memoryBudgetSnapshot['budgetTier'] ?? '-'} · model=${variant.modelRouteSnapshot['modelName'] ?? '-'}',
              ),
            ),
          ],
          if (_roiSummary != null) ...[
            const SizedBox(height: 12),
            Text(
              'ROI：${_roiSummary!.overallConclusionType} · ${_roiSummary!.overallRationale}',
            ),
            const SizedBox(height: 6),
            ..._roiSummary!.variantComparisons.map(
              (item) => Text(
                '${item.variantLabel} · scoreΔ ${item.qualityScoreDelta.toStringAsFixed(2)} · tokenΔ ${item.tokenDeltaPercent.toStringAsFixed(1)}%',
              ),
            ),
          ],
          if (_gateSummary != null) ...[
            const SizedBox(height: 12),
            Text(summarizeBenchmarkGate(_gateSummary)),
            const SizedBox(height: 6),
            ..._gateSummary!.assessments.map(
              (item) => Text(
                '${item.variantLabel} · ${item.autoDecision} · scoreΔ ${item.qualityScoreDelta.toStringAsFixed(2)} · severeGuard ${item.severeGuardFailures}',
              ),
            ),
          ],
          if (_trends != null) ...[
            const SizedBox(height: 12),
            Text(summarizeBenchmarkTrends(_trends)),
            const SizedBox(height: 6),
            ..._trends!.weeks.map(
              (item) => Text(
                '${item.weekStart} · 质量 ${item.avgQualityScore.toStringAsFixed(1)} · token ${item.totalTokens} · approved ${item.approvedCount} / blocked ${item.blockedCount}',
              ),
            ),
          ],
          if (_abCompare != null) ...[
            const SizedBox(height: 12),
            Text(
              'A/B 汇总：${_abCompare!.passed ? "通过" : "未通过"} · '
              '通过 ${_abCompare!.passedCases}/${_abCompare!.totalCases} · '
              '平均 token 降幅 ${_abCompare!.avgTokenReductionPct.toStringAsFixed(1)}% · '
              '平均质量差 ${_abCompare!.avgQualityDiff.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 6),
            ..._abCompare!.comparisons.take(12).map(
              (item) => Text(
                '${item.testCaseId} · ${item.passed ? "PASS" : "FAIL"} · '
                'tokenΔ ${item.tokenReductionPct.toStringAsFixed(1)}% · '
                'qualityΔ ${(item.qualityScoreDiff ?? 0).toStringAsFixed(2)}'
                '${item.failureReasons.isEmpty ? '' : ' · ${item.failureReasons.join(" | ")}'}',
              ),
            ),
          ],
          if (_abRunDetail != null) ...[
            const SizedBox(height: 12),
            Text(
              '历史回放：${_abRunDetail!.run.name ?? _abRunDetail!.run.id} · ${_abRunDetail!.run.createdAt}',
            ),
            const SizedBox(height: 6),
            ..._abRunDetail!.cases.take(12).map((item) {
              final cmp = item.comparison;
              final passed = cmp['passed'] == true;
              final tokenDelta = (cmp['tokenReductionPct'] as num?)?.toDouble();
              final qualityDelta = (cmp['qualityScoreDiff'] as num?)?.toDouble();
              final reasons = (cmp['failureReasons'] is List)
                  ? (cmp['failureReasons'] as List).map((e) => e.toString()).toList()
                  : const <String>[];
              return Text(
                '${item.testCaseId} · ${passed ? "PASS" : "FAIL"} · '
                'tokenΔ ${(tokenDelta ?? 0).toStringAsFixed(1)}% · '
                'qualityΔ ${(qualityDelta ?? 0).toStringAsFixed(2)}'
                '${reasons.isEmpty ? "" : " · ${reasons.join(" | ")}"}',
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPromoteCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('从质量评审提升样本', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _qualityReviewIdCtrl,
              decoration: const InputDecoration(labelText: '质量评审 ID'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _promoteCaseType,
              decoration: const InputDecoration(labelText: '样本类型'),
              items: const [
                DropdownMenuItem(value: 'bad_case', child: Text('bad_case')),
                DropdownMenuItem(value: 'golden', child: Text('golden')),
                DropdownMenuItem(
                  value: 'regression_guard',
                  child: Text('regression_guard'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _promoteCaseType = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promoteSummaryCtrl,
              decoration: const InputDecoration(labelText: '样本摘要'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promoteTagsCtrl,
              decoration: const InputDecoration(labelText: '标签（逗号分隔）'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  _busy ||
                      _qualityReviewIdCtrl.text.trim().isEmpty ||
                      _promoteSummaryCtrl.text.trim().isEmpty
                  ? null
                  : () => _runAction('从评审提升样本', (token) async {
                      final item = await promoteBenchmarkCaseFromReview(
                        token,
                        qualityReviewId: _qualityReviewIdCtrl.text.trim(),
                        caseType: _promoteCaseType,
                        summary: _promoteSummaryCtrl.text.trim(),
                        issueTags: _parseCommaValues(_promoteTagsCtrl),
                      );
                      _cases = [item, ..._cases];
                    }),
              child: const Text('提升为样本'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperimentCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实验运行', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _experimentIdCtrl,
              decoration: const InputDecoration(labelText: '实验 ID'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('读取实验详情', (token) async {
                          _experimentDetail =
                              await fetchBenchmarkExperimentDetail(
                                token,
                                _experimentIdCtrl.text.trim(),
                              );
                        }),
                  child: const Text('读取详情'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('启动实验', (token) async {
                          _experimentDetail = await startBenchmarkExperiment(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: const Text('启动'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('取消实验', (token) async {
                          _experimentDetail = await cancelBenchmarkExperiment(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: const Text('取消'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('读取 ROI', (token) async {
                          _roiSummary = await fetchBenchmarkExperimentRoi(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: const Text('读取 ROI'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('读取放行门', (token) async {
                          _gateSummary = await fetchBenchmarkGate(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: const Text('读取放行门'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _experimentNameCtrl,
              decoration: const InputDecoration(labelText: '新实验名称'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _sampleTier,
              decoration: const InputDecoration(labelText: '样本集'),
              items: const [
                DropdownMenuItem(value: 'smoke', child: Text('smoke')),
                DropdownMenuItem(value: 'core', child: Text('core')),
                DropdownMenuItem(value: 'full', child: Text('full')),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _sampleTier = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stageScopeCtrl,
              decoration: const InputDecoration(labelText: '阶段范围（逗号分隔）'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baselineLabelCtrl,
              decoration: const InputDecoration(labelText: '基线变体 label'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _variantsJsonCtrl,
              maxLines: 14,
              decoration: const InputDecoration(labelText: '变体 JSON（数组）'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy || _experimentNameCtrl.text.trim().isEmpty
                  ? null
                  : () => _runAction('创建实验', (token) async {
                      final decoded = jsonDecode(_variantsJsonCtrl.text.trim());
                      if (decoded is! List) {
                        throw const FormatException('variants JSON 必须是数组');
                      }
                      final variants = decoded
                          .whereType<Map>()
                          .map(
                            (item) => Map<String, dynamic>.from(
                              item.cast<String, dynamic>(),
                            ),
                          )
                          .toList(growable: false);
                      final detail = await createBenchmarkExperiment(
                        token,
                        name: _experimentNameCtrl.text.trim(),
                        sampleTier: _sampleTier,
                        stageScope: _parseCommaValues(_stageScopeCtrl),
                        variants: variants,
                        baselineVariantLabel: _baselineLabelCtrl.text.trim(),
                      );
                      _experimentDetail = detail;
                      _experimentIdCtrl.text = detail.experiment.id;
                      _experiments = [detail.experiment, ..._experiments];
                    }),
              child: const Text('创建实验'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('人工复核', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewQueueIdCtrl,
              decoration: const InputDecoration(labelText: '复核队列 ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewScoreJsonCtrl,
              maxLines: 8,
              decoration: const InputDecoration(labelText: '提交评分 JSON'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy || _reviewQueueIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('提交复核', (token) async {
                          final decoded = jsonDecode(
                            _reviewScoreJsonCtrl.text.trim(),
                          );
                          if (decoded is! Map) {
                            throw const FormatException('submittedScore 必须是对象');
                          }
                          await submitBenchmarkReview(
                            token,
                            reviewQueueId: _reviewQueueIdCtrl.text.trim(),
                            submittedScore: Map<String, dynamic>.from(
                              decoded.cast<String, dynamic>(),
                            ),
                          );
                          _reviewQueue = await fetchBenchmarkReviewQueue(token);
                        }),
                  child: const Text('提交复核'),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _reviewSkipReasonCtrl,
                    decoration: const InputDecoration(labelText: '跳过原因（可选）'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _reviewQueueIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction('跳过复核', (token) async {
                          await skipBenchmarkReview(
                            token,
                            reviewQueueId: _reviewQueueIdCtrl.text.trim(),
                            reason: _reviewSkipReasonCtrl.text.trim(),
                          );
                          _reviewQueue = await fetchBenchmarkReviewQueue(token);
                        }),
                  child: const Text('跳过复核'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGateCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('放行门决策', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _gateVariantIdCtrl,
              decoration: const InputDecoration(labelText: '变体 ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gateDecisionCtrl,
              decoration: const InputDecoration(
                labelText: '决策（留空则使用 auto decision）',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gateNoteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '决策说明'),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _promoteToBaseline,
              title: const Text('同时提升为新基线'),
              subtitle: const Text('仅对 approved / approved_limited 生效'),
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() {
                        _promoteToBaseline = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  _busy ||
                      _experimentIdCtrl.text.trim().isEmpty ||
                      _gateVariantIdCtrl.text.trim().isEmpty
                  ? null
                  : () => _runAction('提交放行决策', (token) async {
                      await submitBenchmarkGateDecision(
                        token,
                        experimentId: _experimentIdCtrl.text.trim(),
                        variantId: _gateVariantIdCtrl.text.trim(),
                        decision: _gateDecisionCtrl.text.trim().isEmpty
                            ? null
                            : _gateDecisionCtrl.text.trim(),
                        rationaleNote: _gateNoteCtrl.text.trim(),
                        promoteToBaseline: _promoteToBaseline,
                      );
                      _gateSummary = await fetchBenchmarkGate(
                        token,
                        _experimentIdCtrl.text.trim(),
                      );
                    }),
              child: const Text('提交放行决策'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildABCompareCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A/B 对比评估', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _abCompareNameCtrl,
              decoration: const InputDecoration(labelText: '保存名称（可选）'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _abCompareCasesCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '案例列表（每行：testCaseId,baselineJobId,optimizedJobId）',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abMinTokenReductionCtrl,
                    decoration: const InputDecoration(labelText: '最小 token 降幅 %'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abMaxQualityDropCtrl,
                    decoration: const InputDecoration(labelText: '最大质量下降'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abMinQualityScoreCtrl,
                    decoration: const InputDecoration(labelText: '最小质量分'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abSignificanceCtrl,
                    decoration: const InputDecoration(labelText: '显著性阈值 p'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _runAction('执行 A/B 对比', (token) async {
                      final cases = _parseAbCompareCases();
                      final config = _parseAbCompareConfig();
                      _abCompare = await compareBenchmarkABJobs(
                        token,
                        cases: cases,
                        config: config,
                      );
                    }),
              child: const Text('执行 A/B 对比'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _runAction('保存并执行 A/B 对比', (token) async {
                      final cases = _parseAbCompareCases();
                      final config = _parseAbCompareConfig();
                      _abCompare = await compareBenchmarkABJobs(
                        token,
                        persist: true,
                        name: _abCompareNameCtrl.text.trim(),
                        cases: cases,
                        config: config,
                      );
                      _abRuns = await fetchBenchmarkABCompareRuns(token);
                    }),
              child: const Text('保存并执行'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _runAction('读取 A/B 历史', (token) async {
                          _abRuns = await fetchBenchmarkABCompareRuns(token);
                          if (_selectedAbRunId == null && _abRuns.isNotEmpty) {
                            _selectedAbRunId = _abRuns.first.id;
                          }
                        }),
                  child: const Text('读取历史'),
                ),
                if (_abRuns.isNotEmpty)
                  DropdownButton<String>(
                    value: _selectedAbRunId,
                    items: _abRuns
                        .take(20)
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(r.name ?? r.id.substring(0, 8)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (value) {
                            setState(() {
                              _selectedAbRunId = value;
                            });
                          },
                  ),
                FilledButton.tonal(
                  onPressed: _busy || _selectedAbRunId == null
                      ? null
                      : () => _runAction('读取 A/B 详情', (token) async {
                          final detail = await fetchBenchmarkABCompareRunDetail(
                            token,
                            _selectedAbRunId!,
                          );
                          _abRunDetail = detail;
                          // Refill controls for replay.
                          final cfg = detail.run.config;
                          _abMinTokenReductionCtrl.text =
                              '${cfg['minTokenReductionPct'] ?? _abMinTokenReductionCtrl.text}';
                          _abMaxQualityDropCtrl.text =
                              '${cfg['maxQualityDrop'] ?? _abMaxQualityDropCtrl.text}';
                          _abMinQualityScoreCtrl.text =
                              '${cfg['minQualityScore'] ?? _abMinQualityScoreCtrl.text}';
                          _abSignificanceCtrl.text =
                              '${cfg['significanceThreshold'] ?? _abSignificanceCtrl.text}';
                          _abCompareCasesCtrl.text = detail.cases
                              .map(
                                (c) =>
                                    '${c.testCaseId},${c.baselineJobId},${c.optimizedJobId}',
                              )
                              .join('\n');
                        }),
                  child: const Text('读取详情并回填'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _abRunDetail == null
                      ? null
                      : () => _runAction('复跑并保存', (token) async {
                          final cases = _parseAbCompareCases();
                          final config = _parseAbCompareConfig();
                          final baseName = (_abCompareNameCtrl.text.trim().isNotEmpty)
                              ? _abCompareNameCtrl.text.trim()
                              : (_abRunDetail!.run.name ??
                                  'ab-replay-${_abRunDetail!.run.id.substring(0, 8)}');
                          final ts = DateTime.now()
                              .toIso8601String()
                              .replaceAll(':', '')
                              .split('.')
                              .first;
                          final name = '$baseName-replay-$ts';
                          _abCompare = await compareBenchmarkABJobs(
                            token,
                            persist: true,
                            name: name,
                            cases: cases,
                            config: config,
                          );
                          _abRuns = await fetchBenchmarkABCompareRuns(token);
                          if (_abCompare?.runId != null) {
                            _selectedAbRunId = _abCompare!.runId;
                            _abRunDetail = await fetchBenchmarkABCompareRunDetail(
                              token,
                              _selectedAbRunId!,
                            );
                          }
                        }),
                  child: const Text('回放参数复跑并保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
