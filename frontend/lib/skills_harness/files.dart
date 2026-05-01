part of 'controller.dart';

extension SkillsHarnessFileController on SkillsHarnessController {
  Future<void> previewSkillFile(BuildContext context) async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillPreview = true;
    _setError(null);
    _publish();
    try {
      final r = await fetchSkillContent(token, path);
      loadingSkillPreview = false;
      _publish();
      if (!context.mounted) return;
      final text = r.content.length > 12000
          ? '${r.content.substring(0, 12000)}…\n\n(truncated)'
          : r.content;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(r.path),
          content: SingleChildScrollView(
            child: SelectableText(
              text,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillPreview = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillPreview = false;
      _publish();
    }
  }

  Future<void> showSkillVersionHistory(BuildContext context) async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillVersions = true;
    _setError(null);
    _publish();
    try {
      final current = await fetchSkillContent(token, path);
      final versions = await fetchSkillVersions(token, path);
      loadingSkillVersions = false;
      _publish();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          SkillVersion? selected = versions.isEmpty ? null : versions.first;
          return StatefulBuilder(
            builder: (ctx, setState) {
              final selectedContent = selected?.contentSnapshot ?? '';
              final diffRows = _buildSkillDiffRows(
                current.content,
                selectedContent,
              );
              return AlertDialog(
                title: Text('版本历史 · $path'),
                content: SizedBox(
                  width: 980,
                  height: 720,
                  child: versions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('该文件暂无版本历史记录'),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '共 ${versions.length} 个版本，选择一条历史记录查看与当前版本的差异。',
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 180,
                              child: ListView.separated(
                                itemCount: versions.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, index) {
                                  final version = versions[index];
                                  final selectedNow =
                                      selected?.id == version.id;
                                  final summary = version.summary?.trim();
                                  final subtitle = [
                                    _formatSkillVersionTime(version.changedAt),
                                    if (summary != null && summary.isNotEmpty)
                                      summary,
                                    'hash ${_shortHash(version.hashAfter)}',
                                  ].join(' · ');
                                  return ListTile(
                                    dense: true,
                                    selected: selectedNow,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      version.rollbackOf == null
                                          ? '版本 ${index + 1}'
                                          : '回滚版本 ${index + 1}',
                                    ),
                                    subtitle: Text(subtitle),
                                    onTap: () => setState(() {
                                      selected = version;
                                    }),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '当前版本 vs 选中版本',
                              style: Theme.of(ctx).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(ctx).colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListView.builder(
                                  itemCount: diffRows.length,
                                  itemBuilder: (ctx, index) {
                                    final row = diffRows[index];
                                    return Container(
                                      color: row.changed
                                          ? Theme.of(ctx)
                                                .colorScheme
                                                .errorContainer
                                                .withValues(alpha: 0.32)
                                          : null,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: SelectableText(
                                              row.currentLine,
                                              style: Theme.of(
                                                ctx,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SelectableText(
                                              row.selectedLine,
                                              style: Theme.of(
                                                ctx,
                                              ).textTheme.bodySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                actions: [
                  if (selected != null)
                    FilledButton.tonal(
                      onPressed: rollingBackSkillVersion
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => AlertDialog(
                                  title: const Text('确认回滚'),
                                  content: Text(
                                    '当前文件将回滚到 ${_formatSkillVersionTime(selected!.changedAt)} 的版本（hash ${_shortHash(selected!.hashAfter)}）。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(false),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(true),
                                      child: const Text('确认回滚'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              if (!ctx.mounted) return;
                              await _rollbackToVersion(
                                context: ctx,
                                path: path,
                                version: selected!,
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            },
                      child: Text(rollingBackSkillVersion ? '回滚中…' : '回滚到此版本'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillVersions = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillVersions = false;
      _publish();
    }
  }

  Future<void> putSkillProbe() async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillPut = true;
    _setError(null);
    skillMutationLine = null;
    _publish();
    try {
      final r = await saveSkillContent(
        token,
        path,
        skillContentController.text,
      );
      loadingSkillPut = false;
      skillMutationLine =
          'PUT 200: ${r.path} (${r.content.length} chars written)';
      _publish();
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillPut = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillPut = false;
      _publish();
    }
  }

  Future<void> postSkillProbe() async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillPost = true;
    _setError(null);
    skillMutationLine = null;
    _publish();
    try {
      final r = await createSkillContent(
        token,
        path,
        skillContentController.text,
      );
      loadingSkillPost = false;
      skillMutationLine =
          'POST 201: ${r.path} (${r.content.length} chars written)';
      _publish();
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillPost = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillPost = false;
      _publish();
    }
  }

  Future<void> deleteSkillProbe() async {
    final token = _accessToken;
    if (token == null) return;
    final path = skillPathController.text.trim();
    if (path.isEmpty) return;
    loadingSkillDelete = true;
    _setError(null);
    skillMutationLine = null;
    _publish();
    try {
      await deleteSkillContent(token, path);
      loadingSkillDelete = false;
      skillMutationLine = 'DELETE 204: $path';
      _publish();
    } on RustApiException catch (e) {
      _setError(e.toString());
      loadingSkillDelete = false;
      _publish();
    } catch (e) {
      _setError(e.toString());
      loadingSkillDelete = false;
      _publish();
    }
  }

  Future<void> _rollbackToVersion({
    required BuildContext context,
    required String path,
    required SkillVersion version,
  }) async {
    final token = _accessToken;
    if (token == null) return;
    rollingBackSkillVersion = true;
    _setError(null);
    _publish();
    try {
      final result = await rollbackSkillVersion(
        token,
        filePath: path,
        targetVersionId: version.id,
        summary: 'SkillsHarness 手动回滚',
      );
      final current = await fetchSkillContent(token, path);
      skillContentController.text = current.content;
      skillMutationLine =
          'ROLLBACK 200: ${result.filePath} -> ${_shortHash(result.hashAfter)}';
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('技能文件已回滚并刷新内容')));
      }
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      rollingBackSkillVersion = false;
      _publish();
    }
  }
}

class _SkillDiffRow {
  const _SkillDiffRow({
    required this.currentLine,
    required this.selectedLine,
    required this.changed,
  });

  final String currentLine;
  final String selectedLine;
  final bool changed;
}

List<_SkillDiffRow> _buildSkillDiffRows(String current, String selected) {
  final currentLines = current.split('\n');
  final selectedLines = selected.split('\n');
  final maxLength = currentLines.length > selectedLines.length
      ? currentLines.length
      : selectedLines.length;
  return List<_SkillDiffRow>.generate(maxLength, (index) {
    final currentLine = index < currentLines.length ? currentLines[index] : '';
    final selectedLine = index < selectedLines.length
        ? selectedLines[index]
        : '';
    return _SkillDiffRow(
      currentLine: currentLine,
      selectedLine: selectedLine,
      changed: currentLine != selectedLine,
    );
  });
}

String _shortHash(String hash) {
  return hash.length <= 8 ? hash : hash.substring(0, 8);
}

String _formatSkillVersionTime(String raw) {
  try {
    final parsed = DateTime.parse(raw).toLocal();
    final yyyy = parsed.year.toString().padLeft(4, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  } catch (_) {
    return raw;
  }
}
