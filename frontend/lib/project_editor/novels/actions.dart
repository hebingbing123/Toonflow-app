part of '../../../home_page.dart';

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
  List<ParsedNovelChapter> _parseNovelImportPreview(String raw) {
    return parseWholeBookNovelText(raw);
  }

  Future<void> _crawlNovelSourcePreview({
    required String token,
    required ProjectRow project,
    required TextEditingController importUrlCtrl,
    required TextEditingController importRawTextCtrl,
    required TextEditingController importExecutionSideCtrl,
    required void Function(String infoLine) applyInfoLine,
    required void Function(List<ParsedNovelChapter> rows, String message)
    applyImportPreview,
  }) async {
    final url = importUrlCtrl.text.trim();
    if (url.isEmpty) {
      throw const FormatException('请先输入抓取 URL');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('抓取 URL 必须是合法的 http/https 地址');
    }

    final side = importExecutionSideCtrl.text.trim().toLowerCase();
    final _CrawlerPreviewPayload payload;
    if (side == 'server') {
      final preview = await postProjectNovelCrawlPreview(
        token,
        project.id,
        url,
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
        headers: const <String, String>{
          'User-Agent': 'Toonflow/1.0 content-intake crawler',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException('抓取失败，HTTP ${response.statusCode}');
      }

      payload = await _crawlNovelSourceAdaptive(uri, response.body);
    }

    importRawTextCtrl.text = payload.bodyText;
    final rows = _parseNovelImportPreview(payload.bodyText);
    applyImportPreview(
      rows,
      rows.isEmpty
          ? '已抓取 ${payload.title}，但没有抽出可导入正文。'
          : '已抓取 ${payload.title}，抽出 ${rows.length} 条可导入章节。',
    );
    final label = side == 'server' ? 'server-side crawl' : 'client-side crawl';
    applyInfoLine(
      '$label 已完成：${payload.title}（模式 ${payload.mode}，抓取 ${payload.pageCount} 页，候选章节链接 ${payload.chapterUrlCount}，正文 ${payload.bodyCharCount} 字）',
    );
  }

  Future<_CrawlerPreviewPayload> _crawlNovelSourceAdaptive(
    Uri seedUri,
    String seedHtml,
  ) async {
    final seed = extractCrawlerContentFromHtml(
      seedHtml,
      fallbackTitle: seedUri.host,
      pageUri: seedUri,
    );
    if (seed.chapterUrls.isNotEmpty) {
      final chapterPages = seed.chapterUrls.take(20).toList(growable: false);
      final chunks = <String>[];
      for (var i = 0; i < chapterPages.length; i += 1) {
        final body = await _fetchCrawlerBodyText(chapterPages[i]);
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
      final page = await _fetchCrawlerBodyText(next);
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

  Future<ExtractedCrawlerContent?> _fetchCrawlerBodyText(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    final response = await http.get(
      uri,
      headers: const <String, String>{
        'User-Agent': 'Toonflow/1.0 content-intake crawler',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return extractCrawlerContentFromHtml(
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
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (ctx.mounted) {
        setDialogState(() => novelsBusy[0] = false);
      }
      setLocalBusy(false);
    }
  }

  Future<void> _searchNovelWorkbenchRows({
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
          ? '搜索命中 ${rows.total} 条，当前展示 ${rows.items.length} 条。'
          : '筛选命中 ${rows.total} 条（${filters.join(' / ')}），当前展示 ${rows.items.length} 条。',
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
    final normalizedChapters = reindexParsedNovelChapters(chapters);
    if (normalizedChapters.isEmpty) {
      throw const FormatException('请先预解析整本内容');
    }
    final quality = evaluateNovelImportQuality(normalizedChapters);
    if (!quality.canImport) {
      throw FormatException('导入质量门未通过：${quality.blockers.join('；')}');
    }
    if (quality.warnings.isNotEmpty) {
      applyInfoLine('导入质量提示：${quality.warnings.join('；')}');
    }
    if (batchSize <= 0) {
      throw const FormatException('批次大小必须大于 0');
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
        '第 ${emptyBodyChapter.chapterIndex} 条章节正文为空，请先在预解析预览里修正后再导入',
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
      applyInfoLine('已导入 $end/${normalizedChapters.length} 条章节…');
    }

    await refreshWorkbench(setLocalState);
    applyInfoLine('整本导入完成，共新增 ${normalizedChapters.length} 条章节。');
  }

  Future<void> _importNovelWorkbenchViaServerCrawl({
    required String token,
    required ProjectRow project,
    required String intakeSourceUrl,
    required String intakeStatus,
    required String? intakeNote,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final url = intakeSourceUrl.trim();
    if (url.isEmpty) {
      throw const FormatException('请先输入抓取 URL');
    }
    final imported = await postProjectNovelCrawlImport(
      token,
      project.id,
      url,
      intakeStatus: intakeStatus,
      intakeNote: intakeNote,
    );
    if (imported.qualityWarnings.isNotEmpty) {
      applyInfoLine('导入质量提示：${imported.qualityWarnings.join('；')}');
    }
    await refreshWorkbench(setLocalState);
    applyInfoLine(
      'server 托管导入完成：${imported.title}（新增 ${imported.chaptersCreated} 条章节，模式 ${imported.mode}，抓取 ${imported.pageCount} 页，候选章节链接 ${imported.chapterUrlCount}，正文 ${imported.bodyCharCount} 字）',
    );
  }

  Future<void> _importNovelWorkbenchViaServerCrawlBatch({
    required String token,
    required ProjectRow project,
    required String batchUrls,
    required String intakeStatus,
    required String? intakeNote,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final urls = batchUrls
        .split(RegExp(r'[\n\r]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      throw const FormatException('请先在批量托管 URL 里填入至少 1 行 URL');
    }
    final res = await postProjectNovelCrawlImportBatch(
      token,
      project.id,
      urls,
      intakeStatus: intakeStatus,
      intakeNote: intakeNote,
    );
    await refreshWorkbench(setLocalState);
    final sampleFailures = res.items
        .where((e) => !e.ok)
        .take(3)
        .map((e) => '${e.errorCode ?? 'error'}: ${e.url}')
        .join('；');
    applyInfoLine(
      '批量托管导入完成：成功 ${res.succeeded}/${res.total}，失败 ${res.failed}。'
      '${sampleFailures.isEmpty ? '' : ' 失败样例：$sampleFailures'}',
    );
  }

  Future<void> _createNovelCrawlSchedule({
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
      throw const FormatException('请先在批量托管 URL 里填入至少 1 行 URL');
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
      projectNumericId: project.numericId,
    );
    applyInfoLine(
      '已创建托管抓取计划：task #${created.numericTaskId}（${created.status}；delay ${delayMinutes}m；repeat ${repeatMinutes ?? 0}m）',
    );
  }

  Future<void> _listNovelCrawlSchedules({
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final rows = await fetchProjectNovelCrawlSchedules(token, project.id);
    if (rows.isEmpty) {
      applyInfoLine('暂无托管抓取计划（仅显示本项目最近 100 条）。');
      return;
    }
    final head = rows.take(3).map((e) {
      final runAt = e.runAtMs == null
          ? 'n/a'
          : DateTime.fromMillisecondsSinceEpoch(e.runAtMs!).toIso8601String();
      final repeat = e.repeatIntervalMs == null ? '' : ' repeat=${e.repeatIntervalMs}ms';
      return '#${e.numericTaskId} ${e.status} runAt=$runAt$repeat';
    }).join('；');
    applyInfoLine('本项目托管抓取计划 ${rows.length} 条，最近：$head');
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
    applyInfoLine('已读取章节 #${row.numericId}。');
  }

  Future<void> _saveNovelWorkbenchChapter({
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
    applyInfoLine('已更新章节 #${row.numericId}。');
  }

  Future<void> _deleteNovelWorkbenchChapter({
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
    applyInfoLine('已删除章节 #$id。');
  }

  Future<void> _generateNovelWorkbenchEvents({
    required String token,
    required ProjectRow project,
    required TextEditingController generateIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(generateIdsCtrl.text);
    if (ids.isEmpty) {
      throw const FormatException('至少提供一个章节 ID');
    }
    final message = await postNovelEventsGenerateEvents(
      token,
      projectNumericId: project.numericId,
      novelIds: ids,
    );
    await refreshWorkbench(setLocalState);
    applyInfoLine('已触发事件生成：$message');
  }

  Future<void> _readNovelWorkbenchData({
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final rows = await fetchNovelWorkbenchFullRows(token, project.numericId);
    final sample = rows.isEmpty
        ? '空列表'
        : rows
              .take(2)
              .map((row) => '#${row.numericId} ${row.chapter}')
              .join(' · ');
    applyInfoLine('workbench get-novel-data 返回 ${rows.length} 条：$sample');
  }

  Future<void> _readNovelWorkbenchIndex({
    required String token,
    required ProjectRow project,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final rows = await fetchNovelWorkbenchIndex(token, project.numericId);
    final sample = rows.isEmpty
        ? '空列表'
        : rows
              .take(3)
              .map((row) => '#${row.numericId}:${row.chapterIndex}')
              .join(' · ');
    applyInfoLine('workbench get-novel-index 返回 ${rows.length} 条：$sample');
  }

  Future<void> _readNovelWorkbenchEventStates({
    required String token,
    required ProjectRow project,
    required TextEditingController numericIdsCtrl,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(numericIdsCtrl.text);
    if (ids.isEmpty) {
      throw const FormatException('至少提供一个章节 ID');
    }
    final rows = await fetchNovelWorkbenchEventStates(token, project.id, ids);
    final sample = rows.isEmpty
        ? '当前均为 0'
        : rows
              .take(3)
              .map((row) => '#${row.numericId}:${row.eventState}')
              .join(' · ');
    applyInfoLine(
      'workbench get-novel-event-state 返回 ${rows.length} 条：$sample',
    );
  }

  Future<void> _batchDeleteNovelWorkbenchChapters({
    required String token,
    required ProjectRow project,
    required TextEditingController batchDeleteIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    final ids = parseNumericIdList(batchDeleteIdsCtrl.text);
    if (ids.isEmpty) {
      throw const FormatException('至少提供一个章节 ID');
    }
    final message = await batchDeleteNovelsUnderProject(token, project.id, ids);
    await refreshWorkbench(setLocalState);
    applyInfoLine('已批量删除 ${ids.length} 条章节：$message');
  }

  Future<void> _batchUpdateNovelWorkbenchAdmission({
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
      throw const FormatException('至少提供一个章节 ID');
    }
    final nextStatus = batchAdmissionStatusCtrl.text.trim();
    if (nextStatus.isEmpty) {
      throw const FormatException('请先选择目标准入状态');
    }
    final note = batchAdmissionNoteCtrl.text.trim();
    for (final id in ids) {
      await patchProjectNovelByProjectIds(token, project.id, id, {
        'intake_status': nextStatus,
        'intake_note': note.isEmpty ? null : note,
      });
    }
    await refreshWorkbench(setLocalState);
    applyInfoLine('已批量更新 ${ids.length} 条章节到 $nextStatus。');
  }
}
