import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import 'support.dart';

class ProjectAssetsOverviewViewModel {
  const ProjectAssetsOverviewViewModel({
    required this.scriptList,
    required this.visibleAssets,
    required this.assetsForScript,
    required this.filterScriptNumericId,
    required this.assetsLoading,
    required this.assetsScriptFilterLoading,
    required this.assetsBusy,
  });

  final List<ScriptBrief> scriptList;
  final List<AssetRow> visibleAssets;
  final List<AssetRow>? assetsForScript;
  final int? filterScriptNumericId;
  final bool assetsLoading;
  final bool assetsScriptFilterLoading;
  final bool assetsBusy;
}

class ProjectAssetsOverviewViewCallbacks {
  const ProjectAssetsOverviewViewCallbacks({
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onOpenWorkbench,
  });

  final ValueChanged<int?>? onFilterChanged;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenWorkbench;
}

/// Renders the assets overview, script filter, and workbench entry actions.
class ProjectAssetsOverviewView extends StatelessWidget {
  const ProjectAssetsOverviewView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectAssetsOverviewViewModel model;
  final ProjectAssetsOverviewViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bodySmall = theme.textTheme.bodySmall;
    final outline = theme.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summarizeProjectAssetRows(model.visibleAssets), style: bodySmall),
        if (model.filterScriptNumericId != null) ...[
          const SizedBox(height: 6),
          if (model.assetsScriptFilterLoading)
            Text(
              l10n.projectEditorAssetsOverviewFilteringByScript,
              style: bodySmall?.copyWith(color: outline),
            )
          else if (model.assetsForScript != null)
            Text(
              summarizeScriptScopedAssets(
                model.filterScriptNumericId,
                model.assetsForScript!,
              ),
              style: bodySmall,
            )
          else
            Text(
              l10n.projectEditorAssetsOverviewScriptAssetsNotLoaded,
              style: bodySmall?.copyWith(color: outline),
            ),
        ],
        if (model.scriptList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButton<int?>(
              value: model.filterScriptNumericId,
              isExpanded: true,
              hint: Text(l10n.projectEditorAssetsOverviewFilterHint),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.projectEditorAssetsOverviewFilterOptionAll),
                ),
                ...model.scriptList.map(
                  (script) => DropdownMenuItem<int?>(
                    value: script.numericId,
                    child: Text(
                      '#${script.numericId} ${script.name ?? ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged:
                  model.assetsBusy ||
                      model.assetsLoading ||
                      model.assetsScriptFilterLoading ||
                      callbacks.onFilterChanged == null
                  ? null
                  : (value) => callbacks.onFilterChanged!(value),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed:
                    model.assetsLoading ||
                        model.assetsScriptFilterLoading ||
                        callbacks.onRefresh == null
                ? null
                : () => callbacks.onRefresh!(),
            child: Text(
              model.assetsLoading
                  ? l10n.projectEditorAssetsOverviewRefreshBusy
                  : l10n.projectEditorAssetsOverviewRefresh,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.projectEditorAssetsMainWorkbenchTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                l10n.projectEditorAssetsOverviewCardIntro,
                style: bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed:
                    model.assetsBusy ||
                        model.assetsLoading ||
                        model.assetsScriptFilterLoading
                    ? null
                    : callbacks.onOpenWorkbench,
                child: Text(l10n.projectEditorAssetsOverviewOpenMainWorkbench),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
