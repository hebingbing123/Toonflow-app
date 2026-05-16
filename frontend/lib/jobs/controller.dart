import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import 'product_scope.dart';
import '../../rust_api.dart';

typedef JobsAccessTokenProvider = String? Function();
typedef JobsErrorSink = void Function(String? error);
typedef JobsScopeSink = void Function(JobProductScope scope);
typedef JobsL10nProvider = AppLocalizations? Function();

class JobsController extends ChangeNotifier {
  JobsController({
    required JobsAccessTokenProvider accessTokenProvider,
    required JobsErrorSink onErrorChanged,
    required JobsL10nProvider l10nProvider,
    JobsScopeSink? onJobScopeResolved,
  }) : _accessTokenProvider = accessTokenProvider,
       _l10nProvider = l10nProvider,
       _onErrorChanged = onErrorChanged,
       _onJobScopeResolved = onJobScopeResolved;

  final JobsAccessTokenProvider _accessTokenProvider;
  final JobsL10nProvider _l10nProvider;
  final JobsErrorSink _onErrorChanged;
  final JobsScopeSink? _onJobScopeResolved;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _wsToken;

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
  String? _lastKindFilter;
  String? _lastStatusFilter;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  void onJobIdChanged(String _) {
    notifyListeners();
  }

  void selectJob(JobRow job) {
    jobIdController.text = job.id;
    final scope = jobProductScopeFromRow(job);
    if (scope.hasProjectScope) {
      _onJobScopeResolved?.call(scope);
    }
    notifyListeners();
  }

  void reset() {
    unawaited(closeLiveUpdates());
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
    _lastKindFilter = null;
    _lastStatusFilter = null;
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
    await _ensureLiveUpdates(token);
    loadingJobs = true;
    jobs = null;
    _lastKindFilter = kind;
    _lastStatusFilter = status;
    _setError(null);
    notifyListeners();
    try {
      jobs = await fetchJobs(token, kind: kind, status: status);
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
      jobKindsLine = kinds.isEmpty
          ? _l10nResolved.jobsEmptyValue
          : kinds.join(', ');
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
          ? _l10nResolved.jobsEmptyValue
          : rows
                .map(
                  (r) => _l10nResolved.jobsKindCountEntry(r.kind, r.jobCount),
                )
                .join(', ');
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
          ? _l10nResolved.jobsEmptyValue
          : rows
                .map(
                  (r) =>
                      _l10nResolved.jobsStatusCountEntry(r.status, r.jobCount),
                )
                .join(', ');
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
      final scope = jobProductScopeFromRow(job);
      if (scope.hasProjectScope) {
        _onJobScopeResolved?.call(scope);
      }
      jobByIdLine = _formatJobDetailLine(job);
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
      final updated = await cancelJob(token, job.id);
      _upsertJob(updated);
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
      final updated = await retryJob(token, job.id);
      _upsertJob(updated);
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
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
          _l10nResolved.jobsIdempotencyMismatch(firstJob.id, secondJob.id),
        );
        return;
      }
      _upsertJob(secondJob);
    } catch (e) {
      reportRustOrDescribeApiError(e, onErrorChanged: _setError, l10n: _l10nResolved);
    } finally {
      creatingJob = false;
      notifyListeners();
    }
  }

  Future<void> _ensureLiveUpdates(String token) async {
    if (_ws != null && _wsToken == token) {
      return;
    }
    await closeLiveUpdates();
    try {
      final channel = WebSocketChannel.connect(
        rustWebSocketUri(kApiBaseUrl, accessToken: token),
      );
      _ws = channel;
      _wsToken = token;
      _wsSub = channel.stream.listen(
        (message) => _handleWsMessage(message.toString()),
        onError: (_) {
          _ws = null;
          _wsSub = null;
          _wsToken = null;
        },
        onDone: () {
          _ws = null;
          _wsSub = null;
          _wsToken = null;
        },
      );
    } catch (_) {
      _ws = null;
      _wsSub = null;
      _wsToken = null;
    }
  }

  void _handleWsMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      if (decoded['type'] != 'generation.job.updated') {
        return;
      }
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) {
        return;
      }
      _upsertJob(JobRow.fromJson(payload));
    } catch (_) {
      // Ignore unrelated WS envelopes.
    }
  }

  void _upsertJob(JobRow updated) {
    if (jobs != null) {
      final next = List<JobRow>.from(jobs!);
      final index = next.indexWhere((job) => job.id == updated.id);
      final matchesFilter = _matchesCurrentFilters(updated);
      if (index >= 0 && matchesFilter) {
        next[index] = updated;
      } else if (index >= 0 && !matchesFilter) {
        next.removeAt(index);
      } else if (matchesFilter) {
        next.insert(0, updated);
      }
      jobs = next;
    }
    if (jobIdController.text.trim() == updated.id) {
      jobByIdLine = _formatJobDetailLine(updated);
    }
    notifyListeners();
  }

  String _formatJobDetailLine(JobRow job) {
    final parts = <String>[
      '${job.kind} · ${job.status}',
      _l10nResolved.jobsUpdatedAt(job.updatedAt),
    ];
    if (job.claimedBy != null && job.claimedBy!.isNotEmpty) {
      parts.add(
        _l10nResolved.jobsClaimedBy(job.claimedBy!),
      );
    }
    if (job.errorMessage != null && job.errorMessage!.isNotEmpty) {
      parts.add(
        _l10nResolved.jobsFailedReason(job.errorMessage!),
      );
    }
    return parts.join(' · ');
  }

  bool _matchesCurrentFilters(JobRow row) {
    final matchesKind =
        _lastKindFilter == null ||
        _lastKindFilter!.trim().isEmpty ||
        row.kind == _lastKindFilter;
    final matchesStatus =
        _lastStatusFilter == null ||
        _lastStatusFilter!.trim().isEmpty ||
        row.status == _lastStatusFilter;
    return matchesKind && matchesStatus;
  }

  Future<void> closeLiveUpdates() async {
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _ws = null;
    _wsSub = null;
    _wsToken = null;
  }

  @override
  void dispose() {
    unawaited(closeLiveUpdates());
    jobIdController.dispose();
    super.dispose();
  }
}
