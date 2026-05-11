part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelsProbeMutationActions on _HomePageState {
  List<Widget> _buildProjectNovelsProbeMutationActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsBusy,
    required bool disabled,
  }) {
    return [
      TextButton(
        onPressed: disabled || novelsRef[0] == null || novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final ids = novelsRef[0]!.items.map((e) => e.numericId).toList();
                  final msg = await postNovelEventsGenerateEvents(
                    token,
                    projectNumericId: p.numericId,
                    projectUuid: p.id,
                    novelIds: ids.take(3).toList(),
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('POST …/novel-events/generate-events：$msg'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST events/generate-events'),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final msg = await appendNovelsUnderProject(
                    token,
                    p.numericId,
                    const [],
                    projectUuid: p.id,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('POST …/novels/add-novel 空 data：$msg')),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST add-novel []'),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  await batchDeleteNovelsUnderProject(token, p.id, const []);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('POST …/novels/batch-delete：unexpected 200'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (!ctx.mounted) return;
                  if (e.statusCode == 400) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'POST …/novels/batch-delete [] -> 400 (expected)',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST batch-delete []'),
      ),
      TextButton(
        onPressed: disabled
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  await deleteNovelByNumericIdScanningProjects(
                    token,
                    0,
                    projectUuid: p.id,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('POST …/novels/delete-novel：unexpected 200'),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (!ctx.mounted) return;
                  if (e.statusCode == 400) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'POST …/novels/delete-novel id=0 -> 400 (expected)',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST delete-novel id=0'),
      ),
      TextButton(
        onPressed: disabled || novelsRef[0] == null || novelsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                final n = novelsRef[0]!.items.first;
                try {
                  final msg = await updateNovelScanningProjects(
                    token,
                    id: n.numericId,
                    projectUuid: p.id,
                    index: n.chapterIndex,
                    reel: n.reel ?? '',
                    chapter: n.chapter,
                    chapterData: n.chapterData,
                    event: n.event ?? '',
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/novels/update-novel noop #${n.numericId}：$msg',
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                }
              },
        child: const Text('POST update-novel (noop)'),
      ),
    ];
  }
}
