// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageJobsControllerActions on _HomePageState {
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
