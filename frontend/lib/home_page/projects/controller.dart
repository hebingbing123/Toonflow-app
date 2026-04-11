// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageProjectsController on _HomePageState {
  Future<void> _createEmptyProject() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _creatingProject = true;
      _error = null;
    });
    try {
      await createProject(token);
      if (!mounted) return;
      await _loadProjects();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已创建项目')));
    } on RustApiException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creatingProject = false);
    }
  }

  Future<void> _probeAgentMemory() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final projects = _projects;
    if (projects == null || projects.isEmpty) {
      setState(
        () => _error =
            'Load projects first (agent memory needs a legacy project id).',
      );
      return;
    }
    final legacyId = projects.first.legacyId;
    setState(() {
      _loadingAgentMemory = true;
      _error = null;
      _agentMemoryBody = null;
    });
    try {
      final rows = await queryAgentMemory(
        token,
        projectId: legacyId,
        agentType: 'scriptAgent',
      );
      if (!mounted) return;
      var appendBit = '';
      try {
        final id = await appendAgentMemory(
          token,
          projectId: legacyId,
          agentType: 'scriptAgent',
          content: '[flutter probe] ${DateTime.now().toIso8601String()}',
        );
        final short = id.length > 8 ? '${id.substring(0, 8)}…' : id;
        appendBit = ' · append id=$short';
      } on RustApiException catch (e) {
        appendBit = ' · append -> ${e.statusCode}';
      }
      setState(() {
        _agentMemoryBody =
            '${rows.length} message(s) for project $legacyId$appendBit';
        _loadingAgentMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAgentMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAgentMemory = false;
      });
    }
  }

  Future<void> _loadProjects() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingProjects = true;
      _error = null;
      _projects = null;
    });
    try {
      final list = await fetchProjects(token);
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjects = false;
      });
    }
  }

  Future<void> _loadProjectsSummary() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingProjectsSummary = true;
      _error = null;
      _projectsSummaryLine = null;
    });
    try {
      final s = await fetchProjectsSummary(token);
      if (!mounted) return;
      setState(() {
        _projectsSummaryLine =
            'projects=${s.projectCount} scripts=${s.scriptCount} storyboards=${s.storyboardCount} novels=${s.novelCount} roles=${s.roleCount} art_styles=${s.artStyleCount} assets=${s.assetCount} videos=${s.videoCount}';
        _loadingProjectsSummary = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjectsSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjectsSummary = false;
      });
    }
  }

  Future<void> _loadArtStyles() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingArtStyles = true;
      _error = null;
      _artStyles = null;
      _artStylesLine = null;
    });
    try {
      final r = await fetchArtStyles(token);
      if (!mounted) return;
      var line =
          'total=${r.total} · ${r.items.take(5).map((s) => '#${s.legacyId}:${s.name}').join(', ')}${r.items.length > 5 ? '…' : ''}';
      try {
        final probeName =
            '[flutter probe art-style] ${DateTime.now().toIso8601String()}';
        final created = await createArtStyle(token, name: probeName);
        await fetchArtStyleByLegacyId(token, legacyId: created.legacyId);
        await patchArtStyleByLegacyId(
          token,
          created.legacyId,
          <String, dynamic>{'label': 'probe'},
        );
        await deleteArtStyleByLegacyId(token, created.legacyId);
        line += ' · create→get→patch→del ok (#${created.legacyId})';
      } on RustApiException catch (e) {
        line += ' · crud -> ${e.statusCode}';
      }
      setState(() {
        _artStyles = r.items;
        _artStylesLine = line;
        _loadingArtStyles = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingArtStyles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingArtStyles = false;
      });
    }
  }
}
