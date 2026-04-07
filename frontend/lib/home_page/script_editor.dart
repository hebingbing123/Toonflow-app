part of '../home_page.dart';

extension _HomePageScriptEditor on _HomePageState {
  Future<void> _openScriptEditor(
    String token,
    int scriptLegacyId, {
    Future<void> Function()? onScriptTreeMutated,
  }) async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    try {
      final script = await fetchScriptByLegacyId(token, scriptLegacyId);
      if (!mounted) return;
      nameCtrl.text = script.name ?? '';
      contentCtrl.text = script.content ?? '';
      stateCtrl.text = script.extractState?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Script #${script.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentCtrl,
                        minLines: 4,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Content (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'extract_state (empty = clear)',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: saving[0]
                              ? null
                              : () async {
                                  try {
                                    final boards =
                                        await fetchStoryboardsForScript(
                                          token,
                                          scriptLegacyId,
                                        );
                                    if (!mounted) return;
                                    final boardsList = List<StoryboardRow>.from(
                                      boards,
                                    );
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx2) {
                                        final creatingSb = <bool>[false];
                                        final sbProbeBusy = <bool>[false];
                                        return StatefulBuilder(
                                          builder: (ctx2, setBoardsState) {
                                            return AlertDialog(
                                              title: Text(
                                                '分镜 (${boardsList.length})',
                                              ),
                                              content: SizedBox(
                                                width: double.maxFinite,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    ListView.builder(
                                                      shrinkWrap: true,
                                                      physics:
                                                          const NeverScrollableScrollPhysics(),
                                                      itemCount:
                                                          boardsList.length,
                                                      itemBuilder: (_, i) {
                                                        final b = boardsList[i];
                                                        return ListTile(
                                                          title: Text(
                                                            '#${b.legacyId} ${b.state ?? ""}',
                                                          ),
                                                          subtitle: Text(
                                                            b.prompt ?? '',
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
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
                                                                      if (!ctx2
                                                                          .mounted) {
                                                                        return;
                                                                      }
                                                                      boardsList
                                                                        ..clear()
                                                                        ..addAll(
                                                                          fresh,
                                                                        );
                                                                      setBoardsState(
                                                                        () {},
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Wrap(
                                                        spacing: 4,
                                                        runSpacing: 4,
                                                        children: [
                                                          TextButton(
                                                            onPressed:
                                                                sbProbeBusy[0] ||
                                                                    creatingSb[0] ||
                                                                    boardsList
                                                                        .isEmpty
                                                                ? null
                                                                : () async {
                                                                    sbProbeBusy[0] =
                                                                        true;
                                                                    setBoardsState(
                                                                      () {},
                                                                    );
                                                                    try {
                                                                      final sid = boardsList
                                                                          .first
                                                                          .legacyId;
                                                                      final row =
                                                                          await fetchStoryboardByLegacyId(
                                                                            token,
                                                                            sid,
                                                                          );
                                                                      if (!ctx2
                                                                          .mounted) {
                                                                        return;
                                                                      }
                                                                      ScaffoldMessenger.of(
                                                                        ctx2,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text(
                                                                            'GET …/storyboards/legacy/$sid：state=${row.state ?? "(null)"}',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    } on RustApiException catch (
                                                                      e
                                                                    ) {
                                                                      if (ctx2
                                                                          .mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          ctx2,
                                                                        ).showSnackBar(
                                                                          SnackBar(
                                                                            content: Text(
                                                                              e.toString(),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      if (ctx2
                                                                          .mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          ctx2,
                                                                        ).showSnackBar(
                                                                          SnackBar(
                                                                            content: Text(
                                                                              e.toString(),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    } finally {
                                                                      sbProbeBusy[0] =
                                                                          false;
                                                                      if (ctx2
                                                                          .mounted) {
                                                                        setBoardsState(
                                                                          () {},
                                                                        );
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
                                                                    boardsList
                                                                        .isEmpty
                                                                ? null
                                                                : () async {
                                                                    sbProbeBusy[0] =
                                                                        true;
                                                                    setBoardsState(
                                                                      () {},
                                                                    );
                                                                    try {
                                                                      final first =
                                                                          boardsList
                                                                              .first;
                                                                      final patched = await updateStoryboardByLegacyId(
                                                                        token,
                                                                        first
                                                                            .legacyId,
                                                                        <
                                                                          String,
                                                                          dynamic
                                                                        >{
                                                                          'state':
                                                                              first.state ??
                                                                              '',
                                                                        },
                                                                      );
                                                                      if (!ctx2
                                                                          .mounted) {
                                                                        return;
                                                                      }
                                                                      ScaffoldMessenger.of(
                                                                        ctx2,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text(
                                                                            'PATCH …/storyboards/legacy/${first.legacyId} state noop → ok (legacy #${patched.legacyId})',
                                                                          ),
                                                                        ),
                                                                      );
                                                                    } on RustApiException catch (
                                                                      e
                                                                    ) {
                                                                      if (ctx2
                                                                          .mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          ctx2,
                                                                        ).showSnackBar(
                                                                          SnackBar(
                                                                            content: Text(
                                                                              e.toString(),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      if (ctx2
                                                                          .mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          ctx2,
                                                                        ).showSnackBar(
                                                                          SnackBar(
                                                                            content: Text(
                                                                              e.toString(),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      }
                                                                    } finally {
                                                                      sbProbeBusy[0] =
                                                                          false;
                                                                      if (ctx2
                                                                          .mounted) {
                                                                        setBoardsState(
                                                                          () {},
                                                                        );
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
                                                            final row =
                                                                await createStoryboardUnderScriptLegacy(
                                                                  token,
                                                                  scriptLegacyId,
                                                                );
                                                            if (ctx2.mounted) {
                                                              boardsList.add(
                                                                row,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                ctx2,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '已创建分镜 legacy #${row.legacyId}',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } on RustApiException catch (
                                                            e
                                                          ) {
                                                            if (ctx2.mounted) {
                                                              ScaffoldMessenger.of(
                                                                ctx2,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    e.toString(),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (ctx2.mounted) {
                                                              ScaffoldMessenger.of(
                                                                ctx2,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    e.toString(),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } finally {
                                                            creatingSb[0] =
                                                                false;
                                                            if (ctx2.mounted) {
                                                              setBoardsState(
                                                                () {},
                                                              );
                                                            }
                                                          }
                                                        },
                                                  child: Text(
                                                    creatingSb[0]
                                                        ? '创建中…'
                                                        : 'POST 空分镜',
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx2).pop(),
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
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                          child: const Text('分镜列表…'),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('删除剧本？'),
                                content: Text(
                                  '将删除 script #${script.legacyId} 及其分镜（数据库级联）。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(c).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(c).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteScriptByLegacyId(
                                token,
                                scriptLegacyId,
                              );
                              if (!ctx.mounted) return;
                              await onScriptTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('剧本已删除')),
                              );
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: const Text('DELETE'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? extractParsed;
                            final st = stateCtrl.text.trim();
                            if (st.isNotEmpty) {
                              extractParsed = int.tryParse(st);
                              if (extractParsed == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('extract_state 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateScriptByLegacyId(
                                token,
                                scriptLegacyId,
                                {
                                  'name': nameCtrl.text.isEmpty
                                      ? null
                                      : nameCtrl.text,
                                  'content': contentCtrl.text.isEmpty
                                      ? null
                                      : contentCtrl.text,
                                  'extract_state': st.isEmpty
                                      ? null
                                      : extractParsed,
                                },
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } finally {
      nameCtrl.dispose();
      contentCtrl.dispose();
      stateCtrl.dispose();
    }
  }
}
