part of '../home_page.dart';

extension _HomePageProjectEditorNovelsLegacyProbe on _HomePageState {
  Widget _buildProjectLegacyNovelsProbeSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Legacy POST …/novels/*（Electron 形）',
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ..._buildProjectLegacyNovelsProbeActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              novelsRef: novelsRef,
              novelsLoading: novelsLoading,
              novelsBusy: novelsBusy,
              assetsBusy: assetsBusy,
              assetsLoading: assetsLoading,
              assetsScriptFilterLoading: assetsScriptFilterLoading,
            ),
          ],
        ),
      ],
    );
  }
}
