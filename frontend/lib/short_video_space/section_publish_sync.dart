part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionPublishSync on _ShortVideoSpaceSectionState {
  bool _isLatestPublishRefreshRequest(int requestId) =>
      requestId == _publishRefreshRequestId;

  ProjectRow? get _selectedProject {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      return null;
    }
    for (final project in _projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  PublishDraftRow? get _activePublishDraft {
    if (_publishDrafts.isEmpty) {
      return null;
    }
    if (_publishDrafts.length == 1) {
      return _publishDrafts.first;
    }
    final selected = _selectedPublishDraftId;
    if (selected != null) {
      for (final d in _publishDrafts) {
        if (d.id == selected) {
          return d;
        }
      }
    }
    return null;
  }

  void _syncSelectedPublishDraftWith(List<PublishDraftRow> drafts) {
    if (drafts.isEmpty) {
      _selectedPublishDraftId = null;
      return;
    }
    if (drafts.length == 1) {
      _selectedPublishDraftId = drafts.first.id;
      return;
    }
    final current = _selectedPublishDraftId;
    if (current != null && drafts.any((d) => d.id == current)) {
      return;
    }
    _selectedPublishDraftId = null;
  }

  void _syncSelectedDraftIdsWith(List<PublishDraftRow> drafts) {
    _selectedDraftIds = shortVideoFilterExistingDraftIds(
      _selectedDraftIds,
      drafts,
    );
  }

  /// 与 [_activePublishDraft] 一致，但基于本次 API 返回的列表（投递前 state 可能未刷新）。
  String? _resolvePublishDraftIdFromList(List<PublishDraftRow> drafts) {
    if (drafts.isEmpty) {
      return null;
    }
    if (drafts.length == 1) {
      return drafts.first.id;
    }
    final sel = _selectedPublishDraftId;
    if (sel == null || sel.trim().isEmpty) {
      return null;
    }
    for (final d in drafts) {
      if (d.id == sel) {
        return d.id;
      }
    }
    return null;
  }
}
