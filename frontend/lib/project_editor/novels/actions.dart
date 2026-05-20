part of '../../../home_page.dart';

Map<String, String> _novelCrawlHttpHeaders(NovelCrawlAuthOverride? auth) {
  final headers = <String, String>{
    'User-Agent': 'OpenFlow/1.0 content-intake crawler',
  };
  final cookie = auth?.cookie?.trim();
  if (cookie != null && cookie.isNotEmpty) {
    headers['Cookie'] = cookie;
  }
  final username = auth?.username?.trim();
  final password = auth?.password;
  if (username != null &&
      username.isNotEmpty &&
      password != null &&
      password.isNotEmpty) {
    final token = base64Encode(utf8.encode('$username:$password'));
    headers['Authorization'] = 'Basic $token';
  }
  return headers;
}

class _CrawlerPreviewPayload {
  const _CrawlerPreviewPayload({
    required this.title,
    required this.bodyText,
    required this.mode,
    required this.pageCount,
    required this.chapterUrlCount,
    required this.bodyCharCount,
  });

  final String title;
  final String bodyText;
  final String mode;
  final int pageCount;
  final int chapterUrlCount;
  final int bodyCharCount;
}

/// Encapsulates chapter workbench mutations so the main novels workbench file
/// can focus on dialog orchestration and domain layout.
extension _HomePageProjectEditorNovelWorkbenchActions on _HomePageState {
  List<ParsedNovelChapter> _parseNovelImportPreview(
    AppLocalizations l10n,
    String raw,
  ) {
    return parseWholeBookNovelText(l10n, raw);
  }

  Future<void> _crawlNovelSourcePreview({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController importUrlCtrl,
    required TextEditingController importRawTextCtrl,
    required TextEditingController importExecutionSideCtrl,
    required void Function(String infoLine) applyInfoLine,
    required void Function(List<ParsedNovelChapter> rows, String message)
    applyImportPreview,
    NovelCrawlAuthOverride? crawlAuth,
  }) async {
    final url = importUrlCtrl.text.trim();
    if (url.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorUrlEmpty);
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw FormatException(l10n.projectEditorNovelsActionErrorUrlInvalid);
    }

    final side = importExecutionSideCtrl.text.trim().toLowerCase();
    final _CrawlerPreviewPayload payload;
    if (side == 'server') {
      final preview = await postProjectNovelCrawlPreview(
        token,
        project.id,
        url,
        auth: crawlAuth,
      );
      payload = _CrawlerPreviewPayload(
        title: preview.title,
        bodyText: preview.bodyText,
        mode: preview.mode,
        pageCount: preview.pageCount,
        chapterUrlCount: preview.chapterUrlCount,
        bodyCharCount: preview.bodyCharCount,
      );
    } else {
      final response = await http.get(
        uri,
        headers: _novelCrawlHttpHeaders(crawlAuth),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException(
          l10n.projectEditorNovelsActionErrorCrawlHttp(response.statusCode),
        );
      }

      payload = await _crawlNovelSourceAdaptive(
        l10n,
        uri,
        response.body,
        crawlAuth: crawlAuth,
      );
    }

    importRawTextCtrl.text = payload.bodyText;
    final rows = _parseNovelImportPreview(l10n, payload.bodyText);
    applyImportPreview(
      rows,
      rows.isEmpty
          ? l10n.projectEditorNovelsActionCrawlImportPreviewEmpty(payload.title)
          : l10n.projectEditorNovelsActionCrawlImportPreviewOk(
              payload.title,
              rows.length,
            ),
    );
    final label = side == 'server'
        ? l10n.projectEditorNovelsActionCrawlSideServer
        : l10n.projectEditorNovelsActionCrawlSideClient;
    applyInfoLine(
      l10n.projectEditorNovelsActionCrawlDoneInfo(
        label,
        payload.title,
        payload.mode,
        payload.pageCount,
        payload.chapterUrlCount,
        payload.bodyCharCount,
      ),
    );
  }

  Future<_CrawlerPreviewPayload> _crawlNovelSourceAdaptive(
    AppLocalizations l10n,
    Uri seedUri,
    String seedHtml, {
    NovelCrawlAuthOverride? crawlAuth,
  }) async {
    final seed = extractCrawlerContentFromHtml(
      l10n,
      seedHtml,
      fallbackTitle: seedUri.host,
      pageUri: seedUri,
    );
    if (seed.chapterUrls.isNotEmpty) {
      final chapterPages = seed.chapterUrls.take(20).toList(growable: false);
      final chunks = <String>[];
      for (var i = 0; i < chapterPages.length; i += 1) {
        final body = await _fetchCrawlerBodyText(
          l10n,
          chapterPages[i],
          crawlAuth: crawlAuth,
        );
        if (body == null || body.bodyText.trim().isEmpty) {
          continue;
        }
        chunks.add('${body.title}\n${body.bodyText}');
      }
      if (chunks.isNotEmpty) {
        return _CrawlerPreviewPayload(
          title: seed.title,
          bodyText: chunks.join('\n\n'),
          mode: 'toc',
          pageCount: chunks.length,
          chapterUrlCount: seed.chapterUrls.length,
          bodyCharCount: chunks.join('\n\n').length,
        );
      }
    }

    final pages = <String>[seed.bodyText];
    final visited = <String>{seedUri.toString()};
    var next = seed.nextPageUrl;
    var hops = 0;
    while (next != null && hops < 5) {
      if (visited.contains(next)) {
        break;
      }
      visited.add(next);
      final page = await _fetchCrawlerBodyText(l10n, next, crawlAuth: crawlAuth);
      if (page == null || page.bodyText.trim().isEmpty) {
        break;
      }
      pages.add(page.bodyText);
      next = page.nextPageUrl;
      hops += 1;
    }
    return _CrawlerPreviewPayload(
      title: seed.title,
      bodyText: pages.join('\n\n'),
      mode: pages.length > 1 ? 'pagination' : 'single',
      pageCount: pages.length,
      chapterUrlCount: seed.chapterUrls.length,
      bodyCharCount: pages.join('\n\n').length,
    );
  }

  Future<ExtractedCrawlerContent?> _fetchCrawlerBodyText(
    AppLocalizations l10n,
    String rawUrl, {
    NovelCrawlAuthOverride? crawlAuth,
  }) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    final response = await http.get(
      uri,
      headers: _novelCrawlHttpHeaders(crawlAuth),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return extractCrawlerContentFromHtml(
      l10n,
      response.body,
      fallbackTitle: uri.host,
      pageUri: uri,
    );
  }

  Future<void> _runNovelWorkbenchAction({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required List<bool> novelsBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function() action,
  }) async {
    setLocalBusy(true);
    setDialogState(() => novelsBusy[0] = true);
    try {
      await action();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))),
        );
      }
    } finally {
      if (ctx.mounted) {
        setDialogState(() => novelsBusy[0] = false);
      }
      setLocalBusy(false);
    }
  }

  Future<void> _searchNovelWorkbenchRows({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController searchCtrl,
    required TextEditingController searchIntakeStatusCtrl,
    required TextEditingController searchIntakeSourceCtrl,
    required void Function(List<NovelRow> rows, String infoLine) applyResult,
  }) async {
    final rows = await fetchProjectNovelsByProjectId(
      token,
      project.id,
      search: searchCtrl.text.trim(),
      intakeStatus: searchIntakeStatusCtrl.text.trim(),
      intakeSource: searchIntakeSourceCtrl.text.trim(),
      page: 1,
      limit: 10,
    );
    final filters = <String>[
      if (searchCtrl.text.trim().isNotEmpty) 'keyword',
      if (searchIntakeStatusCtrl.text.trim().isNotEmpty)
        'status=${searchIntakeStatusCtrl.text.trim()}',
      if (searchIntakeSourceCtrl.text.trim().isNotEmpty)
        'source=${searchIntakeSourceCtrl.text.trim()}',
    ];
    applyResult(
      List<NovelRow>.from(rows.items),
      filters.isEmpty
          ? l10n.projectEditorNovelsActionSearchHit(
              rows.total,
              rows.items.length,
            )
          : l10n.projectEditorNovelsActionSearchFiltered(
              rows.total,
              filters.join(' / '),
              rows.items.length,
            ),
    );
  }

  Future<void> _createNovelWorkbenchChapter({
    required String token,
    required ProjectRow project,
    required TextEditingController createChapterCtrl,
    required TextEditingController createBodyCtrl,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
  }) async {
    final created = await createProjectNovelUnderProject(
      token,
      project.id,
      chapter: createChapterCtrl.text.trim(),
      chapterData: createBodyCtrl.text.trim(),
      intakeSource: 'manual',
      intakeStatus: 'admitted',
    );
    await refreshWorkbench(setLocalState);
    setLocalState(() {
      selectedNovelIdCtrl.text = created.numericId.toString();
      patchChapterCtrl.text = created.chapter;
      patchBodyCtrl.text = created.chapterData;
    });
  }

  Future<void> _importNovelWorkbenchChapters({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required List<ParsedNovelChapter> chapters,
    required int batchSize,
    required String intakeSourceMode,
    required String? intakeSourceUrl,
    required String intakeStatus,
    required String? intakeNote,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final normalizedChapters = reindexParsedNovelChapters(l10n, chapters);
    if (normalizedChapters.isEmpty) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorPreparseRequired,
      );
    }
    final quality = evaluateNovelImportQuality(l10n, normalizedChapters);
    if (!quality.canImport) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorImportQuality(
          quality.blockers.join('；'),
        ),
      );
    }
    if (quality.warnings.isNotEmpty) {
      applyInfoLine(
        l10n.projectEditorNovelsActionImportQualityHint(
          quality.warnings.join('；'),
        ),
      );
    }
    if (batchSize <= 0) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorBatchSizePositive,
      );
    }
    final emptyBodyChapter = normalizedChapters.firstWhere(
      (chapter) => chapter.chapterData.trim().isEmpty,
      orElse: () => const ParsedNovelChapter(
        chapterIndex: 0,
        chapter: '',
        chapterData: '__ok__',
      ),
    );
    if (emptyBodyChapter.chapterIndex > 0) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorChapterBodyEmpty(
          emptyBodyChapter.chapterIndex,
        ),
      );
    }

    for (var i = 0; i < normalizedChapters.length; i += batchSize) {
      final end = (i + batchSize < normalizedChapters.length)
          ? i + batchSize
          : normalizedChapters.length;
      final slice = normalizedChapters.sublist(i, end);
      for (final chapter in slice) {
        final sourceKind = _resolveImportSourceKind(
          intakeSourceMode: intakeSourceMode,
          intakeSourceUrl: intakeSourceUrl,
        );
        await createProjectNovelUnderProject(
          token,
          project.id,
          chapterIndex: chapter.chapterIndex,
          chapter: chapter.chapter,
          chapterData: chapter.chapterData,
          intakeSource: sourceKind,
          intakeSourceUrl: intakeSourceUrl,
          intakeStatus: intakeStatus,
          intakeNote: intakeNote,
        );
      }
      applyInfoLine(l10n.projectEditorNovelsActionImportProgress(
        end,
        normalizedChapters.length,
      ));
    }

    await refreshWorkbench(setLocalState);
    applyInfoLine(
      l10n.projectEditorNovelsActionImportComplete(normalizedChapters.length),
    );
  }

  Future<void> _importNovelWorkbenchViaServerCrawl({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required String intakeSourceUrl,
    required String intakeStatus,
    required String? intakeNote,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
    NovelCrawlAuthOverride? crawlAuth,
  }) async {
    final url = intakeSourceUrl.trim();
    if (url.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorUrlEmpty);
    }
    final imported = await postProjectNovelCrawlImport(
      token,
      project.id,
      url,
      intakeStatus: intakeStatus,
      intakeNote: intakeNote,
      auth: crawlAuth,
    );
    if (imported.qualityWarnings.isNotEmpty) {
      applyInfoLine(
        l10n.projectEditorNovelsActionImportQualityHint(
          imported.qualityWarnings.join('；'),
        ),
      );
    }
    await refreshWorkbench(setLocalState);
    applyInfoLine(
      l10n.projectEditorNovelsActionServerImportDone(
        imported.title,
        imported.chaptersCreated,
        imported.mode,
        imported.pageCount,
        imported.chapterUrlCount,
        imported.bodyCharCount,
      ),
    );
  }

  Future<void> _importNovelWorkbenchViaServerCrawlBatch({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required String batchUrls,
    required String intakeStatus,
    required String? intakeNote,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
    NovelCrawlAuthOverride? crawlAuth,
  }) async {
    final urls = batchUrls
        .split(RegExp(r'[\n\r]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorBatchUrlsEmpty);
    }
    final res = await postProjectNovelCrawlImportBatch(
      token,
      project.id,
      urls,
      intakeStatus: intakeStatus,
      intakeNote: intakeNote,
      auth: crawlAuth,
    );
    await refreshWorkbench(setLocalState);
    final sampleFailures = res.items
        .where((e) => !e.ok)
        .take(3)
        .map((e) => '${e.errorCode ?? 'error'}: ${e.url}')
        .join('；');
    final detail = sampleFailures.isEmpty
        ? ''
        : '${l10n.projectEditorNovelsActionBatchImportFailuresPrefix}$sampleFailures';
    applyInfoLine(
      l10n.projectEditorNovelsActionBatchImportDone(
        res.succeeded,
        res.total,
        res.failed,
        detail,
      ),
    );
  }

  Future<void> _createNovelCrawlSchedule({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required String batchUrls,
    required int delayMinutes,
    required int? repeatMinutes,
    required String intakeStatus,
    required String? intakeNote,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final urls = batchUrls
        .split(RegExp(r'[\n\r]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorBatchUrlsEmpty);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final runAtMs = now + (delayMinutes * 60 * 1000);
    final repeatIntervalMs = repeatMinutes == null || repeatMinutes <= 0
        ? null
        : repeatMinutes * 60 * 1000;
    final created = await postProjectNovelCrawlScheduleCreate(
      token,
      project.id,
      urls: urls,
      intakeStatus: intakeStatus,
      intakeNote: intakeNote,
      runAtMs: runAtMs,
      repeatIntervalMs: repeatIntervalMs,
    );
    applyInfoLine(
      l10n.projectEditorNovelsActionCrawlScheduleCreated(
        created.numericTaskId,
        created.status,
        delayMinutes,
        repeatMinutes ?? 0,
      ),
    );
  }

  Future<void> _listNovelCrawlSchedules({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final rows = await fetchProjectNovelCrawlSchedules(token, project.id);
    if (rows.isEmpty) {
      applyInfoLine(l10n.projectEditorNovelsActionCrawlSchedulesEmpty);
      return;
    }
    final head = rows.take(3).map((e) {
      final runAt = e.runAtMs == null
          ? 'n/a'
          : DateTime.fromMillisecondsSinceEpoch(e.runAtMs!).toIso8601String();
      final repeat = e.repeatIntervalMs == null ? '' : ' repeat=${e.repeatIntervalMs}ms';
      return '#${e.numericTaskId} ${e.status} runAt=$runAt$repeat';
    }).join('；');
    applyInfoLine(
      l10n.projectEditorNovelsActionCrawlSchedulesSummary(rows.length, head),
    );
  }

  Future<void> _showNovelCrawlObservability({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final res = await fetchProjectNovelCrawlObservability(token, project.id);
    final topSources = res.intakeSources
        .take(3)
        .map((e) => '${e.intakeSource ?? 'none'}=${e.chapterCount}')
        .join(', ');
    final topStatuses = res.intakeStatuses
        .take(3)
        .map((e) => '${e.intakeStatus ?? 'none'}=${e.chapterCount}')
        .join(', ');
    final jobs = res.crawlJobStatuses
        .map((e) => '${e.status}=${e.jobCount}')
        .join(', ');
    final recent = res.recentServerImports.isEmpty
        ? ''
        : l10n.projectEditorNovelsActionCrawlObservabilityRecentImports(
            res.recentServerImports
                .take(2)
                .map((e) => '#${e.numericId}')
                .join(', '),
          );
    applyInfoLine(
      l10n.projectEditorNovelsActionCrawlObservability(
        res.totalChapters,
        topSources,
        topStatuses,
        jobs,
        recent,
      ),
    );
  }

  String _resolveImportSourceKind({
    required String intakeSourceMode,
    required String? intakeSourceUrl,
  }) {
    final hasUrl = intakeSourceUrl != null && intakeSourceUrl.trim().isNotEmpty;
    if (!hasUrl) {
      return 'whole_book_import';
    }
    if (intakeSourceMode == 'server') {
      return 'crawler_server';
    }
    return 'crawler_client';
  }

  Future<void> _readNovelWorkbenchChapter({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required TextEditingController patchIntakeStatusCtrl,
    required TextEditingController patchIntakeSourceUrlCtrl,
    required TextEditingController patchIntakeNoteCtrl,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final id = int.parse(selectedNovelIdCtrl.text.trim());
    final row = await fetchProjectNovelByProjectIds(token, project.id, id);
    patchChapterCtrl.text = row.chapter;
    patchBodyCtrl.text = row.chapterData;
    patchIntakeStatusCtrl.text = row.intakeStatus ?? 'admitted';
    patchIntakeSourceUrlCtrl.text = row.intakeSourceUrl ?? '';
    patchIntakeNoteCtrl.text = row.intakeNote ?? '';
    applyInfoLine(l10n.projectEditorNovelsActionChapterReadOk(row.numericId));
  }

  Future<void> _saveNovelWorkbenchChapter({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required TextEditingController patchIntakeStatusCtrl,
    required TextEditingController patchIntakeSourceUrlCtrl,
    required TextEditingController patchIntakeNoteCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final id = int.parse(selectedNovelIdCtrl.text.trim());
    final row = await patchProjectNovelByProjectIds(token, project.id, id, {
      'chapter': patchChapterCtrl.text.trim(),
      'chapter_data': patchBodyCtrl.text.trim(),
      'intake_status': patchIntakeStatusCtrl.text.trim(),
      'intake_source_url': patchIntakeSourceUrlCtrl.text.trim().isEmpty
          ? null
          : patchIntakeSourceUrlCtrl.text.trim(),
      'intake_note': patchIntakeNoteCtrl.text.trim().isEmpty
          ? null
          : patchIntakeNoteCtrl.text.trim(),
    });
    await refreshWorkbench(setLocalState);
    applyInfoLine(l10n.projectEditorNovelsActionChapterSaveOk(row.numericId));
  }

  Future<void> _deleteNovelWorkbenchChapter({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController deleteNovelIdCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final id = int.parse(deleteNovelIdCtrl.text.trim());
    await deleteProjectNovelByProjectIds(token, project.id, id);
    await refreshWorkbench(setLocalState);
    applyInfoLine(l10n.projectEditorNovelsActionChapterDeleteOk(id));
  }

  Future<void> _generateNovelWorkbenchEvents({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController generateIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(generateIdsCtrl.text);
    if (ids.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorIdsEmpty);
    }
    final message = await postNovelEventsGenerateEvents(
      token,
      projectUuid: project.id,
      novelIds: ids,
    );
    await refreshWorkbench(setLocalState);
    applyInfoLine(
      l10n.projectEditorNovelsActionEventsGenerateOk(message),
    );
  }

  Future<void> _readNovelWorkbenchData({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final rows = await fetchNovelWorkbenchFullRows(
      token,
      projectUuid: project.id,
    );
    final sample = rows.isEmpty
        ? l10n.projectEditorNovelsActionListLabelEmpty
        : rows
              .take(2)
              .map((row) => '#${row.numericId} ${row.chapter}')
              .join(' · ');
    applyInfoLine(
      l10n.projectEditorNovelsActionWorkbenchDataResult(rows.length, sample),
    );
  }

  Future<void> _readNovelWorkbenchIndex({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final rows = await fetchNovelWorkbenchIndex(
      token,
      projectUuid: project.id,
    );
    final sample = rows.isEmpty
        ? l10n.projectEditorNovelsActionListLabelEmpty
        : rows
              .take(3)
              .map((row) => '#${row.numericId}:${row.chapterIndex}')
              .join(' · ');
    applyInfoLine(
      l10n.projectEditorNovelsActionWorkbenchIndexResult(rows.length, sample),
    );
  }

  Future<void> _readNovelWorkbenchEventStates({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController numericIdsCtrl,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(numericIdsCtrl.text);
    if (ids.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorIdsEmpty);
    }
    final rows = await fetchNovelWorkbenchEventStates(token, project.id, ids);
    final sample = rows.isEmpty
        ? l10n.projectEditorNovelsActionListLabelAllZero
        : rows
              .take(3)
              .map((row) => '#${row.numericId}:${row.eventState}')
              .join(' · ');
    applyInfoLine(
      l10n.projectEditorNovelsActionWorkbenchEventStateResult(
        rows.length,
        sample,
      ),
    );
  }

  Future<void> _batchDeleteNovelWorkbenchChapters({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController batchDeleteIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(batchDeleteIdsCtrl.text);
    if (ids.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorIdsEmpty);
    }
    await batchDeleteNovelsUnderProject(token, project.id, ids);
    await refreshWorkbench(setLocalState);
    applyInfoLine(
      l10n.projectEditorNovelsActionBatchDeleteOk(ids.length),
    );
  }

  Future<void> _batchUpdateNovelWorkbenchAdmission({
    required AppLocalizations l10n,
    required String token,
    required ProjectRow project,
    required TextEditingController batchAdmissionIdsCtrl,
    required TextEditingController batchAdmissionStatusCtrl,
    required TextEditingController batchAdmissionNoteCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(batchAdmissionIdsCtrl.text);
    if (ids.isEmpty) {
      throw FormatException(l10n.projectEditorNovelsActionErrorIdsEmpty);
    }
    final nextStatus = batchAdmissionStatusCtrl.text.trim();
    if (nextStatus.isEmpty) {
      throw FormatException(
        l10n.projectEditorNovelsActionErrorAdmissionStatusEmpty,
      );
    }
    final note = batchAdmissionNoteCtrl.text.trim();
    for (final id in ids) {
      await patchProjectNovelByProjectIds(token, project.id, id, {
        'intake_status': nextStatus,
        'intake_note': note.isEmpty ? null : note,
      });
    }
    await refreshWorkbench(setLocalState);
    applyInfoLine(
      l10n.projectEditorNovelsActionBatchAdmissionOk(ids.length, nextStatus),
    );
  }
}
