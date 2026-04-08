// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageJobsController on _HomePageState {
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
}
