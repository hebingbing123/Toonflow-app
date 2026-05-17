part of '../../../home_page.dart';

extension _StoryboardWorkbenchCharacterActions on _StoryboardWorkbenchPanelState {
  Future<void> _loadWorkbenchCharacters() async {
    _applyWorkbenchState(() => _loadingCharacters = true);
    try {
      final rows = await listProjectCharactersV1(
        widget.token,
        widget.projectId,
      );
      if (!mounted) return;
      _applyWorkbenchState(() {
        _projectCharacters = rows;
        _loadingCharacters = false;
      });
    } catch (_) {
      if (mounted) {
        _applyWorkbenchState(() => _loadingCharacters = false);
      }
    }
  }

  Future<void> _saveStoryboardCharacter(String? characterId) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    await postProductionStoryboardSetCharacterV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: widget.storyNumericId,
      characterId: characterId,
    );
    _cachedStoryboardListDataVersion = null;
    await _refreshProductionData();
    if (!mounted) return;
    _applyWorkbenchState(() {
      _setWorkbenchFollowUp(l10n.storyboardWorkbenchCharacterSaved);
    });
    await _notifyStoryboardMutated();
  }
}
