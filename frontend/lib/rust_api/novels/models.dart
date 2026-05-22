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

/// Optional per-request crawl auth override (merged with stored project config).
class NovelCrawlAuthOverride {
  const NovelCrawlAuthOverride({
    this.cookie,
    this.username,
    this.password,
  });

  final String? cookie;
  final String? username;
  final String? password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (cookie != null && cookie!.isNotEmpty) 'cookie': cookie,
      if (username != null && username!.isNotEmpty) 'username': username,
      if (password != null && password!.isNotEmpty) 'password': password,
    };
  }

  bool get isEmpty =>
      (cookie == null || cookie!.isEmpty) &&
      (username == null || username!.isEmpty) &&
      (password == null || password!.isEmpty);
}

/// Response for **`GET/PUT …/novels/crawl-auth`**.
class NovelCrawlAuthGetResponse {
  const NovelCrawlAuthGetResponse({
    required this.authMode,
    required this.hasCookie,
    required this.hasUsername,
    required this.hasPassword,
    this.loginUrl,
    required this.loginUsernameField,
    required this.loginPasswordField,
    required this.encryptionConfigured,
    this.updatedAt,
  });

  final String authMode;
  final bool hasCookie;
  final bool hasUsername;
  final bool hasPassword;
  final String? loginUrl;
  final String loginUsernameField;
  final String loginPasswordField;
  final bool encryptionConfigured;
  final String? updatedAt;

  factory NovelCrawlAuthGetResponse.fromJson(Map<String, dynamic> json) {
    return NovelCrawlAuthGetResponse(
      authMode: json['auth_mode'] as String? ?? 'none',
      hasCookie: json['has_cookie'] as bool? ?? false,
      hasUsername: json['has_username'] as bool? ?? false,
      hasPassword: json['has_password'] as bool? ?? false,
      loginUrl: json['login_url'] as String?,
      loginUsernameField: json['login_username_field'] as String? ?? 'username',
      loginPasswordField: json['login_password_field'] as String? ?? 'password',
      encryptionConfigured: json['encryption_configured'] as bool? ?? false,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

/// Body for **`PUT …/novels/crawl-auth`**.
class NovelCrawlAuthPutBody {
  const NovelCrawlAuthPutBody({
    required this.authMode,
    this.cookie,
    this.username,
    this.password,
    this.loginUrl,
    this.loginUsernameField,
    this.loginPasswordField,
  });

  final String authMode;
  final String? cookie;
  final String? username;
  final String? password;
  final String? loginUrl;
  final String? loginUsernameField;
  final String? loginPasswordField;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'auth_mode': authMode,
      'cookie': cookie,
      'username': username,
      'password': password,
      'login_url': loginUrl,
      'login_username_field': loginUsernameField,
      'login_password_field': loginPasswordField,
    };
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
      qualityWarnings: rawWarnings
          .map((e) => e as String)
          .toList(growable: false),
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
      qualityWarnings: rawWarnings
          .map((e) => e as String)
          .toList(growable: false),
    );
  }
}

/// One chapter in a whole-book import batch request.
class WholeBookImportChapterItem {
  const WholeBookImportChapterItem({
    required this.chapterIndex,
    required this.chapter,
    required this.chapterData,
  });

  final int chapterIndex;
  final String chapter;
  final String chapterData;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'chapter_index': chapterIndex,
    'chapter': chapter,
    'chapter_data': chapterData,
  };
}

/// Response for **`POST …/novels/whole-book-import`**.
class WholeBookImportResponse {
  const WholeBookImportResponse({
    required this.imported,
    required this.skippedExisting,
    required this.nextListIndex,
    required this.totalChapters,
    required this.batchTag,
    required this.contentHash,
    required this.completed,
    required this.canResume,
    this.failedAtListIndex,
  });

  final int imported;
  final int skippedExisting;
  final int nextListIndex;
  final int totalChapters;
  final String batchTag;
  final String contentHash;
  final bool completed;
  final bool canResume;
  final int? failedAtListIndex;

  factory WholeBookImportResponse.fromJson(Map<String, dynamic> json) {
    return WholeBookImportResponse(
      imported: (json['imported'] as num?)?.toInt() ?? 0,
      skippedExisting: (json['skipped_existing'] as num?)?.toInt() ?? 0,
      nextListIndex: (json['next_list_index'] as num?)?.toInt() ?? 0,
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      batchTag: json['batch_tag'] as String? ?? '',
      contentHash: json['content_hash'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      canResume: json['can_resume'] as bool? ?? false,
      failedAtListIndex: (json['failed_at_list_index'] as num?)?.toInt(),
    );
  }
}

/// Active whole-book import session (**`GET …/whole-book-import/session`**).
class WholeBookImportSessionResponse {
  const WholeBookImportSessionResponse({
    required this.contentHash,
    required this.sourceDisplayName,
    required this.batchTag,
    required this.nextListIndex,
    required this.totalChapters,
    required this.updatedAtMs,
  });

  final String contentHash;
  final String sourceDisplayName;
  final String batchTag;
  final int nextListIndex;
  final int totalChapters;
  final int updatedAtMs;

  factory WholeBookImportSessionResponse.fromJson(Map<String, dynamic> json) {
    return WholeBookImportSessionResponse(
      contentHash: json['content_hash'] as String? ?? '',
      sourceDisplayName: json['source_display_name'] as String? ?? '',
      batchTag: json['batch_tag'] as String? ?? '',
      nextListIndex: (json['next_list_index'] as num?)?.toInt() ?? 0,
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
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
          .map(
            (e) =>
                NovelCrawlImportBatchItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class NovelCrawlScheduleRow {
  const NovelCrawlScheduleRow({
    required this.numericTaskId,
    required this.id,
    required this.kind,
    required this.status,
    required this.payload,
    this.errorMessage,
    this.errorDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  final int numericTaskId;
  final String id;
  final String kind;
  final String status;
  final Map<String, dynamic> payload;
  final String? errorMessage;
  final Map<String, dynamic>? errorDetails;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? get runAtMs => (payload['run_at_ms'] as num?)?.toInt();
  int? get repeatIntervalMs => (payload['repeat_interval_ms'] as num?)?.toInt();

  factory NovelCrawlScheduleRow.fromJson(Map<String, dynamic> json) {
    return NovelCrawlScheduleRow(
      numericTaskId: (json['numeric_task_id'] as num).toInt(),
      id: json['id'] as String,
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      errorMessage: json['error_message'] as String?,
      errorDetails: json['error_details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class NovelIntakeSourceCount {
  const NovelIntakeSourceCount({
    required this.intakeSource,
    required this.chapterCount,
  });
  final String? intakeSource;
  final int chapterCount;

  factory NovelIntakeSourceCount.fromJson(Map<String, dynamic> json) {
    return NovelIntakeSourceCount(
      intakeSource: json['intake_source'] as String?,
      chapterCount: (json['chapter_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NovelIntakeStatusCount {
  const NovelIntakeStatusCount({
    required this.intakeStatus,
    required this.chapterCount,
  });
  final String? intakeStatus;
  final int chapterCount;

  factory NovelIntakeStatusCount.fromJson(Map<String, dynamic> json) {
    return NovelIntakeStatusCount(
      intakeStatus: json['intake_status'] as String?,
      chapterCount: (json['chapter_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NovelCrawlJobStatusCount {
  const NovelCrawlJobStatusCount({
    required this.status,
    required this.jobCount,
  });
  final String status;
  final int jobCount;

  factory NovelCrawlJobStatusCount.fromJson(Map<String, dynamic> json) {
    return NovelCrawlJobStatusCount(
      status: json['status'] as String? ?? '',
      jobCount: (json['job_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NovelCrawlAuditSampleRow {
  const NovelCrawlAuditSampleRow({
    required this.numericId,
    this.intakeSourceUrl,
    this.intakeNote,
    this.createTimeMs,
  });

  final int numericId;
  final String? intakeSourceUrl;
  final String? intakeNote;
  final int? createTimeMs;

  factory NovelCrawlAuditSampleRow.fromJson(Map<String, dynamic> json) {
    return NovelCrawlAuditSampleRow(
      numericId: (json['numeric_id'] as num?)?.toInt() ?? 0,
      intakeSourceUrl: json['intake_source_url'] as String?,
      intakeNote: json['intake_note'] as String?,
      createTimeMs: (json['create_time_ms'] as num?)?.toInt(),
    );
  }
}

class NovelCrawlObservabilityResponse {
  const NovelCrawlObservabilityResponse({
    required this.totalChapters,
    required this.intakeSources,
    required this.intakeStatuses,
    required this.recentServerImports,
    required this.crawlJobStatuses,
  });

  final int totalChapters;
  final List<NovelIntakeSourceCount> intakeSources;
  final List<NovelIntakeStatusCount> intakeStatuses;
  final List<NovelCrawlAuditSampleRow> recentServerImports;
  final List<NovelCrawlJobStatusCount> crawlJobStatuses;

  factory NovelCrawlObservabilityResponse.fromJson(Map<String, dynamic> json) {
    final rawSources = json['intake_sources'] as List<dynamic>? ?? const [];
    final rawStatuses = json['intake_statuses'] as List<dynamic>? ?? const [];
    final rawImports =
        json['recent_server_imports'] as List<dynamic>? ?? const [];
    final rawJobs = json['crawl_job_statuses'] as List<dynamic>? ?? const [];
    return NovelCrawlObservabilityResponse(
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      intakeSources: rawSources
          .map(
            (e) => NovelIntakeSourceCount.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      intakeStatuses: rawStatuses
          .map(
            (e) => NovelIntakeStatusCount.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      recentServerImports: rawImports
          .map(
            (e) => NovelCrawlAuditSampleRow.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      crawlJobStatuses: rawJobs
          .map(
            (e) => NovelCrawlJobStatusCount.fromJson(e as Map<String, dynamic>),
          )
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
