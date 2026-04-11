// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageSkillsHarnessController on _HomePageState {
  Future<void> _loadHarnessTools() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingHarnessTools = true;
      _error = null;
      _harnessToolsLine = null;
    });
    try {
      final r = await fetchHarnessTools(token);
      if (!mounted) return;
      setState(() {
        _harnessToolsLine = r.tools
            .map((t) => '${t.name}: ${t.description}')
            .join('\n');
        _loadingHarnessTools = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    }
  }

  Future<void> _loadSkillsAggregate() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillsSummary = true;
      _error = null;
      _skillsAggregateLine = null;
    });
    try {
      final s = await fetchSkillsSummary(token);
      if (!mounted) return;
      setState(() {
        _skillsAggregateLine =
            '${s.markdownFileCount} md files, ${s.totalBytes} bytes total';
        _loadingSkillsSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillsSummary = false;
      });
    }
  }

  Future<void> _loadSkillList() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillList = true;
      _error = null;
      _skillsListSummary = null;
    });
    try {
      final list = await fetchSkills(token);
      if (!mounted) return;
      final sample = list.take(5).map((m) => m.path).join(', ');
      setState(() {
        _skillsListSummary =
            '${list.length} files; sample: ${sample.isEmpty ? '—' : sample}';
        _loadingSkillList = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    }
  }

}
