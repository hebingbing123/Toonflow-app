part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelEventsProbe on _HomePageState {
  Widget _buildProjectNovelEventsCompatibilitySection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<ListNovelEventsResponse?> novelEventsRef,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> novelEventsLoading,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(ctx)!.projectEditorNovelEventsRegressionProbeCaption,
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ..._buildProjectNovelEventsCompatibilityActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              novelsRef: novelsRef,
              novelEventsRef: novelEventsRef,
              novelsLoading: novelsLoading,
              novelsBusy: novelsBusy,
              novelEventsLoading: novelEventsLoading,
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
