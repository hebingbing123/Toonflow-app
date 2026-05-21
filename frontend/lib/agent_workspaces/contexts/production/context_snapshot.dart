import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../design_system/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import 'flow_logic.dart';
import 'support.dart';

/// Renders the context snapshot cards for the production workspace.
/// Extracted from [AgentWorkspaceProductionCard] to keep file size manageable.
class ProductionContextSnapshotView extends StatelessWidget {
  const ProductionContextSnapshotView({
    super.key,
    required this.workspaceLastToolName,
    required this.workspaceLastToolResultData,
    required this.workspaceSuggestedFlowKey,
  });

  static const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
  final String? workspaceSuggestedFlowKey;

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) return value;
    return '${value.substring(0, maxChars)}...';
  }

  String _buildPreviewBody(
    AppLocalizations l10n,
    Object body, {
    String? flowKey,
    Set<int> focusedStoryboardIds = const <int>{},
  }) {
    final normalizedKey = flowKey?.trim() ?? '';
    final summary = summarizeProductionFlowValue(
      l10n,
      body,
      flowKey: normalizedKey,
    ).join(' · ');
    final String digest;
    if (normalizedKey == 'script') {
      digest = _scriptDigest(body);
    } else if (normalizedKey == 'scriptPlan') {
      digest = _scriptPlanDigest(body);
    } else if (normalizedKey == 'storyboardTable') {
      digest = _storyboardTableDigest(
        l10n,
        body,
        focusedStoryboardIds: focusedStoryboardIds,
      );
    } else if (normalizedKey == 'storyboard') {
      digest = _storyboardDigest(l10n, body);
    } else if (body is String) {
      digest = body.trim();
    } else {
      digest = _prettyJsonEncoder.convert(body).trim();
    }
    if (summary.isEmpty) return digest;
    if (digest.isEmpty || digest == summary) return summary;
    return '$summary\n\n$digest';
  }

  String _plainTextDigest(
    String value, {
    int maxLines = 6,
    int maxChars = 360,
  }) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(maxLines)
        .toList(growable: false);
    if (lines.isEmpty) {
      return value.trim();
    }
    return _previewText(lines.join('\n'), maxChars: maxChars);
  }

  String _scriptDigest(Object body) {
    if (body is! String) {
      return _prettyJsonEncoder.convert(body).trim();
    }
    return _plainTextDigest(body, maxLines: 8, maxChars: 420);
  }

  String _scriptPlanDigest(Object body) {
    if (body is! String) {
      return _prettyJsonEncoder.convert(body).trim();
    }
    final sections = summarizeProductionScriptPlanSections(body);
    if (sections.isNotEmpty) {
      return sections.join('\n');
    }
    return _plainTextDigest(body, maxLines: 8, maxChars: 420);
  }

  String _scriptPlanRewriteConstraintDigest(
    AppLocalizations l10n,
    Object body,
  ) {
    if (body is! String) {
      return '';
    }
    final sections = summarizeProductionScriptPlanSections(
      body,
      maxSections: 3,
    );
    if (sections.isEmpty) {
      return '';
    }
    final assetScope = summarizeProductionAssetScope(
      l10n,
      buildProductionScriptPlanAssetArgs(body),
    );
    final lines = <String>[
      l10n.agentWorkspaceProductionPromptFlowDown,
      l10n.agentWorkspaceProductionPromptRewriteFocus(sections.first),
      if (sections.length > 1)
        l10n.agentWorkspaceProductionPromptVisualPacing(sections[1]),
      if (sections.length > 2)
        l10n.agentWorkspaceProductionPromptExtraConstraint(sections[2]),
      l10n.agentWorkspaceProductionPromptAssetFocus(assetScope),
      l10n.agentWorkspaceProductionPromptExecutionOrder,
    ];
    return lines.join('\n');
  }

  String _storyboardTableDigest(
    AppLocalizations l10n,
    Object body, {
    Set<int> focusedStoryboardIds = const <int>{},
  }) {
    final rows = switch (body) {
      String value => parseProductionStoryboardTableMarkdown(value),
      Map<String, dynamic> value =>
        (value['rows'] is List)
            ? (value['rows'] as List).whereType<Map<String, dynamic>>().toList(
                growable: false,
              )
            : const <Map<String, dynamic>>[],
      _ => const <Map<String, dynamic>>[],
    };
    if (rows.isEmpty) {
      return switch (body) {
        String value => value.trim(),
        _ => _prettyJsonEncoder.convert(body).trim(),
      };
    }
    final focusedRows = focusedStoryboardIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : rows
              .where((row) {
                final id = _readNumericId(
                  row['id'] ??
                      row['numeric_id'] ??
                      row['numericId'] ??
                      row['storyboardId'],
                );
                return id != null && focusedStoryboardIds.contains(id);
              })
              .toList(growable: false);
    final selectedRows = (focusedRows.isNotEmpty ? focusedRows : rows)
        .take(4)
        .toList(growable: false);
    final hiddenCount = rows.length - selectedRows.length;
    final lines = <String>[
      if (focusedRows.isNotEmpty)
        l10n.agentWorkspaceProductionStoryboardPriorityMissing,
      ...selectedRows.map((row) => _formatStoryboardTableRow(l10n, row)),
      if (hiddenCount > 0)
        l10n.agentWorkspaceProductionCollapsedRows(hiddenCount),
    ];
    return lines.join('\n\n');
  }

  String _storyboardDigest(AppLocalizations l10n, Object body) {
    if (body is! List) {
      return switch (body) {
        String value => value.trim(),
        _ => _prettyJsonEncoder.convert(body).trim(),
      };
    }
    final rows = body.whereType<Map<String, dynamic>>().toList(growable: false);
    if (rows.isEmpty) {
      return _prettyJsonEncoder.convert(body).trim();
    }
    final missingRows = rows
        .where((row) {
          return productionStoryboardEntryNeedsImageGeneration(row) &&
              !productionFlowEntryHasMediaResult(row);
        })
        .toList(growable: false);
    final selectedRows = (missingRows.isNotEmpty ? missingRows : rows)
        .take(4)
        .map((row) => _formatStoryboardRow(l10n, row))
        .toList(growable: false);
    final hiddenCount = rows.length - selectedRows.length;
    final lines = <String>[
      if (missingRows.isNotEmpty)
        l10n.agentWorkspaceProductionStoryboardPriorityMissing,
      ...selectedRows,
      if (hiddenCount > 0)
        l10n.agentWorkspaceProductionCollapsedRows(hiddenCount),
    ];
    return lines.join('\n\n');
  }

  String _reviewDigest(
    AppLocalizations l10n,
    ProductionSupervisionReview review,
  ) {
    final lines = <String>[
      l10n.agentWorkspaceProductionReviewTarget(review.target),
      l10n.agentWorkspaceProductionReviewGrade(review.grade),
      l10n.agentWorkspaceProductionReviewIssues(
        review.severeCount,
        review.mediumCount,
        review.minorCount,
      ),
      l10n.agentWorkspaceProductionReviewNextStep(review.nextAction),
      if (review.assetIds.isNotEmpty)
        l10n.agentWorkspaceProductionReviewAssetIds(review.assetIds.join(', ')),
      if (review.assetIds.isEmpty && review.assetTypes.isNotEmpty)
        l10n.agentWorkspaceProductionReviewAssetScope(
          summarizeProductionAssetTypeScope(l10n, review.assetTypes),
        ),
      if (review.storyboardIds.isNotEmpty)
        l10n.agentWorkspaceProductionReviewStoryboardIds(
          review.storyboardIds.join(', '),
        ),
      if (review.summary.isNotEmpty)
        l10n.agentWorkspaceProductionReviewSummary(review.summary),
    ];
    return lines.join('\n');
  }

  String _formatStoryboardTableRow(
    AppLocalizations l10n,
    Map<String, dynamic> row,
  ) {
    final id = _readNumericId(
      row['id'] ?? row['numeric_id'] ?? row['numericId'] ?? row['storyboardId'],
    );
    final scene = (row['scene'] as String?)?.trim() ?? '';
    final description = (row['description'] as String?)?.trim() ?? '';
    final duration = (row['duration'] as String?)?.trim() ?? '';
    final assetIds = extractProductionReferencedAssetIds(<String, dynamic>{
      'rows': <Map<String, dynamic>>[row],
    });
    final lines = <String>[
      if (id != null) l10n.agentWorkspaceProductionShotLabel(id),
      if (scene.isNotEmpty) l10n.agentWorkspaceProductionSceneLabel(scene),
      if (duration.isNotEmpty)
        l10n.agentWorkspaceProductionDurationLabel(duration),
      if (description.isNotEmpty) _previewText(description, maxChars: 180),
      if (assetIds.isNotEmpty)
        l10n.agentWorkspaceProductionAssetsLabel(assetIds.join(', ')),
    ];
    return lines.join('\n');
  }

  String _formatStoryboardRow(AppLocalizations l10n, Map<String, dynamic> row) {
    final id = _readNumericId(
      row['id'] ?? row['numeric_id'] ?? row['numericId'] ?? row['storyboardId'],
    );
    final state = (row['state'] as String?)?.trim() ?? '';
    final duration = switch (row['duration']) {
      String value => value.trim(),
      num value => value.toString(),
      _ => '',
    };
    final prompt = (row['prompt'] as String?)?.trim() ?? '';
    final assetIds = extractProductionReferencedAssetIds(<Map<String, dynamic>>[
      row,
    ]);
    final lines = <String>[
      if (id != null) l10n.agentWorkspaceProductionShotLabel(id),
      if (state.isNotEmpty) l10n.agentWorkspaceProductionStateLabel(state),
      if (duration.isNotEmpty)
        l10n.agentWorkspaceProductionDurationLabel(duration),
      if (!productionStoryboardEntryNeedsImageGeneration(row))
        l10n.agentWorkspaceProductionModeTextOnly,
      if (productionFlowEntryHasMediaResult(row))
        l10n.agentWorkspaceProductionResultHasImage
      else if (productionStoryboardEntryNeedsImageGeneration(row))
        l10n.agentWorkspaceProductionResultMissingImage(
          assetIds.isEmpty ? '—' : assetIds.join(', '),
        ),
      if (assetIds.isNotEmpty)
        l10n.agentWorkspaceProductionAssetsLabel(assetIds.join(', ')),
      if (prompt.isNotEmpty) _previewText(prompt, maxChars: 180),
    ];
    return lines.join('\n');
  }

  int? _readNumericId(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = workspaceLastToolResultData;
    final toolName = workspaceLastToolName?.trim();
    final suggestedFlowKey = workspaceSuggestedFlowKey?.trim();
    if (result is! Map<String, dynamic> ||
        toolName == null ||
        toolName.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context).textTheme;
    final sections = <Widget>[];

    void addPreviewCard({
      required String title,
      required Object body,
      String? flowKey,
      String? subtitle,
      Set<int> focusedStoryboardIds = const <int>{},
    }) {
      final normalized = _buildPreviewBody(
        l10n,
        body,
        flowKey: flowKey,
        focusedStoryboardIds: focusedStoryboardIds,
      ).trim();
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

    final data = result['data'];
    if (data is Map<String, dynamic>) {
      final focusedStoryboardIds = extractProductionStoryboardMissingImageIds(
        data['storyboard'],
      ).toSet();
      for (final key in <String>[
        'assets',
        'script',
        'scriptPlan',
        'storyboardTable',
        'storyboard',
      ]) {
        final value = data[key];
        if (value == null) continue;
        addPreviewCard(
          title: 'flow[$key]',
          flowKey: key,
          subtitle: l10n.agentWorkspaceProductionContextFromTool(toolName),
          body: value,
          focusedStoryboardIds: key == 'storyboardTable'
              ? focusedStoryboardIds
              : const <int>{},
        );
        if (key == 'scriptPlan') {
          final rewriteConstraintDigest = _scriptPlanRewriteConstraintDigest(
            l10n,
            value,
          );
          if (rewriteConstraintDigest.trim().isNotEmpty) {
            addPreviewCard(
              title: l10n.agentWorkspaceProductionContextDerivedRewrite,
              subtitle:
                  l10n.agentWorkspaceProductionContextDerivedRewriteSubtitle,
              body: rewriteConstraintDigest,
            );
          }
        }
      }
    } else if (toolName == 'get_flowData' &&
        data != null &&
        suggestedFlowKey != null &&
        suggestedFlowKey.isNotEmpty) {
      addPreviewCard(
        title: 'flow[$suggestedFlowKey]',
        flowKey: suggestedFlowKey,
        subtitle: l10n.agentWorkspaceProductionContextFromTool(toolName),
        body: data,
      );
      if (suggestedFlowKey == 'scriptPlan') {
        final rewriteConstraintDigest = _scriptPlanRewriteConstraintDigest(
          l10n,
          data,
        );
        if (rewriteConstraintDigest.trim().isNotEmpty) {
          addPreviewCard(
            title: l10n.agentWorkspaceProductionContextDerivedRewrite,
            subtitle:
                l10n.agentWorkspaceProductionContextDerivedRewriteSubtitle,
            body: rewriteConstraintDigest,
          );
        }
      }
    }

    final items = result['items'];
    if (items is List && items.isNotEmpty) {
      addPreviewCard(
        title: l10n.agentWorkspaceProductionContextReturnList(toolName),
        subtitle: l10n.agentWorkspaceProductionContextFromTool(toolName),
        body: items.take(6).toList(growable: false),
      );
    }

    final text = result['result'];
    if (text is String && text.trim().isNotEmpty) {
      addPreviewCard(
        title: l10n.agentWorkspaceProductionContextToolText,
        subtitle: l10n.agentWorkspaceProductionContextFromTool(toolName),
        body: text,
      );
    }

    final review = parseProductionSupervisionReview(result);
    if (review != null) {
      addPreviewCard(
        title: l10n.agentWorkspaceProductionContextReviewSummary(toolName),
        subtitle: l10n.agentWorkspaceProductionContextFromTool(toolName),
        body: _reviewDigest(l10n, review),
      );
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          l10n.agentWorkspaceProductionContextSnapshotTitle,
          style: theme.labelLarge,
        ),
        ...sections,
      ],
    );
  }
}
