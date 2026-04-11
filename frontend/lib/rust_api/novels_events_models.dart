part of 'index.dart';

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
      legacyId: (json['numeric_id'] as num).toInt(),
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

/// Compat event row (**`get-events`** shape); mapped from **`GET …/novel-events`**.
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

/// Compat **`{ list, total }`**; built from **`GET …/novel-events`**.
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
