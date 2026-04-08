// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageJobsController on _HomePageState {
  Future<void> _loadJobKinds() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobKinds = true;
      _error = null;
      _jobKindsLine = null;
    });
    try {
      final kinds = await fetchJobKinds(token);
      if (!mounted) return;
      setState(() {
        _jobKindsLine = kinds.isEmpty ? '(empty)' : kinds.join(', ');
        _loadingJobKinds = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKinds = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKinds = false;
      });
    }
  }

  Future<void> _loadJobKindSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobKindSummary = true;
      _error = null;
      _jobKindSummaryLine = null;
    });
    try {
      final rows = await fetchJobKindSummaries(token);
      if (!mounted) return;
      setState(() {
        _jobKindSummaryLine = rows.isEmpty
            ? '(empty)'
            : rows.map((r) => '${r.kind}: ${r.jobCount}').join(', ');
        _loadingJobKindSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKindSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobKindSummary = false;
      });
    }
  }

  Future<void> _loadJobStatusSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobStatusSummary = true;
      _error = null;
      _jobStatusSummaryLine = null;
    });
    try {
      final rows = await fetchJobStatusSummaries(token);
      if (!mounted) return;
      setState(() {
        _jobStatusSummaryLine = rows.isEmpty
            ? '(empty)'
            : rows.map((r) => '${r.status}: ${r.jobCount}').join(', ');
        _loadingJobStatusSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobStatusSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobStatusSummary = false;
      });
    }
  }

  Future<void> _fetchJobById() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final id = _jobIdCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loadingJobById = true;
      _error = null;
      _jobByIdLine = null;
    });
    try {
      final j = await fetchJob(token, id);
      if (!mounted) return;
      setState(() {
        final parts = <String>[
          '${j.kind} · ${j.status}',
          'updated ${j.updatedAt}',
        ];
        if (j.claimedBy != null && j.claimedBy!.isNotEmpty) {
          parts.add('claimed_by=${j.claimedBy}');
        }
        _jobByIdLine = parts.join(' · ');
        _loadingJobById = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobById = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobById = false;
      });
    }
  }

  Future<void> _cancelQueuedJob(JobRow j) async {
    final token = _session?.accessToken;
    if (token == null || (j.status != 'queued' && j.status != 'running')) {
      return;
    }
    setState(() {
      _cancellingJobId = j.id;
      _error = null;
    });
    try {
      await cancelJob(token, j.id);
      if (!mounted) return;
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _cancellingJobId = null);
      }
    }
  }

  Future<void> _retryFailedJob(JobRow j) async {
    final token = _session?.accessToken;
    if (token == null || j.status != 'failed') return;
    setState(() {
      _retryingJobId = j.id;
      _error = null;
    });
    try {
      await retryJob(token, j.id);
      if (!mounted) return;
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _retryingJobId = null);
      }
    }
  }

  Future<void> _createProbeJob() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _creatingJob = true;
      _error = null;
    });
    try {
      final key = 'flutter-probe-idem-${DateTime.now().millisecondsSinceEpoch}';
      final j1 = await createJob(token, 'flutter.probe', idempotencyKey: key);
      final j2 = await createJob(token, 'flutter.probe', idempotencyKey: key);
      if (!mounted) return;
      if (j1.id != j2.id) {
        setState(() {
          _error =
              'POST /api/v1/jobs idempotency: expected same id, got '
              '${j1.id} vs ${j2.id}';
          _creatingJob = false;
        });
        return;
      }
      setState(() => _creatingJob = false);
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingJob = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingJob = false;
      });
    }
  }
}
