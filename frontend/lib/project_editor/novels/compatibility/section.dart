// ignore_for_file: unused_element
part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelsProbe on _HomePageState {
  Widget _buildProjectNovelsCompatibilitySection({
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
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.projectEditorNovelsCompatibilitySectionTitle),
      subtitle: Text(
        l10n.projectEditorNovelsCompatibilitySectionSubtitle,
        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
          color: Theme.of(ctx).colorScheme.outline,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.projectEditorNovelsCompatibilitySectionProbeHint,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ..._buildProjectNovelsProbeActions(
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
        const SizedBox(height: 8),
        _buildProjectNovelEventsCompatibilitySection(
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
    );
  }
}
