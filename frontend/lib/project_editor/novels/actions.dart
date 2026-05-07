part of '../../../home_page.dart';

/// Encapsulates chapter workbench mutations so the main novels workbench file
/// can focus on dialog orchestration and domain layout.
extension _HomePageProjectEditorNovelWorkbenchActions on _HomePageState {
  List<ParsedNovelChapter> _parseNovelImportPreview(String raw) {
    return parseWholeBookNovelText(raw);
  }

  Future<void> _crawlNovelSourcePreview({
    required TextEditingController importUrlCtrl,
    required TextEditingController importRawTextCtrl,
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

    final response = await http.get(
      uri,
      headers: const <String, String>{
        'User-Agent': 'Toonflow/1.0 content-intake crawler',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('抓取失败，HTTP ${response.statusCode}');
    }

    final extracted = extractCrawlerContentFromHtml(
      response.body,
      fallbackTitle: uri.host,
    );
    importRawTextCtrl.text = extracted.bodyText;
    final rows = _parseNovelImportPreview(extracted.bodyText);
    applyImportPreview(
      rows,
      rows.isEmpty
          ? '已抓取 ${extracted.title}，但没有抽出可导入正文。'
          : '已抓取 ${extracted.title}，抽出 ${rows.length} 条可导入章节。',
    );
    applyInfoLine('client-side crawl 已完成：${extracted.title}');
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
    required void Function(List<NovelRow> rows, String infoLine) applyResult,
  }) async {
    final rows = await fetchProjectNovelsByProjectId(
      token,
      project.id,
      search: searchCtrl.text.trim(),
      page: 1,
      limit: 10,
    );
    applyResult(
      List<NovelRow>.from(rows.items),
      '搜索命中 ${rows.total} 条，当前展示 ${rows.items.length} 条。',
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
    required String? intakeSourceUrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required StateSetter setLocalState,
    required void Function(String infoLine) applyInfoLine,
  }) async {
    if (chapters.isEmpty) {
      throw const FormatException('请先预解析整本内容');
    }
    if (batchSize <= 0) {
      throw const FormatException('批次大小必须大于 0');
    }

    for (var i = 0; i < chapters.length; i += batchSize) {
      final end = (i + batchSize < chapters.length)
          ? i + batchSize
          : chapters.length;
      final slice = chapters.sublist(i, end);
      for (final chapter in slice) {
        final sourceKind =
            (intakeSourceUrl != null && intakeSourceUrl.isNotEmpty)
            ? 'crawler_client'
            : 'whole_book_import';
        await createProjectNovelUnderProject(
          token,
          project.id,
          chapterIndex: chapter.chapterIndex,
          chapter: chapter.chapter,
          chapterData: chapter.chapterData,
          intakeSource: sourceKind,
          intakeSourceUrl: intakeSourceUrl,
          intakeStatus: 'admitted',
        );
      }
      applyInfoLine('已导入 $end/${chapters.length} 条章节…');
    }

    await refreshWorkbench(setLocalState);
    applyInfoLine('整本导入完成，共新增 ${chapters.length} 条章节。');
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
}
