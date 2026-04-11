part of 'index.dart';

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

/// Compat row (**`getNovelIndex`** shape); filled from **`GET …/projects/{uuid}/novels`**.
class LegacyNovelIndexItem {
  const LegacyNovelIndexItem({
    required this.numericId,
    required this.chapterIndex,
    required this.chapter,
  });

  final int numericId;
  final int chapterIndex;
  final String chapter;

  factory LegacyNovelIndexItem.fromJson(Map<String, dynamic> json) {
    return LegacyNovelIndexItem(
      numericId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      chapter: json['chapter'] as String? ?? '',
    );
  }
}

/// Compat row; filled client-side from **`GET …/novels`** (**`event_state != 0`**).
class LegacyNovelEventStateItem {
  const LegacyNovelEventStateItem({
    required this.numericId,
    this.event,
    required this.eventState,
    this.errorReason,
  });

  final int numericId;
  final String? event;
  final int eventState;
  final String? errorReason;

  factory LegacyNovelEventStateItem.fromJson(Map<String, dynamic> json) {
    return LegacyNovelEventStateItem(
      numericId: (json['id'] as num).toInt(),
      event: json['event'] as String?,
      eventState: (json['eventState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
    );
  }
}

/// Compat paginated row (**`getNovel`** shape); fields map from REST **`NovelRow`** (snake_case JSON).
class LegacyNovelPageRow {
  const LegacyNovelPageRow({
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

  factory LegacyNovelPageRow.fromJson(Map<String, dynamic> json) {
    return LegacyNovelPageRow(
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

/// One batch item for compat **`add-novel`**; sent as **`POST …/novels`** bodies.
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
