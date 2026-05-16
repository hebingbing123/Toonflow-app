part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelsActions on _HomePageState {
  bool _novelsProbeDisabled({
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
  }) {
    return novelsBusy[0] ||
        novelsLoading[0] ||
        assetsBusy[0] ||
        assetsLoading[0] ||
        assetsScriptFilterLoading[0];
  }

  List<Widget> _buildProjectNovelsProbeActions({
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
    final disabled = _novelsProbeDisabled(
      novelsLoading: novelsLoading,
      novelsBusy: novelsBusy,
      assetsBusy: assetsBusy,
      assetsLoading: assetsLoading,
      assetsScriptFilterLoading: assetsScriptFilterLoading,
    );
    return [
      ..._buildProjectNovelsProbeReadActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        novelsRef: novelsRef,
        novelsBusy: novelsBusy,
        disabled: disabled,
      ),
      ..._buildProjectNovelsProbeMutationActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        novelsRef: novelsRef,
        novelsBusy: novelsBusy,
        disabled: disabled,
      ),
    ];
  }
}
