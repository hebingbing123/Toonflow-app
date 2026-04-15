import 'package:flutter/material.dart';

import '../../rust_api.dart';

typedef JobsAccessTokenProvider = String? Function();
typedef JobsErrorSink = void Function(String? error);

class JobsController extends ChangeNotifier {
  JobsController({
    required JobsAccessTokenProvider accessTokenProvider,
    required JobsErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final JobsAccessTokenProvider _accessTokenProvider;
  final JobsErrorSink _onErrorChanged;

  final TextEditingController jobIdController = TextEditingController();

  bool loadingJobs = false;
  bool loadingJobKinds = false;
  bool loadingJobKindSummary = false;
  bool loadingJobStatusSummary = false;
  bool creatingJob = false;
  bool loadingJobById = false;
  String? cancellingJobId;
  String? retryingJobId;
  List<JobRow>? jobs;
  String? jobByIdLine;
  String? jobKindsLine;
  String? jobKindSummaryLine;
  String? jobStatusSummaryLine;

  String? get _accessToken => _accessTokenProvider();

  void onJobIdChanged(String _) {
    notifyListeners();
  }

  void selectJob(JobRow job) {
    jobIdController.text = job.id;
    notifyListeners();
  }

  void reset() {
    loadingJobs = false;
    loadingJobKinds = false;
    loadingJobKindSummary = false;
    loadingJobStatusSummary = false;
    creatingJob = false;
    loadingJobById = false;
    cancellingJobId = null;
    retryingJobId = null;
    jobs = null;
    jobByIdLine = null;
    jobKindsLine = null;
    jobKindSummaryLine = null;
    jobStatusSummaryLine = null;
    jobIdController.clear();
    notifyListeners();
  }

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  Future<void> loadJobs() async {
    await _loadJobsList();
  }

  Future<void> loadJobsKindFlutterProbe() async {
    await _loadJobsList(kind: 'flutter.probe');
  }

  Future<void> loadJobsStatusFailed() async {
    await _loadJobsList(status: 'failed');
  }

  Future<void> loadJobsKindProbeStatusQueued() async {
    await _loadJobsList(kind: 'flutter.probe', status: 'queued');
  }

  Future<void> _loadJobsList({String? kind, String? status}) async {
    final token = _accessToken;
    if (token == null) return;
    loadingJobs = true;
    jobs = null;
    _setError(null);
    notifyListeners();
    try {
      jobs = await fetchJobs(token, kind: kind, status: status);
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingJobs = false;
      notifyListeners();
    }
  }

  Future<void> loadJobKinds() async {
    final token = _accessToken;
    if (token == null) return;
    loadingJobKinds = true;
    jobKindsLine = null;
    _setError(null);
    notifyListeners();
    try {
      final kinds = await fetchJobKinds(token);
      jobKindsLine = kinds.isEmpty ? '(empty)' : kinds.join(', ');
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingJobKinds = false;
      notifyListeners();
    }
  }

  Future<void> loadJobKindSummary() async {
    final token = _accessToken;
    if (token == null) return;
    loadingJobKindSummary = true;
    jobKindSummaryLine = null;
    _setError(null);
    notifyListeners();
    try {
      final rows = await fetchJobKindSummaries(token);
      jobKindSummaryLine = rows.isEmpty
          ? '(empty)'
          : rows.map((r) => '${r.kind}: ${r.jobCount}').join(', ');
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingJobKindSummary = false;
      notifyListeners();
    }
  }

  Future<void> loadJobStatusSummary() async {
    final token = _accessToken;
    if (token == null) return;
    loadingJobStatusSummary = true;
    jobStatusSummaryLine = null;
    _setError(null);
    notifyListeners();
    try {
      final rows = await fetchJobStatusSummaries(token);
      jobStatusSummaryLine = rows.isEmpty
          ? '(empty)'
          : rows.map((r) => '${r.status}: ${r.jobCount}').join(', ');
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingJobStatusSummary = false;
      notifyListeners();
    }
  }

  Future<void> fetchJobById() async {
    final token = _accessToken;
    if (token == null) return;
    final id = jobIdController.text.trim();
    if (id.isEmpty) return;
    loadingJobById = true;
    jobByIdLine = null;
    _setError(null);
    notifyListeners();
    try {
      final job = await fetchJob(token, id);
      final parts = <String>[
        '${job.kind} · ${job.status}',
        'updated ${job.updatedAt}',
      ];
      if (job.claimedBy != null && job.claimedBy!.isNotEmpty) {
        parts.add('claimed_by=${job.claimedBy}');
      }
      jobByIdLine = parts.join(' · ');
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingJobById = false;
      notifyListeners();
    }
  }

  Future<void> cancelQueuedJob(JobRow job) async {
    final token = _accessToken;
    if (token == null || (job.status != 'queued' && job.status != 'running')) {
      return;
    }
    cancellingJobId = job.id;
    _setError(null);
    notifyListeners();
    try {
      await cancelJob(token, job.id);
      await loadJobs();
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      cancellingJobId = null;
      notifyListeners();
    }
  }

  Future<void> retryFailedJob(JobRow job) async {
    final token = _accessToken;
    if (token == null || job.status != 'failed') return;
    retryingJobId = job.id;
    _setError(null);
    notifyListeners();
    try {
      await retryJob(token, job.id);
      await loadJobs();
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      retryingJobId = null;
      notifyListeners();
    }
  }

  Future<void> createProbeJob() async {
    final token = _accessToken;
    if (token == null) return;
    creatingJob = true;
    _setError(null);
    notifyListeners();
    try {
      final key = 'flutter-probe-idem-${DateTime.now().millisecondsSinceEpoch}';
      final firstJob = await createJob(
        token,
        'flutter.probe',
        idempotencyKey: key,
      );
      final secondJob = await createJob(
        token,
        'flutter.probe',
        idempotencyKey: key,
      );
      if (firstJob.id != secondJob.id) {
        _setError(
          'POST /api/v1/jobs idempotency: expected same id, got '
          '${firstJob.id} vs ${secondJob.id}',
        );
        return;
      }
      creatingJob = false;
      notifyListeners();
      await loadJobs();
      return;
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      creatingJob = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    jobIdController.dispose();
    super.dispose();
  }
}
