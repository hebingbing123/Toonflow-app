import 'package:flutter/material.dart';

import '../../rust_api.dart';

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
  bool creatingQualityReview = false;
  bool loadingQualityReviewById = false;
  String? qualityStatsLine;
  String? qualityStagePassRateLine;
  String? qualityReviewByIdLine;
  List<QualityReview>? qualityReviews;

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
    creatingQualityReview = false;
    loadingQualityReviewById = false;
    qualityStatsLine = null;
    qualityStagePassRateLine = null;
    qualityReviewByIdLine = null;
    qualityReviews = null;
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
      _setError(e.toString());
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
      _setError(e.toString());
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
      _setError(e.toString());
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
      qualityStatsLine = rows.isEmpty
          ? '(empty)'
          : rows
                .map(
                  (row) =>
                      '${row.targetType}: total=${row.totalReviews}, pass=${row.passRatePercent.toStringAsFixed(1)}%, avg=${row.avgOverallScore.toStringAsFixed(1)}',
                )
                .join(' | ');
    } on RustApiException catch (e) {
      _setError(e.toString());
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
      qualityStagePassRateLine = rows.isEmpty
          ? '(empty)'
          : rows
                .take(6)
                .map(
                  (row) =>
                      '${row.reviewDate.substring(0, 10)} ${row.targetType}: pass=${row.passRatePercent?.toStringAsFixed(1) ?? "n/a"}%, total=${row.totalReviews}',
                )
                .join(' | ');
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingQualityStagePassRate = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    qualityReviewIdController.dispose();
    super.dispose();
  }
}
