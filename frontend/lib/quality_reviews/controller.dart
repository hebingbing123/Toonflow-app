import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'support.dart';

typedef QualityReviewsAccessTokenProvider = String? Function();
typedef QualityReviewsErrorSink = void Function(String? error);
typedef QualityReviewsL10nProvider = AppLocalizations? Function();

class QualityReviewsController extends ChangeNotifier {
  QualityReviewsController({
    required QualityReviewsAccessTokenProvider accessTokenProvider,
    required QualityReviewsErrorSink onErrorChanged,
    QualityReviewsL10nProvider? l10nProvider,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider;

  final QualityReviewsAccessTokenProvider _accessTokenProvider;
  final QualityReviewsErrorSink _onErrorChanged;
  final QualityReviewsL10nProvider? _l10nProvider;

  final TextEditingController qualityReviewIdController =
      TextEditingController();

  bool loadingQualityReviews = false;
  bool loadingQualityBadCases = false;
  bool loadingQualityStats = false;
  bool loadingQualityStagePassRate = false;
  bool loadingQualityDashboard = false;
  bool refreshingQualityDashboardReadModel = false;
  bool creatingQualityReview = false;
  bool loadingQualityReviewById = false;
  String? qualityStatsLine;
  String? qualityStagePassRateLine;
  String? qualityStageGradeLine;
  String? qualityScopeInsightsLine;
  String? qualityTokenEfficiencyLine;
  String? qualityBadCaseStatsLine;
  String? qualityDashboardLine;
  String? qualityDashboardRefreshLine;
  String? qualityDashboardFreshnessLine;
  String? qualityReviewByIdLine;
  List<QualityReview>? qualityReviews;
  List<QualityDashboardTargetStat>? qualityStatsRows;
  List<QualityDashboardStagePassRateItem>? qualityStagePassRateRows;
  List<QualityDashboardStageGradeItem>? qualityStageGradeRows;
  List<QualityDashboardScopeInsightItem>? qualityScopeInsightRows;
  List<QualityDashboardTokenEfficiencyItem>? qualityTokenEfficiencyRows;
  List<BadCaseStatItem>? qualityBadCaseStatItems;
  QualityDashboardMeta? qualityDashboardMeta;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider?.call();

  AppLocalizations get _l10nResolved => qualityReviewsResolveL10n(_l10n);

  List<QualityDashboardTargetStat> _mapStatsRowsToDashboardStats(
    List<QualityStatsRow> rows,
  ) {
    return rows
        .map(
          (row) => QualityDashboardTargetStat(
            scope: 'user',
            targetType: row.targetType,
            totalReviews: row.totalReviews,
            passRatePercent: row.passRatePercent,
            avgOverallScore: row.avgOverallScore,
          ),
        )
        .toList(growable: false);
  }

  List<QualityDashboardStagePassRateItem> _mapStagePassRateRows(
    List<StagePassRateRow> rows,
  ) {
    return rows
        .map(
          (row) => QualityDashboardStagePassRateItem(
            scope: 'user',
            targetType: row.targetType,
            reviewDate: DateTime.parse(row.reviewDate),
            totalReviews: row.totalReviews,
            passRatePercent: row.passRatePercent ?? 0,
          ),
        )
        .toList(growable: false);
  }

  List<QualityDashboardStageGradeItem> _mapStageGradeRows(
    List<StageGradeDistributionRow> rows,
  ) {
    return rows
        .map(
          (row) => QualityDashboardStageGradeItem(
            scope: 'user',
            stage: row.stage,
            gradeACount: row.gradeACount,
            gradeBCount: row.gradeBCount,
            gradeCCount: row.gradeCCount,
            gradeDCount: row.gradeDCount,
            totalCount: row.totalCount,
            passRatePercent: row.passRatePercent,
          ),
        )
        .toList(growable: false);
  }

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  void onQualityReviewIdChanged(String _) {
    notifyListeners();
  }

  void selectQualityReview(QualityReview review) {
    qualityReviewIdController.text = review.id;
    notifyListeners();
  }

  void reset() {
    loadingQualityReviews = false;
    loadingQualityBadCases = false;
    loadingQualityStats = false;
    loadingQualityStagePassRate = false;
    loadingQualityDashboard = false;
    refreshingQualityDashboardReadModel = false;
    creatingQualityReview = false;
    loadingQualityReviewById = false;
    qualityStatsLine = null;
    qualityStagePassRateLine = null;
    qualityStageGradeLine = null;
    qualityScopeInsightsLine = null;
    qualityTokenEfficiencyLine = null;
    qualityBadCaseStatsLine = null;
    qualityDashboardLine = null;
    qualityDashboardRefreshLine = null;
    qualityDashboardFreshnessLine = null;
    qualityReviewByIdLine = null;
    qualityReviews = null;
    qualityStatsRows = null;
    qualityStagePassRateRows = null;
    qualityStageGradeRows = null;
    qualityScopeInsightRows = null;
    qualityTokenEfficiencyRows = null;
    qualityBadCaseStatItems = null;
    qualityDashboardMeta = null;
    qualityReviewIdController.clear();
    notifyListeners();
  }

  Future<void> loadQualityReviews() async {
    await _loadQualityReviews();
  }

  Future<void> loadQualityBadCases() async {
    await _loadQualityReviews(onlyBadCases: true);
  }

  Future<void> _loadQualityReviews({bool onlyBadCases = false}) async {
    final token = _accessToken;
    if (token == null) return;
    if (onlyBadCases) {
      loadingQualityBadCases = true;
    } else {
      loadingQualityReviews = true;
    }
    qualityReviews = null;
    _setError(null);
    notifyListeners();
    try {
      qualityReviews = await fetchQualityReviews(
        token,
        isBadCase: onlyBadCases ? true : null,
        limit: 20,
      );
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      if (onlyBadCases) {
        loadingQualityBadCases = false;
      } else {
        loadingQualityReviews = false;
      }
      notifyListeners();
    }
  }

  Future<void> createQualityReviewProbe() async {
    final token = _accessToken;
    if (token == null) return;
    creatingQualityReview = true;
    _setError(null);
    notifyListeners();
    try {
      await loadQualityReviews();
      await loadQualityStats();
      if ((qualityReviews ?? const <QualityReview>[]).isNotEmpty) {
        qualityReviewIdController.text = qualityReviews!.first.id;
        await fetchSelectedQualityReview();
      }
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      creatingQualityReview = false;
      notifyListeners();
    }
  }

  Future<void> fetchSelectedQualityReview() async {
    final token = _accessToken;
    if (token == null) return;
    final id = qualityReviewIdController.text.trim();
    if (id.isEmpty) return;
    loadingQualityReviewById = true;
    qualityReviewByIdLine = null;
    _setError(null);
    notifyListeners();
    try {
      final row = await fetchQualityReviewById(token, id);
      qualityReviewByIdLine = [
        row.id,
        row.targetType,
        row.source,
        if (row.overallScore != null) 'score=${row.overallScore}',
        if (row.passed != null) 'passed=${row.passed}',
        if (row.badCaseCategory != null) 'badCase=${row.badCaseCategory}',
      ].join(' · ');
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      loadingQualityReviewById = false;
      notifyListeners();
    }
  }

  Future<void> loadQualityStats() async {
    final token = _accessToken;
    if (token == null) return;
    loadingQualityStats = true;
    qualityStatsLine = null;
    _setError(null);
    notifyListeners();
    try {
      final rows = await fetchQualityStats(token);
      qualityStatsRows = _mapStatsRowsToDashboardStats(rows);
      qualityStatsLine = rows.isEmpty
          ? _l10nResolved.qualityReviewsEmpty
          : summarizeQualityStatsRows(rows, maxItems: 4, l10n: _l10nResolved);
      _refreshQualityDashboardLine();
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      loadingQualityStats = false;
      notifyListeners();
    }
  }

  Future<void> loadQualityStagePassRate() async {
    final token = _accessToken;
    if (token == null) return;
    loadingQualityStagePassRate = true;
    qualityStagePassRateLine = null;
    _setError(null);
    notifyListeners();
    try {
      final rows = await fetchQualityStagePassRate(token);
      final gradeRows = await fetchQualityStageGradeDistribution(token);
      qualityStagePassRateRows = _mapStagePassRateRows(rows);
      qualityStageGradeRows = _mapStageGradeRows(gradeRows);
      qualityStagePassRateLine = rows.isEmpty
          ? _l10nResolved.qualityReviewsEmpty
          : summarizeStagePassRateRows(rows, maxItems: 6, l10n: _l10nResolved);
      qualityStageGradeLine = summarizeStageGradeDistributionRows(
        gradeRows,
        maxItems: 6,
        l10n: _l10nResolved,
      );
      _refreshQualityDashboardLine();
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      loadingQualityStagePassRate = false;
      notifyListeners();
    }
  }

  Future<void> loadQualityDashboard({
    int? projectId,
    bool refreshReadModel = false,
  }) async {
    final token = _accessToken;
    if (token == null) return;
    loadingQualityDashboard = true;
    if (refreshReadModel) {
      refreshingQualityDashboardReadModel = true;
    }
    _setError(null);
    notifyListeners();
    try {
      final loc = _l10nResolved;
      if (refreshReadModel) {
        final refresh = await refreshQualityDashboardReadModel(
          token,
          onlyIfStale: true,
        );
        final timeStr = refresh.refreshedAt.toLocal().toString().substring(
          0,
          19,
        );
        qualityDashboardRefreshLine = refresh.performed
            ? loc.qualityReviewsDashboardRefreshPerformed(
                refresh.rowCount,
                refresh.sourceReviewCount,
                refresh.sourceUsageCount,
                timeStr,
              )
            : loc.qualityReviewsDashboardRefreshSkipped(timeStr);
      }
      final dashboard = await fetchQualityDashboard(
        token,
        projectId: projectId,
        scriptId: null,
      );

      qualityDashboardMeta = dashboard.meta;
      qualityStatsRows = dashboard.stats;
      final scopePrefix = dashboard.stats.isNotEmpty
          ? loc.qualityReviewsDashboardStatsScopePrefix(
              dashboard.stats.first.scope,
            )
          : '';
      qualityStatsLine = dashboard.stats.isEmpty
          ? loc.qualityReviewsNoQualityStats
          : '$scopePrefix${dashboard.stats.map((row) {
              final passPct = row.passRatePercent.toStringAsFixed(1);
              final avgScore = row.avgOverallScore.toStringAsFixed(1);
              return loc.qualityReviewsDashboardTargetStatRow(row.targetType, row.totalReviews, passPct, avgScore);
            }).join(' | ')}';
      qualityStagePassRateRows = dashboard.stagePassRate;
      qualityStagePassRateLine = dashboard.stagePassRate.isEmpty
          ? loc.qualityReviewsNoStagePassRate
          : dashboard.stagePassRate
                .map((row) {
                  final date = row.reviewDate.toIso8601String().substring(
                    0,
                    10,
                  );
                  final passPct = row.passRatePercent.toStringAsFixed(1);
                  return loc.qualityReviewsDashboardStagePassRateRow(
                    date,
                    row.targetType,
                    passPct,
                    row.totalReviews,
                  );
                })
                .join(' | ');
      qualityStageGradeRows = dashboard.stageGradeDistribution;
      qualityStageGradeLine = summarizeDashboardStageGradeDistributionRows(
        dashboard.stageGradeDistribution,
        maxItems: 6,
        l10n: _l10nResolved,
      );
      qualityScopeInsightRows = dashboard.scopeInsights;
      qualityScopeInsightsLine = summarizeDashboardScopeInsightRows(
        dashboard.scopeInsights,
        maxItems: 4,
        l10n: _l10nResolved,
      );
      qualityTokenEfficiencyRows = dashboard.tokenEfficiency;
      qualityTokenEfficiencyLine = summarizeDashboardTokenEfficiencyRows(
        dashboard.tokenEfficiency,
        maxItems: 4,
        l10n: _l10nResolved,
      );
      qualityBadCaseStatItems = dashboard.badCaseStats;
      qualityBadCaseStatsLine = summarizeBadCaseStatItems(
        dashboard.badCaseStats,
        maxItems: 5,
        l10n: _l10nResolved,
      );
      qualityDashboardFreshnessLine = _buildQualityDashboardFreshnessLine(
        dashboard.meta,
      );
      _refreshQualityDashboardLine();
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      loadingQualityDashboard = false;
      refreshingQualityDashboardReadModel = false;
      notifyListeners();
    }
  }

  String _buildQualityDashboardFreshnessLine(QualityDashboardMeta meta) {
    final loc = _l10nResolved;
    final age = meta.ageSeconds == null
        ? loc.qualityReviewsFreshnessUnknownAge
        : meta.ageSeconds! < 60
        ? '${meta.ageSeconds}s'
        : '${(meta.ageSeconds! / 60).floor()}m';
    final refreshedAt = meta.refreshedAt == null
        ? loc.qualityReviewsFreshnessNever
        : meta.refreshedAt!.toLocal().toString().substring(0, 19);
    final reviewMax = meta.sourceMaxReviewCreatedAt == null
        ? loc.qualityReviewsFreshnessNone
        : meta.sourceMaxReviewCreatedAt!.toLocal().toString().substring(0, 19);
    final usageMax = meta.sourceMaxUsageCreatedAt == null
        ? loc.qualityReviewsFreshnessNone
        : meta.sourceMaxUsageCreatedAt!.toLocal().toString().substring(0, 19);
    final verdict = meta.stale
        ? loc.qualityReviewsFreshnessStale
        : loc.qualityReviewsFreshnessFresh;
    final reason = meta.staleReason == null ? '' : ' · ${meta.staleReason}';
    return '$verdict · age=$age · refreshed=$refreshedAt · snapshot=${meta.snapshotRowCount} · source reviews=${meta.sourceReviewCount} @ $reviewMax · usage=${meta.sourceUsageCount} @ $usageMax$reason';
  }

  void _refreshQualityDashboardLine() {
    qualityDashboardLine = buildQualityDashboardSummary(
      statsSummary: qualityStatsLine,
      stagePassRateSummary: qualityStagePassRateLine,
      stageGradeSummary: qualityStageGradeLine,
      scopeInsightsSummary: qualityScopeInsightsLine,
      tokenEfficiencySummary: qualityTokenEfficiencyLine,
      badCaseStatsSummary: qualityBadCaseStatsLine,
      l10n: _l10nResolved,
    );
  }

  @override
  void dispose() {
    qualityReviewIdController.dispose();
    super.dispose();
  }
}
