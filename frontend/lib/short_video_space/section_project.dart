// Part extensions call `setState` on `_ShortVideoSpaceSectionState`; analyzer treats
// extension `this` as the extension type, not `State` (false positive).
// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

extension ShortVideoSpaceSectionProject on _ShortVideoSpaceSectionState {
  void _applyDemoOverviewSnapshot(ShortVideoDemoSnapshot snap) {
    setState(() {
      _loadingProjectOverview = false;
      _loadingTimeline = false;
      _projectStats = snap.projectStats;
      _productionOverview = snap.productionOverview;
      _projectAssetsOverview = snap.assetsOverview;
      _shotReadiness = snap.shotReadiness;
      _shotReadinessUnavailable = snap.shotReadinessUnavailable;
      _publishDrafts = snap.publishDrafts;
      _syncSelectedPublishDraftWith(_publishDrafts);
      _candidateCompareRows = snap.candidateCompareRows;
      _candidateCompareReviews = snap.candidateCompareReviews;
      _scopedRunningJobCount = snap.scopedRunningJobCount;
      _shortVideoAssembly = snap.assembly;
      _shortVideoExportCheck = snap.exportCheck;
      _shortVideoTimeline = snap.timeline;
      _recentProjectTasks = snap.recentProjectTasks;
      if (snap.projectConfigLine != null) {
        _projectConfigLine = snap.projectConfigLine;
      }
    });
  }

  Future<void> _loadProjects() async {
    if (ProductDemoMode.instance.shouldSkipLiveApi &&
        widget.debugProjects != null) {
      return;
    }
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projects = const <ProjectRow>[];
        _selectedProjectId = null;
        _projectConfigLine = l10n.shortVideoProjectNotLoggedWriteback;
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
        final l10n = resolveAppLocalizationsForErrors(context);
        setState(() {
          _projectConfigLine = l10n.shortVideoProjectEmptyList;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = l10n.shortVideoProjectLoadFailed(
          describeUserVisibleApiErrorResolved(context, e),
        );
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
    return resolveShortVideoSelectedProjectId(
      projects,
      currentProjectId: _selectedProjectId,
      preferredProjectUuid: widget.initialProjectUuid,
    );
  }

  void _applyProjectPreset(ProjectRow? project) {
    if (project == null) {
      setState(() {
        _latestSuccessfulExport = null;
      });
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
      _latestSuccessfulExport = null;
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
    widget.onSyncProjectContext(
      project == null ? null : ShortVideoProjectScope.fromProject(project),
    );
  }

  ShortVideoMode _modeFromProject(ProjectRow project) {
    final value = (project.mode ?? '').trim().toLowerCase();
    if (studioProjectModeLooksLiveAction(value)) {
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
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = l10n.shortVideoProjectCreateNeedLogin;
      });
      return;
    }
    setState(() {
      _creatingProject = true;
      _projectConfigLine = null;
    });
    final l10n = resolveAppLocalizationsForErrors(context);
    final defaultName = _isAnimated
        ? l10n.shortVideoProjectDefaultNameAnimated
        : l10n.shortVideoProjectDefaultNameLive;
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
          if (_bgmStrategy.trim().isNotEmpty)
            'bgmStrategy': _bgmStrategy.trim(),
        },
      );
      if (!mounted) {
        return;
      }
      final modeLabel = shortVideoModeLabelL10n(l10n, _mode);
      final ratioLabel = shortVideoVideoRatioLabelL10n(l10n, _videoRatio);
      setState(() {
        _projects = [created, ..._projects].toList(growable: false);
        _selectedProjectId = created.id;
        _projectConfigLine = l10n.shortVideoProjectCreated(
          created.numericId,
          modeLabel,
          ratioLabel,
        );
      });
      _syncSelectedProjectContext();
      await _loadProjectOverview();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final errL10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = errL10n.shortVideoProjectCreateFailed(
          describeUserVisibleApiErrorResolved(context, e),
        );
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
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = l10n.shortVideoProjectSaveNeedSelection;
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
        'subtitleStyle': _subtitleStyle.trim().isEmpty
            ? null
            : _subtitleStyle.trim(),
        'bgmStrategy': _bgmStrategy.trim().isEmpty ? null : _bgmStrategy.trim(),
      };
      final updated = await updateProjectByProjectId(token, project.id, body);
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      final modeLabel = shortVideoModeLabelL10n(l10n, _mode);
      final ratioLabel = shortVideoVideoRatioLabelL10n(l10n, _videoRatio);
      setState(() {
        _projects = _projects
            .map((row) => row.id == updated.id ? updated : row)
            .toList(growable: false);
        _selectedProjectId = updated.id;
        _projectConfigLine = l10n.shortVideoProjectSaved(
          updated.numericId,
          modeLabel,
          ratioLabel,
          _targetMarket,
          _targetPlatforms.length,
          _durationStrategy,
        );
      });
      _syncSelectedProjectContext();
      _loadProjectOverview();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final errL10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = errL10n.shortVideoProjectSaveFailed(
          describeUserVisibleApiErrorResolved(context, e),
        );
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final plan = buildShortVideoNextStepPlan(
      l10n: l10n,
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
