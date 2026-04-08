// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageJobsControllerList on _HomePageState {
  Future<void> _loadJobs() async {
    await _loadJobsList();
  }

  Future<void> _loadJobsKindFlutterProbe() async {
    await _loadJobsList(kind: 'flutter.probe');
  }

  Future<void> _loadJobsStatusFailed() async {
    await _loadJobsList(status: 'failed');
  }

  Future<void> _loadJobsKindProbeStatusQueued() async {
    await _loadJobsList(kind: 'flutter.probe', status: 'queued');
  }

  Future<void> _loadJobsList({String? kind, String? status}) async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobs = true;
      _error = null;
      _jobs = null;
    });
    try {
      final list = await fetchJobs(token, kind: kind, status: status);
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    }
  }
}
