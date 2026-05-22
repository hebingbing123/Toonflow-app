import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/novels/import_parser.dart';
import '../project_editor/novels/whole_book_chapter_importer.dart';
import '../project_editor/novels/whole_book_file_picker.dart';
import '../project_editor/novels/whole_book_import_resume.dart';
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
  WholeBookImportCheckpoint? _resumeCheckpoint;
  String? _lastSourceDisplayName;
  String? _lastContentHash;
  String? _lastBatchTag;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshResumeCheckpoint());
  }

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

  void _applyWholeBookParseResult(String text, List<ParsedNovelChapter> rows) {
    final l10n = AppLocalizations.of(context)!;
    final contentHash = text.trim().isEmpty ? null : wholeBookContentHash(text);
    setState(() {
      _lastContentHash = contentHash;
      if (shouldMirrorWholeBookIntoPasteField(text)) {
        _pasteCtrl.text = text;
      } else {
        _pasteCtrl.clear();
      }
      _previewChapters = rows;
      _previewMessage = rows.isEmpty
          ? l10n.projectEditorNovelsActionPreparseResultEmpty
          : l10n.projectEditorNovelsActionPreparseResultOk(rows.length);
      if (rows.isEmpty) {
        _infoLine = null;
      } else if (!shouldMirrorWholeBookIntoPasteField(text)) {
        _infoLine = l10n.projectEditorNovelsWholeBookPickFileLargeNoPastePreview(
          text.length,
        );
      } else {
        _infoLine = l10n.projectEditorNovelsWholeBookPickFileLoadedPreparse(
          rows.length,
          text.length,
        );
      }
    });
  }

  void _preparsePaste() {
    final l10n = AppLocalizations.of(context)!;
    _applyWholeBookParseResult(_pasteCtrl.text, parseWholeBookNovelText(l10n, _pasteCtrl.text));
  }

  Future<void> _refreshResumeCheckpoint() async {
    final checkpoint = await loadWholeBookImportCheckpoint(
      widget.project.id,
      accessToken: widget.accessToken,
    );
    if (!mounted) {
      return;
    }
    setState(() => _resumeCheckpoint = checkpoint);
  }

  Future<void> _pickWholeBookFile({required bool importAfterParse}) async {
    await _runAction(() async {
      final l10n = AppLocalizations.of(context)!;
      final payload = await pickWholeBookFile(l10n);
      if (payload == null || !mounted) {
        return;
      }
      _lastSourceDisplayName = payload.displayName;
      _lastContentHash = payload.contentHash;
      final rows = parseWholeBookNovelText(l10n, payload.text);
      _applyWholeBookParseResult(payload.text, rows);
      if (rows.isEmpty) {
        throw FormatException(l10n.projectEditorNovelsActionPreparseResultEmpty);
      }
      if (!importAfterParse) {
        return;
      }
      final resume = _resumeCheckpoint;
      final canResume = resume != null &&
          wholeBookImportSourcesMatch(
            resume,
            sourceKey: payload.sourceKey,
            contentHash: payload.contentHash,
          );
      await _importParsedChapters(
        startListIndex: canResume ? resume.nextChapterListIndex : 0,
        sourceKey: payload.sourceKey,
        sourceDisplayName: payload.displayName,
        contentHash: payload.contentHash,
        batchTag: canResume ? resume.batchTag : null,
      );
    });
  }

  Future<void> _resumeWholeBookImport() async {
    final checkpoint = _resumeCheckpoint;
    if (checkpoint == null) {
      return;
    }
    await _runAction(() async {
      final l10n = AppLocalizations.of(context)!;
      var rows = await loadWholeBookResumeChapters(
        l10n: l10n,
        projectId: widget.project.id,
        checkpoint: checkpoint,
        pasteText: _pasteCtrl.text,
      );
      var sourceKey = checkpoint.sourceKey;
      var sourceDisplayName = checkpoint.sourceDisplayName;
      var contentHash = checkpoint.effectiveContentHash;
      if (rows != null) {
        if (mounted) {
          setState(() {
            _infoLine = l10n.projectEditorNovelsWholeBookResumeContinueInPlace;
            _previewChapters = rows!;
            _lastContentHash = contentHash;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _infoLine = l10n.projectEditorNovelsWholeBookResumePickSameFile(
              checkpoint.sourceDisplayName,
            );
          });
        }
        final payload = await pickWholeBookFile(l10n);
        if (payload == null || !mounted) {
          return;
        }
        if (!wholeBookImportSourcesMatch(
          checkpoint,
          sourceKey: payload.sourceKey,
          contentHash: payload.contentHash,
        )) {
          throw FormatException(
            l10n.projectEditorNovelsWholeBookSourceContentMismatch,
          );
        }
        sourceKey = payload.sourceKey;
        sourceDisplayName = payload.displayName;
        contentHash = payload.contentHash;
        rows = parseWholeBookNovelText(l10n, payload.text);
        _applyWholeBookParseResult(payload.text, rows);
        if (rows.isEmpty) {
          throw FormatException(l10n.projectEditorNovelsActionPreparseResultEmpty);
        }
      }
      await _importParsedChapters(
        startListIndex: checkpoint.nextChapterListIndex,
        sourceKey: sourceKey,
        sourceDisplayName: sourceDisplayName,
        contentHash: contentHash,
        batchTag: checkpoint.batchTag,
        chapters: rows,
      );
    });
  }

  Future<void> _importParsedChapters({
    int startListIndex = 0,
    String? sourceKey,
    String? sourceDisplayName,
    String? contentHash,
    String? batchTag,
    List<ParsedNovelChapter>? chapters,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final importChapters = chapters ?? _previewChapters;
    final paste = _pasteCtrl.text.trim();
    final resolvedHash =
        contentHash ??
        _lastContentHash ??
        (paste.isNotEmpty
            ? wholeBookContentHash(paste)
            : wholeBookContentHash(
                importChapters
                    .map((c) => '${c.chapter}\n${c.chapterData}')
                    .join('\n'),
              ));
    final resolvedSourceKey = sourceKey ?? wholeBookSourceKeyFromContentHash(resolvedHash);
    final result = await importWholeBookChapters(
      l10n: l10n,
      accessToken: widget.accessToken,
      projectId: widget.project.id,
      chapters: importChapters,
      sourceKey: resolvedSourceKey,
      sourceDisplayName: sourceDisplayName ?? _lastSourceDisplayName ?? 'paste',
      contentHash: resolvedHash,
      intakeStatus: 'admitted',
      startListIndex: startListIndex,
      existingBatchTag: batchTag ?? _lastBatchTag,
      onProgress: (done, total, message) {
        if (!mounted) {
          return;
        }
        setState(() => _infoLine = message);
      },
    );
    _lastBatchTag = result.batchTag;
    if (!mounted) {
      return;
    }
    setState(() {
      if (result.succeeded) {
        _infoLine = l10n.projectEditorNovelsWholeBookImportDoneSummary(
          result.imported,
          result.skippedExisting,
          result.total,
        );
        _previewChapters = const <ParsedNovelChapter>[];
        _previewMessage = null;
      } else if (result.canResume && result.failedAtIndex != null) {
        _infoLine = l10n.projectEditorNovelsWholeBookImportPartialFailure(
          result.failedAtIndex! + 1,
          result.imported,
          result.skippedExisting,
        );
      }
    });
    await _refreshResumeCheckpoint();
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
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
                  style: studioPaneTitleStyle(context),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, StudioSpacing.iconTouchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: _busy ? null : widget.onOpenFullWorkbench,
                child: Text(l10n.studioScriptNovelInlineOpenFullWorkbench),
              ),
            ],
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Text(
            l10n.studioScriptNovelInlineImportSubtitle,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
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
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          Text(
            l10n.studioScriptNovelInlineUrlSection,
            style: studioControlLabelStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          TextField(
            controller: _urlCtrl,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: l10n.projectEditorNovelsWorkbenchImportCrawlUrlLabel,
              isDense: true,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              style: studioFormPrimaryButtonStyle(context),
              onPressed: _busy ? null : () => _runAction(_importFromUrl),
              icon: const Icon(Icons.link, size: 18),
              label: Text(l10n.studioScriptNovelInlineImportFromUrl),
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          Text(
            l10n.studioScriptNovelInlinePasteSection,
            style: studioControlLabelStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          TextField(
            controller: _pasteCtrl,
            enabled: !_busy,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: l10n.projectEditorNovelsWorkbenchImportRawPasteLabel,
              helperText: l10n.projectEditorNovelsWorkbenchImportRawPasteHelper,
              alignLabelWithHint: true,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (_resumeCheckpoint != null)
                FutureBuilder<bool>(
                  future: hasWholeBookImportStash(
                    widget.project.id,
                    _resumeCheckpoint!.effectiveContentHash,
                  ),
                  builder: (context, stashSnap) {
                    final cp = _resumeCheckpoint!;
                    final paste = _pasteCtrl.text.trim();
                    final inPlace =
                        stashSnap.data == true ||
                        (paste.isNotEmpty &&
                            wholeBookContentHash(paste) ==
                                cp.effectiveContentHash);
                    return FilledButton.tonal(
                      style: FilledButton.styleFrom().merge(
                        studioFormButtonStyle(context),
                      ),
                      onPressed: _busy ? null : _resumeWholeBookImport,
                      child: Text(
                        inPlace
                            ? l10n
                                  .projectEditorNovelsWholeBookResumeImportButtonInPlace
                            : l10n.projectEditorNovelsWholeBookResumeImportButton(
                                cp.nextChapterListIndex,
                                cp.totalChapters,
                              ),
                      ),
                    );
                  },
                ),
              FilledButton.icon(
                style: studioFormPrimaryButtonStyle(context),
                onPressed: _busy
                    ? null
                    : () => _pickWholeBookFile(importAfterParse: true),
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(l10n.studioScriptNovelInlinePickFileAndImport),
              ),
              OutlinedButton.icon(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: _busy
                    ? null
                    : () => _pickWholeBookFile(importAfterParse: false),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(l10n.projectEditorNovelsWholeBookPickFileButton),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: _busy ? null : _preparsePaste,
                child: Text(
                  l10n.projectEditorNovelsWorkbenchImportPreparseButton,
                ),
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom().merge(
                  studioFormButtonStyle(context),
                ),
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
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          Text(
            l10n.studioScriptNovelInlineManualSection,
            style: studioControlLabelStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
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
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom().merge(
                studioFormButtonStyle(context),
              ),
              onPressed: _busy ? null : () => _runAction(_createSingleChapter),
              child: Text(l10n.projectEditorNovelsWorkbenchCreateSubmit),
            ),
          ),
          if (_infoLine != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            Text(
              _infoLine!,
              style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
            ),
          ],
          if (_busy) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            const LinearProgressIndicator(minHeight: 2),
          ],
          ],
        ),
      ),
    );
  }
}
