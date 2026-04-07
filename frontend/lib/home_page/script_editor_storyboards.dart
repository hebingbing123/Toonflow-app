part of '../home_page.dart';

extension _HomePageScriptEditorStoryboards on _HomePageState {
  Future<void> _openScriptStoryboardsDialog({
    required String token,
    required int scriptLegacyId,
  }) async {
    try {
      final boards = await fetchStoryboardsForScript(token, scriptLegacyId);
      if (!mounted) return;
      final boardsList = List<StoryboardRow>.from(boards);
      await showDialog<void>(
        context: context,
        builder: (ctx2) {
          final creatingSb = <bool>[false];
          final sbProbeBusy = <bool>[false];
          return StatefulBuilder(
            builder: (ctx2, setBoardsState) {
              return AlertDialog(
                title: Text('分镜 (${boardsList.length})'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: boardsList.length,
                        itemBuilder: (_, i) {
                          final b = boardsList[i];
                          return ListTile(
                            title: Text('#${b.legacyId} ${b.state ?? ""}'),
                            subtitle: Text(
                              b.prompt ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: creatingSb[0]
                                ? null
                                : () async {
                                    await _openStoryboardEditor(
                                      token,
                                      b.legacyId,
                                      onStoryboardTreeMutated: () async {
                                        final fresh =
                                            await fetchStoryboardsForScript(
                                              token,
                                              scriptLegacyId,
                                            );
                                        if (!ctx2.mounted) return;
                                        boardsList
                                          ..clear()
                                          ..addAll(fresh);
                                        setBoardsState(() {});
                                      },
                                    );
                                  },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            TextButton(
                              onPressed:
                                  sbProbeBusy[0] ||
                                      creatingSb[0] ||
                                      boardsList.isEmpty
                                  ? null
                                  : () async {
                                      sbProbeBusy[0] = true;
                                      setBoardsState(() {});
                                      try {
                                        final sid = boardsList.first.legacyId;
                                        final row = await fetchStoryboardByLegacyId(
                                          token,
                                          sid,
                                        );
                                        if (!ctx2.mounted) return;
                                        ScaffoldMessenger.of(ctx2).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'GET …/storyboards/legacy/$sid：state=${row.state ?? "(null)"}',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx2.mounted) {
                                          ScaffoldMessenger.of(ctx2).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx2.mounted) {
                                          ScaffoldMessenger.of(ctx2).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        sbProbeBusy[0] = false;
                                        if (ctx2.mounted) {
                                          setBoardsState(() {});
                                        }
                                      }
                                    },
                              child: Text(
                                sbProbeBusy[0]
                                    ? '…'
                                    : 'GET storyboard/legacy (首条)',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  sbProbeBusy[0] ||
                                      creatingSb[0] ||
                                      boardsList.isEmpty
                                  ? null
                                  : () async {
                                      sbProbeBusy[0] = true;
                                      setBoardsState(() {});
                                      try {
                                        final first = boardsList.first;
                                        final patched =
                                            await updateStoryboardByLegacyId(
                                              token,
                                              first.legacyId,
                                              <String, dynamic>{
                                                'state': first.state ?? '',
                                              },
                                            );
                                        if (!ctx2.mounted) return;
                                        ScaffoldMessenger.of(ctx2).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'PATCH …/storyboards/legacy/${first.legacyId} state noop → ok (legacy #${patched.legacyId})',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx2.mounted) {
                                          ScaffoldMessenger.of(ctx2).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (ctx2.mounted) {
                                          ScaffoldMessenger.of(ctx2).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        sbProbeBusy[0] = false;
                                        if (ctx2.mounted) {
                                          setBoardsState(() {});
                                        }
                                      }
                                    },
                              child: Text(
                                sbProbeBusy[0]
                                    ? '…'
                                    : 'PATCH storyboard/legacy (state noop)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: creatingSb[0]
                        ? null
                        : () async {
                            creatingSb[0] = true;
                            setBoardsState(() {});
                            try {
                              final row = await createStoryboardUnderScriptLegacy(
                                token,
                                scriptLegacyId,
                              );
                              if (ctx2.mounted) {
                                boardsList.add(row);
                                ScaffoldMessenger.of(ctx2).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '已创建分镜 legacy #${row.legacyId}',
                                    ),
                                  ),
                                );
                              }
                            } on RustApiException catch (e) {
                              if (ctx2.mounted) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx2.mounted) {
                                ScaffoldMessenger.of(ctx2).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } finally {
                              creatingSb[0] = false;
                              if (ctx2.mounted) {
                                setBoardsState(() {});
                              }
                            }
                          },
                    child: Text(creatingSb[0] ? '创建中…' : 'POST 空分镜'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx2).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
