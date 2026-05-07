class NovelRow {
  NovelRow({
    required this.id,
    required this.numericId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
    this.createTimeMs,
    this.intakeSource,
    this.intakeSourceUrl,
    this.intakeStatus,
    this.intakeNote,
  });

  final String id;
  final int numericId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;
  final int? createTimeMs;
  final String? intakeSource;
  final String? intakeSourceUrl;
  final String? intakeStatus;
  final String? intakeNote;

  factory NovelRow.fromJson(Map<String, dynamic> json) {
    return NovelRow(
      id: json['id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      chapterIndex: (json['chapter_index'] as num).toInt(),
      reel: json['reel'] as String?,
      chapter: json['chapter'] as String? ?? '',
      chapterData: json['chapter_data'] as String? ?? '',
      event: json['event'] as String?,
      eventState: (json['event_state'] as num).toInt(),
      errorReason: json['error_reason'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
      intakeSource: json['intake_source'] as String?,
      intakeSourceUrl: json['intake_source_url'] as String?,
      intakeStatus: json['intake_status'] as String?,
      intakeNote: json['intake_note'] as String?,
    );
  }
}

/// Body of **`GET …/novels`** — OpenAPI **`ListNovelsResponse`**.
class ListNovelsResponse {
  const ListNovelsResponse({required this.items, required this.total});

  final List<NovelRow> items;
  final int total;

  factory ListNovelsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListNovelsResponse(
      items: raw
          .map((e) => NovelRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// Response for **`POST …/novels/crawl-preview`** — OpenAPI **`NovelCrawlPreviewResponse`**.
class NovelCrawlPreviewResponse {
  const NovelCrawlPreviewResponse({
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

  factory NovelCrawlPreviewResponse.fromJson(Map<String, dynamic> json) {
    return NovelCrawlPreviewResponse(
      title: json['title'] as String? ?? '',
      bodyText: json['body_text'] as String? ?? '',
      mode: json['mode'] as String? ?? 'single',
      pageCount: (json['page_count'] as num?)?.toInt() ?? 1,
      chapterUrlCount: (json['chapter_url_count'] as num?)?.toInt() ?? 0,
      bodyCharCount: (json['body_char_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Response for **`POST …/novels/crawl-import`**.
class NovelCrawlImportResponse {
  const NovelCrawlImportResponse({
    required this.title,
    required this.mode,
    required this.pageCount,
    required this.chapterUrlCount,
    required this.bodyCharCount,
    required this.chaptersCreated,
    required this.qualityWarnings,
  });

  final String title;
  final String mode;
  final int pageCount;
  final int chapterUrlCount;
  final int bodyCharCount;
  final int chaptersCreated;
  final List<String> qualityWarnings;

  factory NovelCrawlImportResponse.fromJson(Map<String, dynamic> json) {
    final rawWarnings = json['quality_warnings'] as List<dynamic>? ?? const [];
    return NovelCrawlImportResponse(
      title: json['title'] as String? ?? '',
      mode: json['mode'] as String? ?? 'single',
      pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
      chapterUrlCount: (json['chapter_url_count'] as num?)?.toInt() ?? 0,
      bodyCharCount: (json['body_char_count'] as num?)?.toInt() ?? 0,
      chaptersCreated: (json['chapters_created'] as num?)?.toInt() ?? 0,
      qualityWarnings: rawWarnings.map((e) => e as String).toList(growable: false),
    );
  }
}

class NovelCrawlImportBatchItem {
  const NovelCrawlImportBatchItem({
    required this.url,
    required this.ok,
    this.errorCode,
    this.errorMessage,
    this.title,
    this.mode,
    this.pageCount,
    this.chapterUrlCount,
    this.bodyCharCount,
    this.chaptersCreated,
    required this.qualityWarnings,
  });

  final String url;
  final bool ok;
  final String? errorCode;
  final String? errorMessage;
  final String? title;
  final String? mode;
  final int? pageCount;
  final int? chapterUrlCount;
  final int? bodyCharCount;
  final int? chaptersCreated;
  final List<String> qualityWarnings;

  factory NovelCrawlImportBatchItem.fromJson(Map<String, dynamic> json) {
    final rawWarnings = json['quality_warnings'] as List<dynamic>? ?? const [];
    return NovelCrawlImportBatchItem(
      url: json['url'] as String? ?? '',
      ok: json['ok'] as bool? ?? false,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      title: json['title'] as String?,
      mode: json['mode'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt(),
      chapterUrlCount: (json['chapter_url_count'] as num?)?.toInt(),
      bodyCharCount: (json['body_char_count'] as num?)?.toInt(),
      chaptersCreated: (json['chapters_created'] as num?)?.toInt(),
      qualityWarnings: rawWarnings.map((e) => e as String).toList(growable: false),
    );
  }
}

class NovelCrawlImportBatchResponse {
  const NovelCrawlImportBatchResponse({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.items,
  });

  final int total;
  final int succeeded;
  final int failed;
  final List<NovelCrawlImportBatchItem> items;

  factory NovelCrawlImportBatchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return NovelCrawlImportBatchResponse(
      total: (json['total'] as num?)?.toInt() ?? 0,
      succeeded: (json['succeeded'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((e) => NovelCrawlImportBatchItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// Compat row (**`getNovelIndex`** shape); filled from **`GET …/projects/{uuid}/novels`**.
class NovelWorkbenchIndexItem {
  const NovelWorkbenchIndexItem({
    required this.numericId,
    required this.chapterIndex,
    required this.chapter,
  });

  final int numericId;
  final int chapterIndex;
  final String chapter;

  factory NovelWorkbenchIndexItem.fromJson(Map<String, dynamic> json) {
    return NovelWorkbenchIndexItem(
      numericId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      chapter: json['chapter'] as String? ?? '',
    );
  }
}

/// Compat row; filled client-side from **`GET …/novels`** (**`event_state != 0`**).
class NovelWorkbenchEventStateItem {
  const NovelWorkbenchEventStateItem({
    required this.numericId,
    this.event,
    required this.eventState,
    this.errorReason,
  });

  final int numericId;
  final String? event;
  final int eventState;
  final String? errorReason;

  factory NovelWorkbenchEventStateItem.fromJson(Map<String, dynamic> json) {
    return NovelWorkbenchEventStateItem(
      numericId: (json['id'] as num).toInt(),
      event: json['event'] as String?,
      eventState: (json['eventState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
    );
  }
}

/// Compat paginated row (**`getNovel`** shape); fields map from REST **`NovelRow`** (snake_case JSON).
class NovelWorkbenchPageRow {
  const NovelWorkbenchPageRow({
    required this.numericId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
  });

  final int numericId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;

  factory NovelWorkbenchPageRow.fromJson(Map<String, dynamic> json) {
    return NovelWorkbenchPageRow(
      numericId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      reel: json['reel'] as String?,
      chapter: json['chapter'] as String? ?? '',
      chapterData: json['chapterData'] as String? ?? '',
      event: json['event'] as String?,
      eventState: (json['eventState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
    );
  }
}

/// Compat **`{ data, total }`** for **`getNovel`**; built from **`GET …/novels`**.
class NovelWorkbenchPagedResponse {
  const NovelWorkbenchPagedResponse({required this.data, required this.total});

  final List<NovelWorkbenchPageRow> data;
  final int total;

  factory NovelWorkbenchPagedResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>;
    return NovelWorkbenchPagedResponse(
      data: raw
          .map((e) => NovelWorkbenchPageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One batch item for compat **`add-novel`**; sent as **`POST …/novels`** bodies.
class NovelWorkbenchAppendItem {
  const NovelWorkbenchAppendItem({
    required this.index,
    required this.reel,
    required this.chapter,
    required this.chapterData,
  });

  final int index;
  final String reel;
  final String chapter;
  final String chapterData;

  Map<String, dynamic> toJson() => {
    'index': index,
    'reel': reel,
    'chapter': chapter,
    'chapterData': chapterData,
  };
}
