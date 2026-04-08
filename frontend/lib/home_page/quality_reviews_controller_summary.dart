// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageQualityReviewsControllerSummary on _HomePageState {
  Future<void> _loadQualityStats() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingQualityStats = true;
      _error = null;
      _qualityStatsLine = null;
    });
    try {
      final rows = await fetchQualityStats(token);
      if (!mounted) return;
      setState(() {
        _qualityStatsLine = rows.isEmpty
            ? '(empty)'
            : rows
                  .map(
                    (r) =>
                        '${r.targetType}: total=${r.totalReviews}, pass=${r.passRatePercent.toStringAsFixed(1)}%, avg=${r.avgOverallScore.toStringAsFixed(1)}',
                  )
                  .join(' | ');
        _loadingQualityStats = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingQualityStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingQualityStats = false;
      });
    }
  }

  Future<void> _loadQualityStagePassRate() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingQualityStagePassRate = true;
      _error = null;
      _qualityStagePassRateLine = null;
    });
    try {
      final rows = await fetchQualityStagePassRate(token);
      if (!mounted) return;
      setState(() {
        _qualityStagePassRateLine = rows.isEmpty
            ? '(empty)'
            : rows
                  .take(6)
                  .map(
                    (r) =>
                        '${r.reviewDate.substring(0, 10)} ${r.targetType}: pass=${r.passRatePercent?.toStringAsFixed(1) ?? "n/a"}%, total=${r.totalReviews}',
                  )
                  .join(' | ');
        _loadingQualityStagePassRate = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingQualityStagePassRate = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingQualityStagePassRate = false;
      });
    }
  }
}
