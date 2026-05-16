part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesProbe on _HomePageState {
  Widget _buildProjectAssetsImagesCompatibilitySection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.projectEditorAssetsCompatibilityImagesSectionLabel,
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: _buildProjectAssetsImagesProbeActions(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            assetsRef: assetsRef,
            assetsLoading: assetsLoading,
            assetsScriptFilterLoading: assetsScriptFilterLoading,
            assetsBusy: assetsBusy,
            reloadAssetsAndStats: reloadAssetsAndStats,
          ),
        ),
      ],
    );
  }
}
