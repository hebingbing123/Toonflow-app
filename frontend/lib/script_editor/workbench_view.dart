import 'package:flutter/material.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_workbench_section.dart';
import '../design_system/tokens.dart';
import '../rust_api.dart';
import 'support.dart';

class ScriptWorkbenchPanelViewModel {
  const ScriptWorkbenchPanelViewModel({
    required this.contextLine,
    required this.loadingContext,
    required this.runningAction,
    required this.scriptContext,
    required this.extractStateRow,
    required this.exportLine,
    required this.extractStateLine,
    required this.extractAssetsLine,
    required this.diagnosis,
    required this.relatedAssets,
    required this.errorReason,
    required this.recommendedActionLabel,
    required this.recommendedAction,
  });

  final String? contextLine;
  final bool loadingContext;
  final bool runningAction;
  final ScriptWorkbenchDetailRow? scriptContext;
  final ScriptExtractStatePollRow? extractStateRow;
  final String? exportLine;
  final String? extractStateLine;
  final String? extractAssetsLine;
  final ScriptWorkbenchDiagnosis diagnosis;
  final List<ScriptRelatedAssetBrief> relatedAssets;
  final String errorReason;
  final String recommendedActionLabel;
  final VoidCallback? recommendedAction;
}

class ScriptWorkbenchPanelViewCallbacks {
  const ScriptWorkbenchPanelViewCallbacks({
    required this.onRefreshWorkbench,
    required this.onExportCurrentScript,
    required this.onPollExtractState,
    required this.onStartExtractAssets,
    required this.onOpenEditImageWorkbench,
  });

  final VoidCallback? onRefreshWorkbench;
  final VoidCallback? onExportCurrentScript;
  final VoidCallback? onPollExtractState;
  final VoidCallback? onStartExtractAssets;
  final VoidCallback? onOpenEditImageWorkbench;
}

/// 脚本工作台视图，承载建议卡片、状态摘要与动作入口布局。
class ScriptWorkbenchPanelView extends StatelessWidget {
  const ScriptWorkbenchPanelView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ScriptWorkbenchPanelViewModel model;
  final ScriptWorkbenchPanelViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      decoration: studioInsetPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.scriptEditorWorkbenchPanelTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: callbacks.onRefreshWorkbench,
                child: Text(
                  model.loadingContext
                      ? l10n.projectEditorScriptsSingleWorkbenchSyncBusy
                      : l10n.projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench,
                ),
              ),
            ],
          ),
          Text(
            model.contextLine ?? l10n.scriptEditorWorkbenchPanelIntro,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.listItem),
          StudioWorkbenchSection(
            title: model.diagnosis.summary,
            subtitle: model.diagnosis.detail,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
              decoration: studioRecessedPanelDecoration(context),
              child: FilledButton.tonal(
                onPressed: model.recommendedAction,
                child: Text(model.recommendedActionLabel),
              ),
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.listItem),
          if (model.loadingContext)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            Text(
              model.scriptContext == null
                  ? l10n.projectEditorScriptsDiagnosisSingleNoSnapshotSummary
                  : l10n.scriptEditorWorkbenchRelatedAssetsLine(
                      summarizeRelatedScriptAssets(l10n, model.relatedAssets),
                    ),
              style: theme.textTheme.bodySmall,
            ),
            if (model.scriptContext != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.projectEditorScriptsExtractStateLine(
                  model.scriptContext?.extractState ?? 0,
                  model.errorReason.isEmpty
                      ? ''
                      : ' · ${model.errorReason}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: model.errorReason.isEmpty
                      ? tokens.textMuted
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: callbacks.onExportCurrentScript,
                child: Text(l10n.projectEditorScriptsSingleWorkbenchRecommendExportScriptZip),
              ),
              TextButton(
                onPressed: callbacks.onPollExtractState,
                child: Text(l10n.projectEditorScriptsSingleWorkbenchRecommendPollExtractState),
              ),
              TextButton(
                onPressed: callbacks.onStartExtractAssets,
                child: Text(l10n.projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets),
              ),
              TextButton(
                onPressed: callbacks.onOpenEditImageWorkbench,
                child: Text(l10n.projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench),
              ),
            ],
          ),
          if (model.exportLine != null) ...[
            const SizedBox(height: 8),
            Text(model.exportLine!, style: theme.textTheme.bodySmall),
          ],
          if (model.extractStateLine != null) ...[
            const SizedBox(height: 8),
            Text(model.extractStateLine!, style: theme.textTheme.bodySmall),
          ],
          if (model.extractAssetsLine != null) ...[
            const SizedBox(height: 8),
            Text(model.extractAssetsLine!, style: theme.textTheme.bodySmall),
          ],
          if (model.extractStateRow != null &&
              (model.extractStateRow!.errorReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.projectEditorScriptsSingleWorkbenchRecentExtractError(
                model.extractStateRow!.errorReason!.trim(),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
