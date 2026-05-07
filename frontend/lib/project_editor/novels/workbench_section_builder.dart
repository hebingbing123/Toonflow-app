import 'package:flutter/material.dart';

import '../../../rust_api.dart';
import 'support.dart';

Widget buildProjectNovelsWorkbenchSection({
  required BuildContext ctx,
  required List<NovelRow> novels,
  required List<bool> novelsLoading,
  required List<bool> novelsBusy,
  required List<bool> assetsBusy,
  required List<bool> assetsLoading,
  required List<bool> assetsScriptFilterLoading,
  required VoidCallback openWorkbench,
  required Future<void> Function() refreshNovels,
  required Future<void> Function() generateEvents,
}) {
  final first = novels.isNotEmpty ? novels.first : null;
  final last = novels.isNotEmpty ? novels.last : null;
  final summaryLine = summarizeNovelRows(novels);
  final intakeSummaryLine = summarizeNovelIntakeRows(novels);
  final disabled =
      novelsBusy[0] ||
      novelsLoading[0] ||
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
        Text('章节工作台', style: Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          first == null
              ? '用显式表单完成章节新增、搜索、查看、更新、删除和事件生成，不再依赖首条/末条 probe 按钮。'
              : '$summaryLine；首条 #${first.numericId} ${first.chapter}，末条 #${last!.numericId} ${last.chapter}。',
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        if (novels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            intakeSummaryLine,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: disabled ? null : openWorkbench,
              child: const Text('打开章节工作台'),
            ),
            OutlinedButton(
              onPressed: disabled ? null : () => refreshNovels(),
              child: Text(novelsLoading[0] ? '刷新章节…' : '刷新章节'),
            ),
            OutlinedButton(
              onPressed: disabled || novels.isEmpty
                  ? null
                  : () => generateEvents(),
              child: const Text('为前 3 条生成事件'),
            ),
          ],
        ),
      ],
    ),
  );
}
