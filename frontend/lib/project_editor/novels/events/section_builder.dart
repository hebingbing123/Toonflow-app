import 'package:flutter/material.dart';

import '../../../../../rust_api.dart';
import '../support.dart';

Widget buildProjectNovelEventsWorkbenchSection({
  required BuildContext ctx,
  required List<NovelEventRow> events,
  required List<bool> novelsLoading,
  required List<bool> novelsBusy,
  required List<bool> novelEventsLoading,
  required List<bool> assetsBusy,
  required List<bool> assetsLoading,
  required List<bool> assetsScriptFilterLoading,
  required Future<void> Function() openWorkbench,
  required Future<void> Function() refreshEvents,
}) {
  final first = events.isNotEmpty ? events.first : null;
  final summaryLine = summarizeNovelEventRows(events);
  final disabled =
      novelsBusy[0] ||
      novelsLoading[0] ||
      novelEventsLoading[0] ||
      assetsBusy[0] ||
      assetsLoading[0] ||
      assetsScriptFilterLoading[0];

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(
        ctx,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('事件工作台', style: Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          first == null
              ? '用显式表单管理事件搜索、创建、更新、删除和批量删除，减少对 HTTP probe 按钮的依赖。'
              : '$summaryLine；首条 #${first.numericId} ${first.name}。',
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: disabled ? null : openWorkbench,
              child: const Text('打开事件工作台'),
            ),
            OutlinedButton(
              onPressed: disabled ? null : refreshEvents,
              child: Text(novelEventsLoading[0] ? '刷新事件…' : '刷新事件'),
            ),
          ],
        ),
      ],
    ),
  );
}
