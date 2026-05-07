// Part extensions call `setState` on `_ShortVideoSpaceSectionState`; analyzer treats
// extension `this` as the extension type, not `State` (false positive).
// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

extension ShortVideoSpaceSectionProject on _ShortVideoSpaceSectionState {
  Future<void> _loadProjects() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _projects = const <ProjectRow>[];
        _selectedProjectId = null;
        _projectConfigLine = '当前未登录，暂时无法把短视频模式写回项目。';
      });
      return;
    }
    setState(() {
      _loadingProjects = true;
      _projectConfigLine = null;
    });
    try {
      final projects = await fetchProjects(token);
      if (!mounted) {
        return;
      }
      final selectedId = _resolveProjectIdAfterReload(projects);
      setState(() {
        _projects = projects;
        _selectedProjectId = selectedId;
      });
      _applyProjectPreset(_selectedProject);
      _syncSelectedProjectContext();
      _loadProjectOverview();
      if (projects.isEmpty) {
        setState(() {
          _projectConfigLine = '还没有项目，可先去项目区创建一个短剧项目。';
        });
      }
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '读取项目失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '读取项目失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjects = false;
        });
      }
    }
  }

  String? _resolveProjectIdAfterReload(List<ProjectRow> projects) {
    if (projects.isEmpty) {
      return null;
    }
    final currentId = _selectedProjectId;
    if (currentId != null &&
        projects.any((project) => project.id == currentId)) {
      return currentId;
    }
    return projects.first.id;
  }

  void _applyProjectPreset(ProjectRow? project) {
    if (project == null) {
      return;
    }
    setState(() {
      _mode = _modeFromProject(project);
      _videoRatio = _normalizeVideoRatio(project.videoRatio);
      _targetMarket = project.targetMarket ?? 'domestic';
      final tp = project.targetPlatforms;
      _targetPlatforms = (tp != null && tp.isNotEmpty)
          ? List<String>.from(tp)
          : <String>['douyin'];
      _durationStrategy = project.durationStrategy ?? 'short';
      _voiceProfile = project.voiceProfile ?? '';
      _subtitleStyle = project.subtitleStyle ?? '';
      _bgmStrategy = project.bgmStrategy ?? '';
    });
  }

  void _onPublishPlatformTapped(String platformId) {
    setState(() {
      final next = List<String>.from(_targetPlatforms);
      if (next.contains(platformId)) {
        if (next.length <= 1) {
          return;
        }
        next.remove(platformId);
      } else {
        next.add(platformId);
      }
      _targetPlatforms = next;
    });
  }

  void _syncSelectedProjectContext() {
    final project = _selectedProject;
    widget.onSyncProjectContext(project?.numericId);
  }

  ShortVideoMode _modeFromProject(ProjectRow project) {
    final value = (project.mode ?? '').trim().toLowerCase();
    if (value.contains('live') ||
        value.contains('real') ||
        value.contains('真人')) {
      return ShortVideoMode.liveAction;
    }
    return ShortVideoMode.animated;
  }

  String _normalizeVideoRatio(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed == '16:9' || trimmed == '1:1') {
      return trimmed;
    }
    return '9:16';
  }

  Future<void> _createProjectFromSpace() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _projectConfigLine = '请先登录后再创建短剧项目。';
      });
      return;
    }
    setState(() {
      _creatingProject = true;
      _projectConfigLine = null;
    });
    final defaultName = _isAnimated ? '动漫短剧项目' : '真人短剧项目';
    final storedMode = _isAnimated
        ? 'animated.short_drama'
        : 'live_action.short_drama';
    try {
      final created = await createProject(
        token,
        fields: {
          'name': defaultName,
          'projectType': 'short_drama',
          'mode': storedMode,
          'videoRatio': _videoRatio,
          'targetMarket': _targetMarket,
          'targetPlatforms': _targetPlatforms,
          'durationStrategy': _durationStrategy,
          if (_voiceProfile.trim().isNotEmpty)
            'voiceProfile': _voiceProfile.trim(),
          if (_subtitleStyle.trim().isNotEmpty)
            'subtitleStyle': _subtitleStyle.trim(),
          if (_bgmStrategy.trim().isNotEmpty) 'bgmStrategy': _bgmStrategy.trim(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = [created, ..._projects].toList(growable: false);
        _selectedProjectId = created.id;
        _projectConfigLine =
            '已新建项目 #${created.numericId}，并写入 ${shortVideoModeLabel(_mode)} · ${shortVideoVideoRatioLabel(_videoRatio)}。';
      });
      _syncSelectedProjectContext();
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '新建项目失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '新建项目失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingProject = false;
        });
      }
    }
  }

  Future<void> _saveProjectConfig() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      setState(() {
        _projectConfigLine = '请先登录并选择项目。';
      });
      return;
    }
    setState(() {
      _savingProjectConfig = true;
      _projectConfigLine = null;
    });
    final storedMode = _mode == ShortVideoMode.animated
        ? 'animated.short_drama'
        : 'live_action.short_drama';
    try {
      final body = <String, dynamic>{
        'projectType': 'short_drama',
        'mode': storedMode,
        'videoRatio': _videoRatio,
        'targetMarket': _targetMarket,
        'targetPlatforms': _targetPlatforms,
        'durationStrategy': _durationStrategy,
        'voiceProfile': _voiceProfile.trim().isEmpty
            ? null
            : _voiceProfile.trim(),
        'subtitleStyle':
            _subtitleStyle.trim().isEmpty ? null : _subtitleStyle.trim(),
        'bgmStrategy': _bgmStrategy.trim().isEmpty ? null : _bgmStrategy.trim(),
      };
      final updated = await updateProjectByProjectId(token, project.id, body);
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = _projects
            .map((row) => row.id == updated.id ? updated : row)
            .toList(growable: false);
        _selectedProjectId = updated.id;
        _projectConfigLine =
            '已写回项目 #${updated.numericId}：${shortVideoModeLabel(_mode)} · ${shortVideoVideoRatioLabel(_videoRatio)} · 市场 $_targetMarket · 平台 ${_targetPlatforms.length} 个 · 时长 $_durationStrategy';
      });
      _syncSelectedProjectContext();
      _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '保存失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '保存失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingProjectConfig = false;
        });
      }
    }
  }

  VoidCallback _nextStepAction() {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: _isAnimated,
      project: _selectedProject,
      stats: _projectStats,
      recentProjectTasks: _recentProjectTasks,
      qualityScopeInsight: _qualityScopeInsight,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    switch (plan.target) {
      case ShortVideoNextStepTarget.projects:
        return widget.onOpenProjects;
      case ShortVideoNextStepTarget.scriptWorkspace:
        return () {
          _syncSelectedProjectContext();
          widget.onOpenScriptWorkspace();
        };
      case ShortVideoNextStepTarget.productionWorkspace:
        return () {
          _syncSelectedProjectContext();
          widget.onOpenProductionWorkspace();
        };
      case ShortVideoNextStepTarget.tasks:
        return widget.onOpenTasks;
      case ShortVideoNextStepTarget.quality:
        return widget.onOpenQuality;
    }
  }
}
