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
  bool creatingQualityReview = false;
  bool loadingQualityReviewById = false;
  String? qualityStatsLine;
  String? qualityStagePassRateLine;
  String? qualityStageGradeLine;
  String? qualityScopeInsightsLine;
  String? qualityTokenEfficiencyLine;
  String? qualityBadCaseStatsLine;
  String? qualityDashboardLine;
  String? qualityReviewByIdLine;
  List<QualityReview>? qualityReviews;
  List<QualityDashboardTargetStat>? qualityStatsRows;
  List<QualityDashboardStagePassRateItem>? qualityStagePassRateRows;
  List<QualityDashboardStageGradeItem>? qualityStageGradeRows;
  List<QualityDashboardScopeInsightItem>? qualityScopeInsightRows;
  List<QualityDashboardTokenEfficiencyItem>? qualityTokenEfficiencyRows;
  List<BadCaseStatItem>? qualityBadCaseStatItems;

  String? get _accessToken => _accessTokenProvider();

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
    creatingQualityReview = false;
    loadingQualityReviewById = false;
    qualityStatsLine = null;
    qualityStagePassRateLine = null;
    qualityStageGradeLine = null;
    qualityScopeInsightsLine = null;
    qualityTokenEfficiencyLine = null;
    qualityBadCaseStatsLine = null;
    qualityDashboardLine = null;
    qualityReviewByIdLine = null;
    qualityReviews = null;
    qualityStatsRows = null;
    qualityStagePassRateRows = null;
    qualityStageGradeRows = null;
    qualityScopeInsightRows = null;
    qualityTokenEfficiencyRows = null;
    qualityBadCaseStatItems = null;
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
      qualityStatsRows = rows;
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
      qualityStagePassRateRows = rows;
      qualityStageGradeRows = gradeRows;
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

  Future<void> loadQualityDashboard({int? projectId}) async {
    final token = _accessToken;
    if (token == null) return;
    loadingQualityDashboard = true;
    _setError(null);
    notifyListeners();
    try {
      final dashboard = await fetchQualityDashboard(
        token,
        projectId: projectId,
        scriptId: null,
      );

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
      _refreshQualityDashboardLine();
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _setError);
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingQualityDashboard = false;
      notifyListeners();
    }
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
