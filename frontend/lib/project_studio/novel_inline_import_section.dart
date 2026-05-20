import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/novels/import_parser.dart';
import '../rust_api.dart';
import 'novel_crawl_auth_section.dart';

/// Inline novel intake on the script studio step (URL crawl, paste, single chapter).
class StudioScriptNovelInlineImport extends StatefulWidget {
  const StudioScriptNovelInlineImport({
    super.key,
    required this.accessToken,
    required this.project,
    required this.onReload,
    required this.onOpenFullWorkbench,
  });

  final String accessToken;
  final ProjectRow project;
  final Future<void> Function() onReload;
  final VoidCallback onOpenFullWorkbench;

  @override
  State<StudioScriptNovelInlineImport> createState() =>
      _StudioScriptNovelInlineImportState();
}

class _StudioScriptNovelInlineImportState
    extends State<StudioScriptNovelInlineImport> {
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _pasteCtrl = TextEditingController();
  final TextEditingController _chapterTitleCtrl = TextEditingController();
  final TextEditingController _chapterBodyCtrl = TextEditingController();

  bool _busy = false;
  String? _infoLine;
  List<ParsedNovelChapter> _previewChapters = const <ParsedNovelChapter>[];
  String? _previewMessage;
  NovelCrawlAuthOverride? _crawlAuthOverride;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _pasteCtrl.dispose();
    _chapterTitleCtrl.dispose();
    _chapterBodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _infoLine = null;
    });
    try {
      await action();
      await widget.onReload();
    } catch (e) {
      if (mounted) {
        setState(() {
          _infoLine = describeUserVisibleApiErrorResolved(context, e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _importFromUrl() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorUrlEmpty);
    }
    final imported = await postProjectNovelCrawlImport(
      widget.accessToken,
      widget.project.id,
      url,
      intakeStatus: 'admitted',
      auth: _crawlAuthOverride,
    );
    if (!mounted) return;
    setState(() {
      _infoLine = l10n.projectEditorNovelsActionServerImportDone(
        imported.title,
        imported.chaptersCreated,
        imported.mode,
        imported.pageCount,
        imported.chapterUrlCount,
        imported.bodyCharCount,
      );
    });
  }

  void _preparsePaste() {
    final l10n = AppLocalizations.of(context)!;
    final rows = parseWholeBookNovelText(l10n, _pasteCtrl.text);
    setState(() {
      _previewChapters = rows;
      _previewMessage = rows.isEmpty
          ? l10n.projectEditorNovelsActionPreparseResultEmpty
          : l10n.projectEditorNovelsActionPreparseResultOk(rows.length);
    });
  }

  Future<void> _importParsedChapters() async {
    final l10n = AppLocalizations.of(context)!;
    final normalized = reindexParsedNovelChapters(l10n, _previewChapters);
    if (normalized.isEmpty) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorPreparseRequired,
      );
    }
    final quality = evaluateNovelImportQuality(l10n, normalized);
    if (!quality.canImport) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorImportQuality(
          quality.blockers.join('；'),
        ),
      );
    }
    if (quality.warnings.isNotEmpty) {
      setState(() {
        _infoLine = l10n.projectEditorNovelsActionImportQualityHint(
          quality.warnings.join('；'),
        );
      });
    }
    const batchSize = 10;
    for (var i = 0; i < normalized.length; i += batchSize) {
      final end = (i + batchSize < normalized.length)
          ? i + batchSize
          : normalized.length;
      for (final chapter in normalized.sublist(i, end)) {
        await createProjectNovelUnderProject(
          widget.accessToken,
          widget.project.id,
          chapterIndex: chapter.chapterIndex,
          chapter: chapter.chapter,
          chapterData: chapter.chapterData,
          intakeSource: 'whole_book_import',
          intakeStatus: 'admitted',
        );
      }
      if (mounted) {
        setState(() {
          _infoLine = l10n.projectEditorNovelsActionImportProgress(
            end,
            normalized.length,
          );
        });
      }
    }
    if (mounted) {
      setState(() {
        _infoLine = l10n.projectEditorNovelsActionImportComplete(
          normalized.length,
        );
        _previewChapters = const <ParsedNovelChapter>[];
        _previewMessage = null;
      });
    }
  }

  Future<void> _createSingleChapter() async {
    final l10n = AppLocalizations.of(context)!;
    final chapter = _chapterTitleCtrl.text.trim();
    final body = _chapterBodyCtrl.text.trim();
    if (chapter.isEmpty || body.isEmpty) {
      throw FormatException(l10n.studioScriptNovelInlineChapterFieldsRequired);
    }
    await createProjectNovelUnderProject(
      widget.accessToken,
      widget.project.id,
      chapter: chapter,
      chapterData: body,
      intakeSource: 'manual',
      intakeStatus: 'admitted',
    );
    if (!mounted) return;
    setState(() {
      _infoLine = l10n.projectEditorNovelsActionChapterCreateOk;
      _chapterTitleCtrl.clear();
      _chapterBodyCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final outline = theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.35)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.cloud_download_outlined,
                color: tokens.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.studioScriptNovelInlineImportTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : widget.onOpenFullWorkbench,
                child: Text(l10n.studioScriptNovelInlineOpenFullWorkbench),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.studioScriptNovelInlineImportSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          StudioNovelCrawlAuthSection(
            accessToken: widget.accessToken,
            projectId: widget.project.id,
            siteUrlProvider: () {
              final url = _urlCtrl.text.trim();
              return url.isEmpty ? null : url;
            },
            onOverrideChanged: (value) {
              setState(() => _crawlAuthOverride = value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            l10n.studioScriptNovelInlineUrlSection,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _urlCtrl,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.projectEditorNovelsWorkbenchImportCrawlUrlLabel,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : () => _runAction(_importFromUrl),
            icon: const Icon(Icons.link, size: 18),
            label: Text(l10n.studioScriptNovelInlineImportFromUrl),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.studioScriptNovelInlinePasteSection,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _pasteCtrl,
            enabled: !_busy,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l10n.projectEditorNovelsWorkbenchImportRawPasteLabel,
              alignLabelWithHint: true,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: _busy ? null : _preparsePaste,
                child: Text(
                  l10n.projectEditorNovelsWorkbenchImportPreparseButton,
                ),
              ),
              FilledButton.tonal(
                onPressed: _busy || _previewChapters.isEmpty
                    ? null
                    : () => _runAction(_importParsedChapters),
                child: Text(
                  l10n.studioScriptNovelInlineImportParsed(
                    _previewChapters.length,
                  ),
                ),
              ),
            ],
          ),
          if (_previewMessage != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              _previewMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.primary),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.studioScriptNovelInlineManualSection,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _chapterTitleCtrl,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText:
                  l10n.projectEditorNovelsWorkbenchCreateChapterTitleLabel,
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _chapterBodyCtrl,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText:
                  l10n.projectEditorNovelsWorkbenchCreateChapterBodyLabel,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => _runAction(_createSingleChapter),
            child: Text(l10n.projectEditorNovelsWorkbenchCreateSubmit),
          ),
          if (_infoLine != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _infoLine!,
              style: theme.textTheme.bodySmall?.copyWith(color: outline),
            ),
          ],
          if (_busy) ...<Widget>[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          ],
        ),
      ),
    );
  }
}
