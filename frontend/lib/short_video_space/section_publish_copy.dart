// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// Publish copy: suggestion, editing, platform-specific copy.
extension ShortVideoPublishCopy on _ShortVideoSpaceSectionState {
  Future<void> _suggestPublishCopy() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_publishDrafts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shortVideoPublishCopyCreateDraftFirst)),
        );
      }
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final draftId = _activePublishDraft?.id;
      if (draftId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.shortVideoPublishCopySelectDraftToSuggest),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final res = await suggestPublishPlatformCopy(
        token,
        project.id,
        draftId,
        apply: true,
      );
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      setState(() {
        _publishCopyEditorRevision++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shortVideoPublishCopySuggestApplied(res.source)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.shortVideoPublishCopySuggestFailed(
                describeUserVisibleApiErrorResolved(context, e),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _commitPublishPlatformCopy(
    ProjectRow project,
    String token,
    String platformId,
    String title,
    String description,
    String tagsComma,
  ) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final draftId = _activePublishDraft?.id;
    if (draftId == null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.shortVideoPublishCopySelectDraftToEdit),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final tags = tagsComma
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await patchPublishDraft(token, project.id, draftId, <String, dynamic>{
        'platform_copy_fragment': <String, dynamic>{
          platformId: <String, dynamic>{
            'title': title.trim(),
            'description': description.trim(),
            'tags': tags,
          },
        },
      });
      if (!context.mounted) {
        return;
      }
      setState(() {
        _publishCopyEditorRevision++;
      });
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishCopySaved)),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoPublishCopySaveFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }
}
