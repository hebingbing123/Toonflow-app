part of '../home_page.dart';

extension _HomePageProjectEditorNovelEventsProbe on _HomePageState {
  Widget _buildProjectNovelEventsSection({
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
        if (novelEventsRef[0] != null)
          Text(
            novelEventsRef[0]!.items.isEmpty
                ? '当前没有小说事件'
                : '事件 ${novelEventsRef[0]!.total} 条 · ${novelEventsRef[0]!.items.take(3).map((e) => '#${e.legacyId}:${e.name}').join(', ')}${novelEventsRef[0]!.items.length > 3 ? '…' : ''}',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            '事件列表尚未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed:
                novelsBusy[0] ||
                    novelsLoading[0] ||
                    novelEventsLoading[0] ||
                    assetsBusy[0] ||
                    assetsLoading[0] ||
                    assetsScriptFilterLoading[0]
                ? null
                : () async {
                    setDialogState(() => novelEventsLoading[0] = true);
                    try {
                      novelEventsRef[0] =
                          await fetchProjectNovelEventsByLegacyId(
                            token,
                            p.legacyId,
                          );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => novelEventsLoading[0] = false);
                      }
                    }
                  },
            child: Text(novelEventsLoading[0] ? '刷新事件…' : '刷新事件'),
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ..._buildProjectNovelEventsActions(
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
          'Legacy / event regression checks',
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
