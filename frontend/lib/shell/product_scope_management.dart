// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

/// Product scope management extension for _HomePageState.
/// Handles project scope selection, recent projects, and scope resolution.
extension _HomePageProductScopeManagement on _HomePageState {
  Future<void> _refreshRecentProjectIds() async {
    final ids = await StudioRecentProjectsPrefs.load();
    if (!mounted) {
      return;
    }
    setState(() => _recentProjectIds = ids);
    await _applyDefaultProductProjectScopeIfNeeded();
  }

  Future<void> _applyDefaultProductProjectScopeIfNeeded() async {
    if (widget.shellMode != HomeShellMode.product) {
      return;
    }
    final projects = _projectsController.projects;
    if (projects == null || projects.isEmpty) {
      return;
    }

    final scopedNumericId =
        widget.studioProjectNumericId ?? _productScopedProjectNumericId;
    if (scopedNumericId != null && scopedNumericId > 0) {
      final scopedUuid = _workspaceInputController.projectUuidController.text
          .trim();
      if (scopedUuid.isEmpty) {
        ProjectRow? row;
        for (final candidate in projects) {
          if (candidate.numericId == scopedNumericId) {
            row = candidate;
            break;
          }
        }
        if (row != null) {
          await _selectProjectScope(row);
          return;
        }
      } else if (_productScopedProjectNumericId != null) {
        return;
      }
    }

    if (_productScopedProjectNumericId != null) {
      return;
    }

    var recentIds = _recentProjectIds;
    if (recentIds.isEmpty) {
      recentIds = await StudioRecentProjectsPrefs.load();
      if (!mounted) {
        return;
      }
      if (recentIds.isNotEmpty) {
        setState(() => _recentProjectIds = recentIds);
      }
    }

    final row = resolveDefaultProductScopedProject(
      projects: projects,
      recentProjectIds: recentIds,
    );
    if (row == null) {
      return;
    }
    await _selectProjectScope(row);
  }

  Future<void> _selectProjectScope(ProjectRow row) async {
    await StudioRecentProjectsPrefs.record(row.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _productScopedProjectNumericId = row.numericId;
      _recentProjectIds = <String>[
        row.id,
        ..._recentProjectIds.where((id) => id != row.id),
      ].take(3).toList(growable: false);
    });
    _workspaceInputController.applyProjectScope(
      row.numericId,
      projectUuid: row.id,
      workspaceId: row.workspaceId,
    );
  }

  ProjectRow? _studioProjectRow() {
    final id = widget.studioProjectNumericId ?? _productScopedProjectNumericId;
    if (id == null) return null;
    final list = _projectsController.projects;
    if (list == null) return null;
    for (final row in list) {
      if (row.numericId == id) return row;
    }
    return null;
  }

  ProjectRow? _studioProjectRowForNumericId(int projectNumericId) {
    final existing = _studioProjectRow();
    if (existing != null) {
      return existing;
    }
    final uuid = _workspaceInputController.projectUuidController.text.trim();
    if (uuid.isEmpty) {
      return null;
    }
    return _buildReadonlyProjectScopeRow(
      projectNumericId: projectNumericId,
      projectUuid: uuid,
      projectName: widget.debugStudioProjectName,
    );
  }

  ProjectRow _buildReadonlyProjectScopeRow({
    required int projectNumericId,
    required String projectUuid,
    required String? projectName,
  }) {
    return ProjectRow(
      id: projectUuid,
      numericId: projectNumericId,
      name: projectName,
      intro: null,
      projectType: null,
      imageModel: null,
      imageQuality: null,
      videoModel: null,
      artStyle: null,
      directorManual: null,
      mode: null,
      videoRatio: null,
      createTimeMs: null,
      artStylePack: null,
      storyStylePack: null,
      targetMarket: null,
      targetPlatforms: null,
      durationStrategy: null,
      voiceProfile: null,
      subtitleStyle: null,
      bgmStrategy: null,
      projectAccessMode: 'restricted',
      projectAccessRole: 'editor',
    );
  }
}
