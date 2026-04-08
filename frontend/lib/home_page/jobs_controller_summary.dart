// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageJobsControllerSummary on _HomePageState {
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
}
