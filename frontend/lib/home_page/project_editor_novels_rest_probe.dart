part of '../home_page.dart';

extension _HomePageProjectEditorNovelsRestProbe on _HomePageState {
  Widget _buildProjectRestNovelsSection({
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
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (novelsRef[0] != null)
          Text(
            novelsRef[0]!.items.isEmpty
                ? '当前没有小说章节'
                : '共 ${novelsRef[0]!.total} 条 · ${novelsRef[0]!.items.take(4).map((n) => '#${n.legacyId}:${n.chapter}').join(', ')}${novelsRef[0]!.items.length > 4 ? '…' : ''}',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            '小说列表尚未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed:
                novelsLoading[0] ||
                    assetsBusy[0] ||
                    assetsLoading[0] ||
                    assetsScriptFilterLoading[0]
                ? null
                : () async {
                    setDialogState(() => novelsLoading[0] = true);
                    try {
                      await reloadAssetsAndStats();
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => novelsLoading[0] = false);
                      }
                    }
                  },
            child: Text(novelsLoading[0] ? '刷新小说…' : '刷新小说'),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ..._buildProjectRestNovelsActions(
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
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
          ],
        ),
      ],
    );
  }
}
