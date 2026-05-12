import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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

  List<ABCompareCaseV1> _parseAbCompareCases(AppLocalizations l10n) {
    return _abCompareCasesCtrl.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(',').map((e) => e.trim()).toList();
          if (parts.length != 3) {
            throw FormatException(l10n.benchmarkErrorInvalidCaseRow(line));
          }
          return ABCompareCaseV1(
            testCaseId: parts[0],
            baselineJobId: parts[1],
            optimizedJobId: parts[2],
          );
        })
        .toList(growable: false);
  }

  ABCompareConfigV1 _parseAbCompareConfig(AppLocalizations l10n) {
    final minToken = double.tryParse(_abMinTokenReductionCtrl.text.trim());
    final maxDrop = double.tryParse(_abMaxQualityDropCtrl.text.trim());
    final minScore = double.tryParse(_abMinQualityScoreCtrl.text.trim());
    final p = double.tryParse(_abSignificanceCtrl.text.trim());
    if (minToken == null || maxDrop == null || minScore == null || p == null) {
      throw FormatException(l10n.benchmarkErrorAbThresholdFormat);
    }
    return ABCompareConfigV1(
      minTokenReductionPct: minToken,
      maxQualityDrop: maxDrop,
      minQualityScore: minScore,
      significanceThreshold: p,
    );
  }

  Future<void> _runAction(
    AppLocalizations l10n,
    String label,
    Future<void> Function(String token) action,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _statusLine = l10n.benchmarkStatusNeedSignIn(label);
      });
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = l10n.benchmarkStatusRunning(label);
    });
    try {
      await action(token);
      if (!mounted) return;
      setState(() {
        _statusLine = l10n.benchmarkStatusCompleted(label);
      });
    } on RustApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusLine = l10n.benchmarkStatusFailedHttp(
          label,
          '${error.statusCode ?? '-'}',
          error.message,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusLine = l10n.benchmarkStatusFailed(label, '$error');
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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.benchmarkSectionTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.riskyPrefsMenuDefaultTooltip,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.benchmarkIntroBody,
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
                    : () => _runAction(l10n, l10n.benchmarkActionFetchSamplePool, (token) async {
                        _cases = await fetchBenchmarkCases(
                          token,
                          projectId: projectId,
                        );
                      }),
                child: Text(l10n.benchmarkActionFetchSamplePool),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction(l10n, l10n.benchmarkActionFetchExperiments, (token) async {
                        _experiments = await fetchBenchmarkExperiments(token);
                      }),
                child: Text(l10n.benchmarkActionFetchExperiments),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction(l10n, l10n.benchmarkActionFetchReviewQueue, (token) async {
                        _reviewQueue = await fetchBenchmarkReviewQueue(token);
                      }),
                child: Text(l10n.benchmarkActionFetchReviewQueue),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction(l10n, l10n.benchmarkActionFetchMemoryTier, (token) async {
                        _memoryProfiles = await fetchBenchmarkMemoryProfiles(
                          token,
                        );
                      }),
                child: Text(l10n.benchmarkActionFetchMemoryTier),
              ),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () => _runAction(l10n, l10n.benchmarkActionFetchTrends, (token) async {
                        _trends = await fetchBenchmarkTrends(token);
                      }),
                child: Text(l10n.benchmarkActionFetchTrends),
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
            decoration: InputDecoration(
              labelText: l10n.benchmarkProjectIdOptional,
            ),
          ),
          const SizedBox(height: 12),
          _buildPromoteCard(context, l10n),
          const SizedBox(height: 12),
          _buildExperimentCard(context, l10n),
          const SizedBox(height: 12),
          _buildReviewCard(context, l10n),
          const SizedBox(height: 12),
          _buildGateCard(context, l10n),
          const SizedBox(height: 12),
          _buildABCompareCard(context, l10n),
          const SizedBox(height: 12),
          SelectableText(
            summarizeBenchmarkCases(l10n, _cases),
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
                      l10n.benchmarkCaseRowSubtitle(
                        item.summary,
                        '${item.weight}',
                        item.issueTags.join('/'),
                      ),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          SelectableText(
            summarizeBenchmarkExperiments(l10n, _experiments),
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
                      l10n.benchmarkExperimentRowSubtitle(
                        item.sampleTier,
                        item.stageScope.join(', '),
                        item.id,
                      ),
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
            summarizeBenchmarkReviewQueue(l10n, _reviewQueue),
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
              l10n.benchmarkMemoryProfilesLine(
                _memoryProfiles!.profiles
                    .map(
                      (item) =>
                          '${item.budgetTier}/${item.profileVersion ?? '-'}',
                    )
                    .join(', '),
              ),
            ),
          ],
          if (_experimentDetail != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.benchmarkExperimentDetailHeader(
                _experimentDetail!.experiment.name.trim().isEmpty
                    ? _experimentDetail!.experiment.id
                    : _experimentDetail!.experiment.name,
                _experimentDetail!.variants.length,
              ),
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
              l10n.benchmarkRoiHeader(
                _roiSummary!.overallConclusionType,
                _roiSummary!.overallRationale,
              ),
            ),
            const SizedBox(height: 6),
            ..._roiSummary!.variantComparisons.map(
              (item) => Text(
                l10n.benchmarkRoiVariantLine(
                  item.variantLabel,
                  item.qualityScoreDelta.toStringAsFixed(2),
                  item.tokenDeltaPercent.toStringAsFixed(1),
                ),
              ),
            ),
          ],
          if (_gateSummary != null) ...[
            const SizedBox(height: 12),
            Text(summarizeBenchmarkGate(l10n, _gateSummary)),
            const SizedBox(height: 6),
            ..._gateSummary!.assessments.map(
              (item) => Text(
                l10n.benchmarkGateAssessmentRow(
                  item.variantLabel,
                  item.autoDecision,
                  item.qualityScoreDelta.toStringAsFixed(2),
                  '${item.severeGuardFailures}',
                ),
              ),
            ),
          ],
          if (_trends != null) ...[
            const SizedBox(height: 12),
            Text(summarizeBenchmarkTrends(l10n, _trends)),
            const SizedBox(height: 6),
            ..._trends!.weeks.map(
              (item) => Text(
                l10n.benchmarkTrendWeekRow(
                  item.weekStart,
                  item.avgQualityScore.toStringAsFixed(1),
                  '${item.totalTokens}',
                  '${item.approvedCount}',
                  '${item.blockedCount}',
                ),
              ),
            ),
          ],
          if (_abCompare != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.benchmarkAbAggregateSummary(
                _abCompare!.passed
                    ? l10n.benchmarkAbOutcomePassed
                    : l10n.benchmarkAbOutcomeFailed,
                _abCompare!.passedCases,
                _abCompare!.totalCases,
                _abCompare!.avgTokenReductionPct.toStringAsFixed(1),
                _abCompare!.avgQualityDiff.toStringAsFixed(2),
              ),
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
              l10n.benchmarkHistoryReplay(
                ((_abRunDetail!.run.name?.trim().isEmpty) ?? true)
                    ? _abRunDetail!.run.id
                    : _abRunDetail!.run.name!,
                _abRunDetail!.run.createdAt,
              ),
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

  Widget _buildPromoteCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkPromoteCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qualityReviewIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelQualityReviewId,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _promoteCaseType,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSampleType,
              ),
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
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSampleSummary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promoteTagsCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelTagsCommaSeparated,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  _busy ||
                      _qualityReviewIdCtrl.text.trim().isEmpty ||
                      _promoteSummaryCtrl.text.trim().isEmpty
                  ? null
                  : () => _runAction(l10n, l10n.benchmarkActionPromoteFromReview, (token) async {
                      final item = await promoteBenchmarkCaseFromReview(
                        token,
                        qualityReviewId: _qualityReviewIdCtrl.text.trim(),
                        caseType: _promoteCaseType,
                        summary: _promoteSummaryCtrl.text.trim(),
                        issueTags: _parseCommaValues(_promoteTagsCtrl),
                      );
                      _cases = [item, ..._cases];
                    }),
              child: Text(l10n.benchmarkButtonPromoteToSample),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperimentCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkExperimentCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _experimentIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelExperimentId,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionFetchExperimentDetail, (token) async {
                          _experimentDetail =
                              await fetchBenchmarkExperimentDetail(
                                token,
                                _experimentIdCtrl.text.trim(),
                              );
                        }),
                  child: Text(l10n.benchmarkButtonLoadDetail),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionStartExperiment, (token) async {
                          _experimentDetail = await startBenchmarkExperiment(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: Text(l10n.benchmarkButtonStart),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionCancelExperiment, (token) async {
                          _experimentDetail = await cancelBenchmarkExperiment(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: Text(l10n.benchmarkButtonCancel),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionFetchRoi, (token) async {
                          _roiSummary = await fetchBenchmarkExperimentRoi(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: Text(l10n.benchmarkActionFetchRoi),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _experimentIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionFetchGate, (token) async {
                          _gateSummary = await fetchBenchmarkGate(
                            token,
                            _experimentIdCtrl.text.trim(),
                          );
                        }),
                  child: Text(l10n.benchmarkActionFetchGate),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _experimentNameCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelNewExperimentName,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _sampleTier,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSampleTierSet,
              ),
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
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelStageScopeComma,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baselineLabelCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelBaselineVariantLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _variantsJsonCtrl,
              maxLines: 14,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelVariantsJsonArray,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy || _experimentNameCtrl.text.trim().isEmpty
                  ? null
                  : () => _runAction(l10n, l10n.benchmarkActionCreateExperiment, (token) async {
                      final decoded = jsonDecode(_variantsJsonCtrl.text.trim());
                      if (decoded is! List) {
                        throw FormatException(
                          l10n.benchmarkErrorVariantsMustBeJsonArray,
                        );
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
              child: Text(l10n.benchmarkButtonCreateExperiment),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkReviewCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewQueueIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelReviewQueueId,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewScoreJsonCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSubmittedScoreJson,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy || _reviewQueueIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionSubmitReview, (token) async {
                          final decoded = jsonDecode(
                            _reviewScoreJsonCtrl.text.trim(),
                          );
                          if (decoded is! Map) {
                            throw FormatException(
                              l10n.benchmarkErrorSubmittedScoreMustBeObject,
                            );
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
                  child: Text(l10n.benchmarkActionSubmitReview),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _reviewSkipReasonCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.benchmarkLabelSkipReasonOptional,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _reviewQueueIdCtrl.text.trim().isEmpty
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionSkipReview, (token) async {
                          await skipBenchmarkReview(
                            token,
                            reviewQueueId: _reviewQueueIdCtrl.text.trim(),
                            reason: _reviewSkipReasonCtrl.text.trim(),
                          );
                          _reviewQueue = await fetchBenchmarkReviewQueue(token);
                        }),
                  child: Text(l10n.benchmarkActionSkipReview),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGateCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkGateCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gateVariantIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelGateVariantId,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gateDecisionCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelGateDecisionOptionalAuto,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _gateNoteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelGateDecisionNote,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _promoteToBaseline,
              title: Text(l10n.benchmarkGatePromoteBaselineTitle),
              subtitle: Text(l10n.benchmarkGatePromoteBaselineSubtitle),
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
                  : () => _runAction(l10n, l10n.benchmarkActionSubmitGateDecision, (token) async {
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
              child: Text(l10n.benchmarkActionSubmitGateDecision),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildABCompareCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkAbCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _abCompareNameCtrl,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelAbSaveNameOptional,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _abCompareCasesCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelAbCaseLines,
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
                    decoration: InputDecoration(
                      labelText: l10n.benchmarkLabelAbMinTokenReductionPct,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abMaxQualityDropCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.benchmarkLabelAbMaxQualityDrop,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abMinQualityScoreCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.benchmarkLabelAbMinQualityScore,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _abSignificanceCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.benchmarkLabelAbSignificanceP,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _runAction(l10n, l10n.benchmarkActionRunAbCompare, (token) async {
                      final cases = _parseAbCompareCases(l10n);
                      final config = _parseAbCompareConfig(l10n);
                      _abCompare = await compareBenchmarkABJobs(
                        token,
                        cases: cases,
                        config: config,
                      );
                    }),
              child: Text(l10n.benchmarkButtonRunAbCompare),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => _runAction(l10n, l10n.benchmarkActionSaveRunAbCompare, (token) async {
                      final cases = _parseAbCompareCases(l10n);
                      final config = _parseAbCompareConfig(l10n);
                      _abCompare = await compareBenchmarkABJobs(
                        token,
                        persist: true,
                        name: _abCompareNameCtrl.text.trim(),
                        cases: cases,
                        config: config,
                      );
                      _abRuns = await fetchBenchmarkABCompareRuns(token);
                    }),
              child: Text(l10n.benchmarkButtonSaveAndRun),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionFetchAbHistory, (token) async {
                          _abRuns = await fetchBenchmarkABCompareRuns(token);
                          if (_selectedAbRunId == null && _abRuns.isNotEmpty) {
                            _selectedAbRunId = _abRuns.first.id;
                          }
                        }),
                  child: Text(l10n.benchmarkButtonFetchHistory),
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
                      : () => _runAction(l10n, l10n.benchmarkActionFetchAbDetail, (token) async {
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
                  child: Text(l10n.benchmarkButtonLoadDetailAndFill),
                ),
                FilledButton.tonal(
                  onPressed: _busy || _abRunDetail == null
                      ? null
                      : () => _runAction(l10n, l10n.benchmarkActionReplaySave, (token) async {
                          final cases = _parseAbCompareCases(l10n);
                          final config = _parseAbCompareConfig(l10n);
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
                  child: Text(l10n.benchmarkButtonReplaySave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
