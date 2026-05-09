import 'package:flutter/material.dart';

import '../../rust_api.dart';
import 'support.dart';

typedef QualityReviewsAccessTokenProvider = String? Function();
typedef QualityReviewsErrorSink = void Function(String? error);

class QualityReviewsController extends ChangeNotifier {
  QualityReviewsController({
    required QualityReviewsAccessTokenProvider accessTokenProvider,
    required QualityReviewsErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final QualityReviewsAccessTokenProvider _accessTokenProvider;
  final QualityReviewsErrorSink _onErrorChanged;

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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
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
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
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
          ? '(empty)'
          : summarizeQualityStatsRows(rows, maxItems: 4);
      _refreshQualityDashboardLine();
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
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
          ? '(empty)'
          : summarizeStagePassRateRows(rows, maxItems: 6);
      qualityStageGradeLine = summarizeStageGradeDistributionRows(
        gradeRows,
        maxItems: 6,
      );
      _refreshQualityDashboardLine();
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
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
      if (refreshReadModel) {
        final refresh = await refreshQualityDashboardReadModel(
          token,
          onlyIfStale: true,
        );
        qualityDashboardRefreshLine = refresh.performed
            ? '底层快照已刷新 ${refresh.rowCount} 条 review fact · reviews=${refresh.sourceReviewCount} · usage=${refresh.sourceUsageCount} · ${refresh.refreshedAt.toLocal().toString().substring(0, 19)}'
            : '底层快照保持现状 · fresh snapshot skipped refresh · ${refresh.refreshedAt.toLocal().toString().substring(0, 19)}';
      }
      final dashboard = await fetchQualityDashboard(
        token,
        projectId: projectId,
        scriptId: null,
      );

      qualityDashboardMeta = dashboard.meta;
      qualityStatsRows = dashboard.stats;
      qualityStatsLine = dashboard.stats.isEmpty
          ? '当前没有质量统计'
          : dashboard.stats
                .map(
                  (row) =>
                      '${row.targetType}: total=${row.totalReviews}, pass=${row.passRatePercent.toStringAsFixed(1)}%, avg=${row.avgOverallScore.toStringAsFixed(1)}',
                )
                .join(' | ');
      qualityStagePassRateRows = dashboard.stagePassRate;
      qualityStagePassRateLine = dashboard.stagePassRate.isEmpty
          ? '当前没有阶段通过率'
          : dashboard.stagePassRate
                .map(
                  (row) =>
                      '${row.reviewDate.toIso8601String().substring(0, 10)} ${row.targetType}: pass=${row.passRatePercent.toStringAsFixed(1)}%, total=${row.totalReviews}',
                )
                .join(' | ');
      qualityStageGradeRows = dashboard.stageGradeDistribution;
      qualityStageGradeLine = summarizeDashboardStageGradeDistributionRows(
        dashboard.stageGradeDistribution,
        maxItems: 6,
      );
      qualityScopeInsightRows = dashboard.scopeInsights;
      qualityScopeInsightsLine = summarizeDashboardScopeInsightRows(
        dashboard.scopeInsights,
        maxItems: 4,
      );
      qualityTokenEfficiencyRows = dashboard.tokenEfficiency;
      qualityTokenEfficiencyLine = summarizeDashboardTokenEfficiencyRows(
        dashboard.tokenEfficiency,
        maxItems: 4,
      );
      qualityBadCaseStatItems = dashboard.badCaseStats;
      qualityBadCaseStatsLine = summarizeBadCaseStatItems(
        dashboard.badCaseStats,
        maxItems: 5,
      );
      qualityDashboardFreshnessLine = _buildQualityDashboardFreshnessLine(
        dashboard.meta,
      );
      _refreshQualityDashboardLine();
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingQualityDashboard = false;
      refreshingQualityDashboardReadModel = false;
      notifyListeners();
    }
  }

  String _buildQualityDashboardFreshnessLine(QualityDashboardMeta meta) {
    final age = meta.ageSeconds == null
        ? 'unknown_age'
        : meta.ageSeconds! < 60
        ? '${meta.ageSeconds}s'
        : '${(meta.ageSeconds! / 60).floor()}m';
    final refreshedAt = meta.refreshedAt == null
        ? 'never'
        : meta.refreshedAt!.toLocal().toString().substring(0, 19);
    final reviewMax = meta.sourceMaxReviewCreatedAt == null
        ? 'none'
        : meta.sourceMaxReviewCreatedAt!.toLocal().toString().substring(0, 19);
    final usageMax = meta.sourceMaxUsageCreatedAt == null
        ? 'none'
        : meta.sourceMaxUsageCreatedAt!.toLocal().toString().substring(0, 19);
    final verdict = meta.stale ? 'STALE' : 'fresh';
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
    );
  }

  @override
  void dispose() {
    qualityReviewIdController.dispose();
    super.dispose();
  }
}
