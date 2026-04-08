part of 'index.dart';

class NovelRow {
  NovelRow({
    required this.id,
    required this.legacyId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;
  final int? createTimeMs;

  factory NovelRow.fromJson(Map<String, dynamic> json) {
    return NovelRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
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

/// Row from **`POST /api/v1/novels/get-novel-index`** — **`id`** is **`app_novel.legacy_id`**.
class LegacyNovelIndexItem {
  const LegacyNovelIndexItem({
    required this.legacyId,
    required this.chapterIndex,
    required this.chapter,
  });

  final int legacyId;
  final int chapterIndex;
  final String chapter;

  factory LegacyNovelIndexItem.fromJson(Map<String, dynamic> json) {
    return LegacyNovelIndexItem(
      legacyId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      chapter: json['chapter'] as String? ?? '',
    );
  }
}

/// Row from **`POST /api/v1/novels/get-novel`** — response uses **camelCase** (**`chapterData`**, …).
class LegacyNovelPageRow {
  const LegacyNovelPageRow({
    required this.legacyId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
  });

  final int legacyId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;

  factory LegacyNovelPageRow.fromJson(Map<String, dynamic> json) {
    return LegacyNovelPageRow(
      legacyId: (json['id'] as num).toInt(),
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

/// **`POST /api/v1/novels/get-novel`** — **`{ data, total }`**.
class LegacyNovelPagedResponse {
  const LegacyNovelPagedResponse({required this.data, required this.total});

  final List<LegacyNovelPageRow> data;
  final int total;

  factory LegacyNovelPagedResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>;
    return LegacyNovelPagedResponse(
      data: raw
          .map((e) => LegacyNovelPageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One **`app_novel_event`** row with associated chapter indexes.
class NovelEventRow {
  const NovelEventRow({
    required this.id,
    required this.projectId,
    required this.legacyId,
    required this.name,
    required this.detail,
    this.createTimeMs,
    required this.chapterIndexes,
  });

  final String id;
  final String projectId;
  final int legacyId;
  final String name;
  final String detail;
  final int? createTimeMs;
  final List<int> chapterIndexes;

  factory NovelEventRow.fromJson(Map<String, dynamic> json) {
    final rawChapterIndexes =
        json['chapter_indexes'] as List<dynamic>? ?? const [];
    return NovelEventRow(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
      chapterIndexes: rawChapterIndexes.map((e) => (e as num).toInt()).toList(),
    );
  }
}

/// Body of **`GET …/novel-events`**.
class ListNovelEventsResponse {
  const ListNovelEventsResponse({required this.items, required this.total});

  final List<NovelEventRow> items;
  final int total;

  factory ListNovelEventsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListNovelEventsResponse(
      items: raw
          .map((e) => NovelEventRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// Row from **`POST /api/v1/novels/events/get-events`**.
class LegacyNovelEventRow {
  const LegacyNovelEventRow({
    required this.legacyId,
    required this.eventName,
    this.detail,
    required this.createTime,
    required this.chapters,
  });

  final int legacyId;
  final String eventName;
  final String? detail;
  final int createTime;
  final List<int> chapters;

  factory LegacyNovelEventRow.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'] as List<dynamic>? ?? const [];
    return LegacyNovelEventRow(
      legacyId: (json['id'] as num).toInt(),
      eventName: json['eventName'] as String? ?? '',
      detail: json['detail'] as String?,
      createTime: (json['createTime'] as num?)?.toInt() ?? 0,
      chapters: rawChapters.map((e) => (e as num).toInt()).toList(),
    );
  }
}

/// **`POST /api/v1/novels/events/get-events`** — legacy paginated list.
class LegacyNovelEventsPagedResponse {
  const LegacyNovelEventsPagedResponse({
    required this.list,
    required this.total,
  });

  final List<LegacyNovelEventRow> list;
  final int total;

  factory LegacyNovelEventsPagedResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['list'] as List<dynamic>;
    return LegacyNovelEventsPagedResponse(
      list: raw
          .map((e) => LegacyNovelEventRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One entry for **`POST /api/v1/novels/add-novel`** **`data`** (camelCase **`chapterData`**).
class LegacyNovelAddItem {
  const LegacyNovelAddItem({
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
