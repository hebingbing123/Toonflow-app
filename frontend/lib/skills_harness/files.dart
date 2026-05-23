part of 'controller.dart';

extension SkillsHarnessFileController on SkillsHarnessController {
  Future<void> previewSkillFile(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
          ? l10n.skillsHarnessPreviewTruncated(r.content.substring(0, 12000))
          : r.content;
      await showStudioDialog<void>(
        context: context,
        builder: (ctx) => StudioAlertDialog(
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
              child: Text(l10n.skillsHarnessPreviewClose),
            ),
          ],
        ),
      );
    } catch (e) {
      _setErrorFromException(e);
      loadingSkillPreview = false;
      _publish();
    }
  }

  Future<void> showSkillVersionHistory(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
      await showStudioDialog<void>(
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
              return StudioAlertDialog(
                title: Text(l10n.skillsHarnessVersionDialogTitle(path)),
                content: SizedBox(
                  width: studioConstrainedDialogWidth(context, maxWidth: 980),
                  height: 720,
                  child: versions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: StudioEmptyState.emptyData(
                            title: l10n.skillsHarnessVersionEmpty,
                            icon: Icons.history_outlined,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.skillsHarnessVersionCountHint(
                                versions.length,
                              ),
                              style: Theme.of(ctx).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
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
                                    l10n.skillsHarnessVersionHash(
                                      _shortHash(version.hashAfter),
                                    ),
                                  ].join(' · ');
                                  return ListTile(
                                    dense: true,
                                    selected: selectedNow,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      version.rollbackOf == null
                                          ? l10n.skillsHarnessVersionTitle(
                                              index + 1,
                                            )
                                          : l10n.skillsHarnessRollbackVersionTitle(
                                              index + 1,
                                            ),
                                    ),
                                    subtitle: Text(subtitle),
                                    onTap: () => setState(() {
                                      selected = version;
                                    }),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.skillsHarnessDiffTitle,
                              style: Theme.of(ctx).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: studioPanelMutedColor(ctx),
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
                                          const SizedBox(width: 16),
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
                              final confirmed = await showStudioDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => StudioAlertDialog(
                                  title: Text(
                                    l10n.skillsHarnessConfirmRollbackTitle,
                                  ),
                                  content: Text(
                                    l10n.skillsHarnessConfirmRollbackBody(
                                      _formatSkillVersionTime(
                                        selected!.changedAt,
                                      ),
                                      _shortHash(selected!.hashAfter),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(false),
                                      child: Text(l10n.skillsHarnessCancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(confirmCtx).pop(true),
                                      child: Text(
                                        l10n.skillsHarnessConfirmRollback,
                                      ),
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
                      child: Text(
                        rollingBackSkillVersion
                            ? l10n.skillsHarnessRollingBack
                            : l10n.skillsHarnessRollbackToVersion,
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.skillsHarnessPreviewClose),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      _setErrorFromException(e);
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
          _l10nResolved.skillsHarnessPutResult(r.path, r.content.length);
      _publish();
    } catch (e) {
      _setErrorFromException(e);
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
          _l10nResolved.skillsHarnessPostResult(r.path, r.content.length);
      _publish();
    } catch (e) {
      _setErrorFromException(e);
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
      skillMutationLine =
          _l10nResolved.skillsHarnessDeleteResult(path);
      _publish();
    } catch (e) {
      _setErrorFromException(e);
      loadingSkillDelete = false;
      _publish();
    }
  }

  Future<void> _rollbackToVersion({
    required BuildContext context,
    required String path,
    required SkillVersion version,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        summary: l10n.skillsHarnessRollbackSummary,
      );
      final current = await fetchSkillContent(token, path);
      skillContentController.text = current.content;
      skillMutationLine = l10n.skillsHarnessRollbackResult(
        result.filePath,
        _shortHash(result.hashAfter),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.skillsHarnessRollbackDone)));
      }
    } catch (e) {
      _setErrorFromException(e);
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
