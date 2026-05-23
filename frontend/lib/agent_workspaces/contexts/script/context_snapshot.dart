import 'package:flutter/material.dart';

import '../../../design_system/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';

String _displayString(Object? raw) {
  if (raw == null) return '';
  if (raw is String) return raw.trim();
  return raw.toString().trim();
}

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

  String _buildRewriteGuidancePreview(
    AppLocalizations l10n,
    Map<String, dynamic> data,
  ) {
    final storySkeleton = (data['storySkeleton'] as String?)?.trim() ?? '';
    final adaptationStrategy =
        (data['adaptationStrategy'] as String?)?.trim() ?? '';
    final scriptRows = (data['script'] is List)
        ? (data['script'] as List).whereType<Map<String, dynamic>>().toList(
            growable: false,
          )
        : const <Map<String, dynamic>>[];
    final skeletonHint = _firstMeaningfulLine(storySkeleton);
    final strategyHint = _firstMeaningfulLine(adaptationStrategy);
    final lines = <String>[];
    if (skeletonHint.isNotEmpty) {
      lines.add(l10n.agentWorkspaceScriptContextSkeletonFocus(skeletonHint));
    }
    if (strategyHint.isNotEmpty) {
      lines.add(l10n.agentWorkspaceScriptContextAdaptationFocus(strategyHint));
    }
    if (scriptRows.isNotEmpty) {
      lines.add(l10n.agentWorkspaceScriptContextExecutionOrder);
      lines.add(l10n.agentWorkspaceScriptContextDialogueConstraint);
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
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
            padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.labelLarge),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudioSpacing.xs),
                  Text(subtitle.trim(), style: theme.bodySmall),
                ],
                const SizedBox(height: StudioSpacing.xs),
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
            ? (data['script'] as List).whereType<Map<String, dynamic>>().toList(
                growable: false,
              )
            : const <Map<String, dynamic>>[];
        addPreviewCard(
          title: l10n.agentWorkspaceScriptContextStorySkeleton,
          body: storySkeleton,
          subtitle: l10n.agentWorkspaceScriptContextFromPlanData,
        );
        addPreviewCard(
          title: l10n.agentWorkspaceScriptContextAdaptationStrategy,
          body: adaptationStrategy,
          subtitle: l10n.agentWorkspaceScriptContextFromPlanData,
        );
        final rewriteGuidance = _buildRewriteGuidancePreview(l10n, data);
        addPreviewCard(
          title: l10n.agentWorkspaceScriptContextRewriteConstraints,
          body: rewriteGuidance,
          subtitle: l10n.agentWorkspaceScriptContextRewriteConstraintsSubtitle,
        );
        if (scriptRows.isNotEmpty) {
          final lines = scriptRows
              .take(4)
              .map((Map<String, dynamic> row) {
                final nameRaw = row['name'] ?? row['scriptName'];
                final nameTrimmed = _displayString(nameRaw);
                final name = nameTrimmed.isNotEmpty
                    ? nameTrimmed
                    : l10n.agentWorkspaceScriptContextUntitledScript;
                final content = _displayString(
                  row['content'] ?? row['scriptData'],
                );
                final preview = content.isEmpty
                    ? l10n.agentWorkspaceScriptContextNoBody
                    : _previewText(content, maxChars: 220);
                return '$name\n$preview';
              })
              .join('\n\n');
          addPreviewCard(
            title: l10n.agentWorkspaceScriptContextPlanDrafts,
            body: lines,
            subtitle: l10n.agentWorkspaceScriptContextPlanDraftsSubtitle,
          );
        }
      }
    }

    if (lastToolName == 'get_script_content' && lastToolResult != null) {
      addPreviewCard(
        title: l10n.agentWorkspaceScriptContextCurrentScriptBody,
        subtitle: l10n.agentWorkspaceScriptContextFromScriptContent,
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
                  (row['chapter'] as String?)?.trim() ??
                  l10n.agentWorkspaceScriptContextUntitledChapter;
              final body =
                  (row['chapter_data'] as String?)?.trim() ??
                  (row['content'] as String?)?.trim() ??
                  '';
              final prefix = chapterIndex is num
                  ? l10n.agentWorkspaceScriptContextChapterPrefix(
                      chapterIndex.toInt(),
                      chapter,
                    )
                  : chapter;
              if (body.isEmpty) return prefix;
              return '$prefix\n${_previewText(body, maxChars: 220)}';
            })
            .join('\n\n');
        addPreviewCard(
          title: l10n.agentWorkspaceScriptContextNovelChapters,
          subtitle: l10n.agentWorkspaceScriptContextNovelChaptersSubtitle,
          body: lines,
        );
      } else {
        final title = (lastToolResult['title'] as String?)?.trim();
        addPreviewCard(
          title: l10n.agentWorkspaceScriptContextNovelChapters,
          subtitle: title == null || title.isEmpty
              ? l10n.agentWorkspaceScriptContextNovelChaptersSubtitle
              : title,
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
                  l10n.agentWorkspaceScriptContextUntitledEvent;
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
          title: l10n.agentWorkspaceScriptContextNovelEvents,
          subtitle: l10n.agentWorkspaceScriptContextNovelEventsSubtitle,
          body: lines,
        );
      }
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          l10n.agentWorkspaceScriptContextSnapshotTitle,
          style: theme.labelLarge,
        ),
        ...sections,
      ],
    );
  }
}
