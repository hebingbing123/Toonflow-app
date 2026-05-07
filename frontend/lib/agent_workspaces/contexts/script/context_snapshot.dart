import 'package:flutter/material.dart';

/// Renders the context snapshot cards for the script workspace.
/// Extracted from [AgentWorkspaceScriptCard] to keep file size manageable.
class ScriptContextSnapshotView extends StatelessWidget {
  const ScriptContextSnapshotView({
    super.key,
    required this.workspaceScriptPlanWritebackCandidate,
    required this.workspaceLastToolName,
    required this.workspaceLastToolResultData,
  });

  final Map<String, dynamic>? workspaceScriptPlanWritebackCandidate;
  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;

  Map<String, dynamic>? get _lastToolResultMap {
    final raw = workspaceLastToolResultData;
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  String _firstMeaningfulLine(String value) {
    for (final line in value.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.startsWith('- ') ? trimmed.substring(2).trim() : trimmed;
    }
    return '';
  }

  String _buildRewriteGuidancePreview(Map<String, dynamic> data) {
    final storySkeleton = (data['storySkeleton'] as String?)?.trim() ?? '';
    final adaptationStrategy =
        (data['adaptationStrategy'] as String?)?.trim() ?? '';
    final scriptRows = (data['script'] is List)
        ? (data['script'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final skeletonHint = _firstMeaningfulLine(storySkeleton);
    final strategyHint = _firstMeaningfulLine(adaptationStrategy);
    final lines = <String>[];
    if (skeletonHint.isNotEmpty) {
      lines.add('骨架重点：$skeletonHint');
    }
    if (strategyHint.isNotEmpty) {
      lines.add('改编口径：$strategyHint');
    }
    if (scriptRows.isNotEmpty) {
      lines.add('执行顺序：先消费 planData.script 草稿，再按需补事件与章节正文。');
      lines.add('对白约束：避免解释剧情，优先口语化冲突表达和情绪推进。');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sections = <Widget>[];
    final planData = workspaceScriptPlanWritebackCandidate;
    final lastToolName = workspaceLastToolName;
    final lastToolResult = _lastToolResultMap;

    void addPreviewCard({
      required String title,
      required String body,
      String? subtitle,
    }) {
      final normalized = body.trim();
      if (normalized.isEmpty) return;
      sections.add(
        Card(
          margin: const EdgeInsets.only(top: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.labelLarge),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle.trim(), style: theme.bodySmall),
                ],
                const SizedBox(height: 6),
                SelectableText(
                  _previewText(normalized, maxChars: 1200),
                  style: theme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (planData != null) {
      final data = planData['data'];
      if (data is Map<String, dynamic>) {
        final storySkeleton = (data['storySkeleton'] as String?)?.trim() ?? '';
        final adaptationStrategy =
            (data['adaptationStrategy'] as String?)?.trim() ?? '';
        final scriptRows = (data['script'] is List)
            ? (data['script'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false)
            : const <Map<String, dynamic>>[];
        addPreviewCard(
          title: '故事骨架',
          body: storySkeleton,
          subtitle: '来自 get_planData',
        );
        addPreviewCard(
          title: '改编策略',
          body: adaptationStrategy,
          subtitle: '来自 get_planData',
        );
        final rewriteGuidance = _buildRewriteGuidancePreview(data);
        addPreviewCard(
          title: '改写约束',
          body: rewriteGuidance,
          subtitle: '由 get_planData 派生的下游消费提示',
        );
        if (scriptRows.isNotEmpty) {
          final lines = scriptRows
              .take(4)
              .map((Map<String, dynamic> row) {
                final name = ((row['name'] as String?) ??
                            (row['scriptName'] as String?))
                        ?.trim()
                        .isNotEmpty ==
                    true
                    ? (((row['name'] as String?) ??
                              (row['scriptName'] as String?))!)
                          .trim()
                    : '未命名剧本';
                final content =
                    ((row['content'] as String?) ??
                            (row['scriptData'] as String?))
                        ?.trim() ??
                    '';
                final preview = content.isEmpty
                    ? '无正文'
                    : _previewText(content, maxChars: 220);
                return '$name\n$preview';
              })
              .join('\n\n');
          addPreviewCard(
            title: '计划内剧本草稿',
            body: lines,
            subtitle: '最多展示前 4 条 script rows',
          );
        }
      }
    }

    if (lastToolName == 'get_script_content' && lastToolResult != null) {
      addPreviewCard(
        title: '当前剧本正文',
        subtitle: '来自 get_script_content',
        body: (lastToolResult['content'] as String?) ?? '',
      );
    }

    if (lastToolName == 'get_novel_text' && lastToolResult != null) {
      final items = (lastToolResult['items'] is List)
          ? (lastToolResult['items'] as List)
                .whereType<Map<String, dynamic>>()
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (items.isNotEmpty) {
        final lines = items
            .take(4)
            .map((Map<String, dynamic> row) {
              final chapterIndex = row['chapter_index'] ?? row['chapterIndex'];
              final chapter =
                  (row['chapter'] as String?)?.trim() ?? '未命名章节';
              final body =
                  (row['chapter_data'] as String?)?.trim() ??
                  (row['content'] as String?)?.trim() ??
                  '';
              final prefix = chapterIndex is num
                  ? '第 ${chapterIndex.toInt()} 章 · $chapter'
                  : chapter;
              if (body.isEmpty) return prefix;
              return '$prefix\n${_previewText(body, maxChars: 220)}';
            })
            .join('\n\n');
        addPreviewCard(
          title: '小说章节正文',
          subtitle: '来自 get_novel_text，最多展示前 4 条',
          body: lines,
        );
      } else {
        final title = (lastToolResult['title'] as String?)?.trim();
        addPreviewCard(
          title: '小说章节正文',
          subtitle:
              title == null || title.isEmpty ? '来自 get_novel_text' : title,
          body: (lastToolResult['content'] as String?) ?? '',
        );
      }
    }

    if (lastToolName == 'get_novel_events' && lastToolResult != null) {
      final rawEvents = lastToolResult['events'] ?? lastToolResult['items'];
      final events = rawEvents is List
          ? rawEvents.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];
      if (events.isNotEmpty) {
        final lines = events
            .take(6)
            .map((Map<String, dynamic> row) {
              final title =
                  (row['title'] as String?)?.trim() ??
                  (row['name'] as String?)?.trim() ??
                  '未命名事件';
              final description =
                  (row['content'] as String?)?.trim() ??
                  (row['detail'] as String?)?.trim() ??
                  (row['description'] as String?)?.trim() ??
                  '';
              if (description.isEmpty) return title;
              return '$title\n${_previewText(description, maxChars: 180)}';
            })
            .join('\n\n');
        addPreviewCard(
          title: '小说事件',
          subtitle: '来自 get_novel_events，最多展示前 6 条',
          body: lines,
        );
      }
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text('上下文快照', style: theme.labelLarge),
        ...sections,
      ],
    );
  }
}
