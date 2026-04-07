// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageQualityReviewsController on _HomePageState {
  Future<void> _loadQualityReviews({bool onlyBadCases = false}) async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      if (onlyBadCases) {
        _loadingQualityBadCases = true;
      } else {
        _loadingQualityReviews = true;
      }
      _error = null;
      _qualityReviews = null;
    });
    try {
      final rows = await fetchQualityReviews(
        token,
        isBadCase: onlyBadCases ? true : null,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _qualityReviews = rows;
        if (onlyBadCases) {
          _loadingQualityBadCases = false;
        } else {
          _loadingQualityReviews = false;
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        if (onlyBadCases) {
          _loadingQualityBadCases = false;
        } else {
          _loadingQualityReviews = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        if (onlyBadCases) {
          _loadingQualityBadCases = false;
        } else {
          _loadingQualityReviews = false;
        }
      });
    }
  }

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

  Future<void> _createQualityReviewProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _creatingQualityReview = true;
      _error = null;
    });
    try {
      final created = await createQualityReview(
        token,
        CreateQualityReviewBody(
          targetType: 'output',
          targetId: 'flutter-probe-${DateTime.now().millisecondsSinceEpoch}',
          source: 'manual',
          overallScore: 82,
          passed: true,
          comments: 'flutter quality probe',
          skillVersion: 'flutter.probe',
          modelName: 'manual',
          modelParams: const {'surface': 'home_page'},
          isBadCase: false,
        ),
      );
      if (!mounted) return;
      setState(() {
        _creatingQualityReview = false;
        _qualityReviewIdCtrl.text = created.id;
        _qualityReviewByIdLine =
            '${created.id} · ${created.targetType} · ${created.source} · score=${created.overallScore ?? "n/a"}';
      });
      await _loadQualityReviews();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingQualityReview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingQualityReview = false;
      });
    }
  }

  Future<void> _fetchQualityReviewById() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final id = _qualityReviewIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loadingQualityReviewById = true;
      _error = null;
      _qualityReviewByIdLine = null;
    });
    try {
      final row = await fetchQualityReviewById(token, id);
      if (!mounted) return;
      setState(() {
        _qualityReviewByIdLine = [
          row.id,
          row.targetType,
          row.source,
          if (row.overallScore != null) 'score=${row.overallScore}',
          if (row.passed != null) 'passed=${row.passed}',
          if (row.badCaseCategory != null) 'badCase=${row.badCaseCategory}',
        ].join(' · ');
        _loadingQualityReviewById = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingQualityReviewById = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingQualityReviewById = false;
      });
    }
  }
}
