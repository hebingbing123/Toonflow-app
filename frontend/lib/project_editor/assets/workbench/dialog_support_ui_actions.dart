part of 'dialog_support.dart';

class _ProjectAssetsWorkbenchActions extends StatelessWidget {
  const _ProjectAssetsWorkbenchActions({
    required this.localBusy,
    required this.assetsBusy,
    required this.targetKind,
    required this.assets,
    required this.scriptList,
    required this.selectedScriptNumericId,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onFilter,
    required this.onLink,
    required this.onUnlink,
    required this.onReviewCandidates,
    required this.onUploadEditImage,
    required this.onUploadClip,
  });

  final bool localBusy;
  final bool assetsBusy;
  final ProjectStudioAssetEditorTargetKind targetKind;
  final List<AssetRow> assets;
  final List<ScriptBrief> scriptList;
  final int? selectedScriptNumericId;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFilter;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onReviewCandidates;
  final VoidCallback onUploadEditImage;
  final VoidCallback onUploadClip;

  _WorkbenchSuggestedAction? _resolveSuggestedAction(
    AppLocalizations l10n, {
    required bool canMutateAssets,
    required bool canLinkScripts,
  }) {
    switch (targetKind) {
      case ProjectStudioAssetEditorTargetKind.buildRoleLibrary:
      case ProjectStudioAssetEditorTargetKind.defineProjectCharacters:
        return _WorkbenchSuggestedAction(
          title: l10n.projectEditorAssetsWorkbenchSuggestedNextTitle,
          detail:
              l10n.projectEditorAssetsWorkbenchSuggestedNextBuildRoleLibrary,
          ctaLabel: l10n.projectEditorAssetsWorkbenchNewAsset,
          enabled: !(localBusy || assetsBusy),
          onPressed: onCreate,
        );
      case ProjectStudioAssetEditorTargetKind.anchorCharacters:
      case ProjectStudioAssetEditorTargetKind.reviewRoleReuse:
        return _WorkbenchSuggestedAction(
          title: l10n.projectEditorAssetsWorkbenchSuggestedNextTitle,
          detail:
              l10n.projectEditorAssetsWorkbenchSuggestedNextAnchorCharacters,
          ctaLabel: l10n.projectEditorAssetsWorkbenchLinkScript,
          enabled: canLinkScripts,
          onPressed: onLink,
        );
      case ProjectStudioAssetEditorTargetKind.confirmCandidates:
        return _WorkbenchSuggestedAction(
          title: l10n.projectEditorAssetsWorkbenchSuggestedNextTitle,
          detail:
              l10n.projectEditorAssetsWorkbenchSuggestedNextConfirmCandidates,
          ctaLabel: l10n.projectEditorAssetsWorkbenchReviewCandidates,
          enabled: canMutateAssets,
          onPressed: onReviewCandidates,
        );
      case ProjectStudioAssetEditorTargetKind.overview:
        return _WorkbenchSuggestedAction(
          title: l10n.projectEditorAssetsWorkbenchSuggestedNextTitle,
          detail: l10n.projectEditorAssetsWorkbenchSuggestedNextOverview,
          ctaLabel: l10n.projectEditorAssetsWorkbenchFilterAssets,
          enabled: canMutateAssets,
          onPressed: onFilter,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final canMutateAssets = !(localBusy || assetsBusy || assets.isEmpty);
    final canLinkScripts =
        !(localBusy ||
            assetsBusy ||
            assets.isEmpty ||
            scriptList.isEmpty ||
            selectedScriptNumericId == null);
    final suggested = _resolveSuggestedAction(
      l10n,
      canMutateAssets: canMutateAssets,
      canLinkScripts: canLinkScripts,
    );
    final canUploadEditImage = !(localBusy || assetsBusy || scriptList.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suggested != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggested.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        suggested.detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: StudioSpacing.sm),
                FilledButton(
                  style: studioFormPrimaryButtonStyle(context),
                  onPressed: suggested.enabled ? suggested.onPressed : null,
                  child: Text(suggested.ctaLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
        ],
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: localBusy || assetsBusy ? null : onCreate,
              child: Text(l10n.projectEditorAssetsWorkbenchNewAsset),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canMutateAssets ? onEdit : null,
              child: Text(l10n.projectEditorAssetsWorkbenchEditAsset),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canMutateAssets ? onDelete : null,
              child: Text(l10n.projectEditorAssetsWorkbenchDeleteAsset),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canMutateAssets ? onFilter : null,
              child: Text(l10n.projectEditorAssetsWorkbenchFilterAssets),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canLinkScripts ? onLink : null,
              child: Text(l10n.projectEditorAssetsWorkbenchLinkScript),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canLinkScripts ? onUnlink : null,
              child: Text(l10n.projectEditorAssetsWorkbenchUnlink),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canMutateAssets ? onReviewCandidates : null,
              child: Text(l10n.projectEditorAssetsWorkbenchReviewCandidates),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: canUploadEditImage ? onUploadEditImage : null,
              child: Text(l10n.projectEditorAssetsWorkbenchUploadEditImage),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: localBusy || assetsBusy ? null : onUploadClip,
              child: Text(l10n.projectEditorAssetsWorkbenchUploadClipAsset),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkbenchSuggestedAction {
  const _WorkbenchSuggestedAction({
    required this.title,
    required this.detail,
    required this.ctaLabel,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final String detail;
  final String ctaLabel;
  final bool enabled;
  final VoidCallback onPressed;
}
