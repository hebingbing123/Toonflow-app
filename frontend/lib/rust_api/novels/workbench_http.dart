import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import '../project/index.dart' as project_api;
import 'models.dart';
import 'project_scope.dart';
import 'rest_api.dart';

/// Compat: full novel rows via **`GET /api/v1/projects/{uuid}/novels`** (workbench **`getNovelData`**).
Future<List<NovelRow>> fetchNovelWorkbenchFullRows(
  String accessToken,
  int projectNumericId, {
  String? projectUuid,
}
) async {
  final projectId = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  final res = await fetchProjectNovelsByProjectId(accessToken, projectId);
  return res.items;
}

/// Compat: index list via **`GET …/novels`** (**`getNovelIndex`** shape).
Future<List<NovelWorkbenchIndexItem>> fetchNovelWorkbenchIndex(
  String accessToken,
  int projectNumericId, {
  String? projectUuid,
}
) async {
  final projectId = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  final res = await fetchProjectNovelsByProjectId(accessToken, projectId);
  return res.items
      .map(
        (n) => NovelWorkbenchIndexItem(
          numericId: n.numericId,
          chapterIndex: n.chapterIndex,
          chapter: n.chapter,
        ),
      )
      .toList();
}

/// Compat: non-zero **`event_state`** among **`numericIds`** (same project UUID).
Future<List<NovelWorkbenchEventStateItem>> fetchNovelWorkbenchEventStates(
  String accessToken,
  String projectUuid,
  List<int> numericIds,
) async {
  if (numericIds.isEmpty) {
    return [];
  }
  final want = numericIds.toSet();
  final out = <NovelWorkbenchEventStateItem>[];
  var page = 1;
  const limit = 200;
  while (true) {
    final batch = await fetchProjectNovelsByProjectId(
      accessToken,
      projectUuid,
      page: page,
      limit: limit,
    );
    for (final row in batch.items) {
      if (want.contains(row.numericId) && row.eventState != 0) {
        out.add(
          NovelWorkbenchEventStateItem(
            numericId: row.numericId,
            event: row.event,
            eventState: row.eventState,
            errorReason: row.errorReason,
          ),
        );
      }
    }
    if (batch.items.length < limit || page * limit >= batch.total) {
      break;
    }
    page++;
  }
  out.sort((a, b) => a.numericId.compareTo(b.numericId));
  return out;
}

/// Compat: async event extraction — **`POST …/novel-events/generate-events`** (project UUID in path).
Future<String> postNovelEventsGenerateEvents(
  String accessToken, {
  required int projectNumericId,
  String? projectUuid,
  required List<int> novelIds,
  int concurrentCount = 5,
}) async {
  final projectId = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novel-events/generate-events',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'novelIds': novelIds,
          'concurrentCount': concurrentCount,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// Compat: paginated list (**`getNovel`**: **`{ data, total }`**).
Future<NovelWorkbenchPagedResponse> fetchNovelWorkbenchPaged(
  String accessToken,
  int projectNumericId, {
  String? projectUuid,
  required int page,
  required int limit,
  String? search,
}) async {
  final projectId = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  final res = await fetchProjectNovelsByProjectId(
    accessToken,
    projectId,
    search: search,
    page: page,
    limit: limit,
  );
  final data = res.items
      .map(
        (n) => NovelWorkbenchPageRow(
          numericId: n.numericId,
          chapterIndex: n.chapterIndex,
          reel: n.reel,
          chapter: n.chapter,
          chapterData: n.chapterData,
          event: n.event,
          eventState: n.eventState,
          errorReason: n.errorReason,
        ),
      )
      .toList();
  return NovelWorkbenchPagedResponse(data: data, total: res.total);
}

/// Compat: batch add — sequential **`POST …/novels`** (empty **`data`** → success message, no HTTP).
Future<String> appendNovelsUnderProject(
  String accessToken,
  int projectNumericId,
  List<NovelWorkbenchAppendItem> data, {
  String? projectUuid,
}
) async {
  if (data.isEmpty) {
    return '新增原文成功';
  }
  final projectId = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  for (final item in data) {
    await createProjectNovelUnderProject(
      accessToken,
      projectId,
      chapterIndex: item.index,
      reel: item.reel,
      chapter: item.chapter,
      chapterData: item.chapterData,
    );
  }
  return '新增原文成功';
}

Future<String> _deleteNovelByNumericIdScanningProjects(
  String accessToken,
  int novelNumericId, {
  String? projectUuid,
}
) async {
  if (novelNumericId <= 0) {
    throw RustApiException('id must be positive', statusCode: 400);
  }
  final explicitProjectUuid = projectUuid?.trim();
  if (explicitProjectUuid != null && explicitProjectUuid.isNotEmpty) {
    await deleteProjectNovelByProjectIds(
      accessToken,
      explicitProjectUuid,
      novelNumericId,
    );
    return '删除原文成功';
  }
  final projects = await project_api.fetchAllProjectsPaged(accessToken);
  for (final p in projects) {
    try {
      await deleteProjectNovelByProjectIds(accessToken, p.id, novelNumericId);
      return '删除原文成功';
    } on RustApiException catch (e) {
      if (e.statusCode == 404) {
        continue;
      }
      rethrow;
    }
  }
  throw RustApiException('not found', statusCode: 404);
}

/// Compat: delete by **`app_novel`** numeric id (scans owned projects).
Future<String> deleteNovelByNumericIdScanningProjects(
  String accessToken,
  int novelNumericId, {
  String? projectUuid,
}
) async {
  return _deleteNovelByNumericIdScanningProjects(
    accessToken,
    novelNumericId,
    projectUuid: projectUuid,
  );
}

Future<String> _patchNovelByNumericIdScanningProjects(
  String accessToken, {
  required int id,
  String? projectUuid,
  required Object index,
  required String reel,
  required String chapter,
  required String chapterData,
  required String event,
}) async {
  if (id <= 0) {
    throw RustApiException('id must be positive', statusCode: 400);
  }
  final idx = index is int
      ? index
      : index is num
      ? index.toInt()
      : int.tryParse('$index');
  if (idx == null) {
    throw RustApiException('invalid index', statusCode: 400);
  }
  final projects = await project_api.fetchAllProjectsPaged(accessToken);
  final body = <String, dynamic>{
    'chapter_index': idx,
    'reel': reel,
    'chapter': chapter,
    'chapter_data': chapterData,
    'event': event,
  };
  final explicitProjectUuid = projectUuid?.trim();
  if (explicitProjectUuid != null && explicitProjectUuid.isNotEmpty) {
    await patchProjectNovelByProjectIds(accessToken, explicitProjectUuid, id, body);
    return '更新原文成功';
  }
  for (final p in projects) {
    try {
      await fetchProjectNovelByProjectIds(accessToken, p.id, id);
    } on RustApiException catch (e) {
      if (e.statusCode == 404) {
        continue;
      }
      rethrow;
    }
    await patchProjectNovelByProjectIds(accessToken, p.id, id, body);
    return '更新原文成功';
  }
  throw RustApiException('not found', statusCode: 404);
}

/// Compat: update by numeric id (**`index`** may be int or numeric string).
Future<String> updateNovelScanningProjects(
  String accessToken, {
  required int id,
  String? projectUuid,
  required Object index,
  required String reel,
  required String chapter,
  required String chapterData,
  required String event,
}) async {
  return _patchNovelByNumericIdScanningProjects(
    accessToken,
    id: id,
    projectUuid: projectUuid,
    index: index,
    reel: reel,
    chapter: chapter,
    chapterData: chapterData,
    event: event,
  );
}

/// Compat: batch delete — **`DELETE …/novels/{numeric_id}`** per id under **`projectUuid`**.
Future<String> batchDeleteNovelsUnderProject(
  String accessToken,
  String projectUuid,
  List<int> numericIds,
) async {
  if (numericIds.isEmpty) {
    throw RustApiException('请先选择需要删除的内容', statusCode: 400);
  }
  if (numericIds.length > 500) {
    throw RustApiException('too many ids', statusCode: 400);
  }
  var any = false;
  for (final id in numericIds) {
    try {
      await deleteProjectNovelByProjectIds(accessToken, projectUuid, id);
      any = true;
    } on RustApiException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
    }
  }
  if (!any) {
    throw RustApiException('not found', statusCode: 404);
  }
  return '删除原文成功';
}
