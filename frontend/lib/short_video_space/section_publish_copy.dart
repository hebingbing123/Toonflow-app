// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// Publish copy: suggestion, editing, platform-specific copy.
extension ShortVideoPublishCopy on _ShortVideoSpaceSectionState {
  Future<void> _suggestPublishCopy() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_publishDrafts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先创建发布草稿。')),
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
            const SnackBar(
              content: Text('请先明确选择要生成文案的草稿。'),
              duration: Duration(seconds: 4),
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
        SnackBar(content: Text('差异化文案已写入（来源：${res.source}）。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文案建议失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文案建议失败：$e')),
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
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final draftId = _activePublishDraft?.id;
    if (draftId == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('请先明确选择要编辑文案的草稿。'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final draft = await fetchPublishDraft(token, project.id, draftId);
      final copy = Map<String, dynamic>.from(draft.platformCopy ?? {});
      final tags = tagsComma
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      copy[platformId] = <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'tags': tags,
      };
      await patchPublishDraft(token, project.id, draftId, <String, dynamic>{
        'platform_copy': copy,
      });
      if (!context.mounted) {
        return;
      }
      setState(() {
        _publishCopyEditorRevision++;
      });
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        const SnackBar(content: Text('已保存差异化文案。')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('保存文案失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('保存文案失败：$e')),
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
