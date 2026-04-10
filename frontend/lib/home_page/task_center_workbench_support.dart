import '../rust_api.dart';

String summarizeTaskProjects(
  Iterable<LegacyTasksProjectItem> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有任务项目';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.id} ${row.name}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '项目 ${items.length} 个 · $visible$suffix';
}

String summarizeTaskCategories(
  Iterable<LegacyTasksTaskClassRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有任务分类';
  }
  final visible = items.take(maxItems).map((row) => row.taskClass).join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '分类 ${items.length} 个 · $visible$suffix';
}

String summarizeTaskJobs(Iterable<JobRow> rows, {int maxItems = 4}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有任务记录';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.legacyTaskId} ${row.kind}:${row.status}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '任务 ${items.length} 条 · $visible$suffix';
}

String formatTaskJobDetails(JobRow row) {
  final payloadKeys = row.payload.keys.take(4).join(', ');
  final resultKeys = row.result?.keys.take(4).join(', ');
  return [
    '#${row.legacyTaskId}',
    row.kind,
    row.status,
    'uuid=${row.id}',
    'updated=${row.updatedAt}',
    if (row.claimedBy != null && row.claimedBy!.isNotEmpty)
      'claimed_by=${row.claimedBy}',
    if (row.errorMessage != null && row.errorMessage!.isNotEmpty)
      'error=${row.errorMessage}',
    if (payloadKeys.isNotEmpty) 'payload={$payloadKeys}',
    if (resultKeys != null && resultKeys.isNotEmpty) 'result={$resultKeys}',
  ].join(' · ');
}
