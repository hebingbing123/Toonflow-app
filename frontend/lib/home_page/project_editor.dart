part of '../home_page.dart';

extension _HomePageProjectEditor on _HomePageState {
  Future<void> _openProjectDetail(ProjectRow p) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final nameCtrl = TextEditingController(text: p.name ?? '');
    final introCtrl = TextEditingController(text: p.intro ?? '');
    try {
      final detail = await fetchProjectByLegacyId(token, p.legacyId);
      if (!mounted) return;
      nameCtrl.text = detail.project.name ?? '';
      introCtrl.text = detail.project.intro ?? '';
      final scriptList = List<ScriptBrief>.from(detail.scripts);
      ProjectStats? statsSnap;
      try {
        statsSnap = await fetchProjectStatsByLegacyId(token, p.legacyId);
      } catch (_) {
        statsSnap = null;
      }
      ListAssetsResponse? assetsSnap;
      try {
        assetsSnap = await fetchProjectAssetsByLegacyId(token, p.legacyId);
      } catch (_) {
        assetsSnap = null;
      }
      ListNovelsResponse? novelsSnap;
      try {
        novelsSnap = await fetchProjectNovelsByLegacyId(token, p.legacyId);
      } catch (_) {
        novelsSnap = null;
      }
      if (!mounted) return;
      final statsRef = <ProjectStats?>[statsSnap];
      final assetsRef = <ListAssetsResponse?>[assetsSnap];
      final novelsRef = <ListNovelsResponse?>[novelsSnap];
      final assetsForScriptRef = <ListAssetsResponse?>[null];
      final assetsFilterScriptLegacyId = <int?>[null];
      final assetsLoading = <bool>[false];
      final assetsScriptFilterLoading = <bool>[false];
      final assetsBusy = <bool>[false];
      final novelsLoading = <bool>[false];
      final novelsBusy = <bool>[false];
      final scriptProbeBusy = <bool>[false];
      final generalLegacyBusy = <bool>[false];
      final tasksLegacyBusy = <bool>[false];
      final projectLegacyBusy = <bool>[false];
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              Future<void> reloadAssetsAndStats() async {
                try {
                  assetsRef[0] = await fetchProjectAssetsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  assetsRef[0] = null;
                }
                final sid = assetsFilterScriptLegacyId[0];
                if (sid != null) {
                  try {
                    assetsForScriptRef[0] = await fetchProjectAssetsByLegacyId(
                      token,
                      p.legacyId,
                      scriptLegacyId: sid,
                    );
                  } catch (_) {
                    assetsForScriptRef[0] = null;
                  }
                }
                try {
                  statsRef[0] = await fetchProjectStatsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {}
                try {
                  novelsRef[0] = await fetchProjectNovelsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  novelsRef[0] = null;
                }
                if (ctx.mounted) {
                  setDialogState(() {});
                }
              }

              return AlertDialog(
                title: Text(
                  detail.project.name ?? 'legacy #${detail.project.legacyId}',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: introCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Intro (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProjectLegacyProbeActions(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        detail: detail,
                        introCtrl: introCtrl,
                        generalLegacyBusy: generalLegacyBusy,
                        tasksLegacyBusy: tasksLegacyBusy,
                        projectLegacyBusy: projectLegacyBusy,
                      ),
                      const SizedBox(height: 12),
                      if (statsRef[0] != null)
                        Text(
                          'GET …/stats：剧本 ${statsRef[0]!.scriptCount} · 分镜 '
                          '${statsRef[0]!.storyboardCount} · 小说 ${statsRef[0]!.novelCount} · 角色/视频 '
                          '${statsRef[0]!.roleCount}/${statsRef[0]!.videoCount}（视频占位）',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/stats 未加载',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (novelsRef[0] != null)
                        Text(
                          novelsRef[0]!.items.isEmpty
                              ? 'GET …/novels：total=0'
                              : 'GET …/novels：total=${novelsRef[0]!.total} · ${novelsRef[0]!.items.take(4).map((n) => '#${n.legacyId}:${n.chapter}').join(', ')}${novelsRef[0]!.items.length > 4 ? '…' : ''}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/novels 未加载',
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
                                      setDialogState(
                                        () => novelsLoading[0] = false,
                                      );
                                    }
                                  }
                                },
                          child: Text(novelsLoading[0] ? '刷新小说…' : '刷新小说列表'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final ts =
                                          DateTime.now().millisecondsSinceEpoch;
                                      await createProjectNovelUnderLegacy(
                                        token,
                                        p.legacyId,
                                        chapter: 'novel_probe_$ts',
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 POST 测试章节'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST 测试章节'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final first = novelsRef[0]!.items.first;
                                    try {
                                      final row =
                                          await fetchProjectNovelByLegacyIds(
                                            token,
                                            p.legacyId,
                                            first.legacyId,
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/novels/${first.legacyId}：'
                                            '${row.chapter}',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 首条小说'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final pg =
                                          await fetchProjectNovelsByLegacyId(
                                            token,
                                            p.legacyId,
                                            search: 'novel',
                                            page: 1,
                                            limit: 5,
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/novels?search=novel&page=1&limit=5：'
                                            'total=${pg.total}，本页 ${pg.items.length} 条',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 小说 search+分页'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final first = novelsRef[0]!.items.first;
                                    try {
                                      await patchProjectNovelByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        {'chapter': '${first.chapter}·patched'},
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '已 PATCH 首条小说 chapter',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('PATCH 首条小说'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final last = novelsRef[0]!.items.last;
                                    try {
                                      await deleteProjectNovelByLegacyIds(
                                        token,
                                        p.legacyId,
                                        last.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已 DELETE 末条小说 #${last.legacyId}',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('DELETE 末条小说'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final pg = await postLegacyNovelsGetNovel(
                                        token,
                                        p.legacyId,
                                        page: 1,
                                        limit: 10,
                                      );
                                      if (!ctx.mounted) return;
                                      final first = pg.data.isNotEmpty
                                          ? pg.data.first
                                          : null;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            first != null
                                                ? 'POST …/novels/get-novel：total=${pg.total} · 首行 #${first.legacyId} ${first.chapter}'
                                                : 'POST …/novels/get-novel：total=${pg.total}',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST get-novel'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final rows =
                                          await postLegacyNovelsGetNovelData(
                                            token,
                                            p.legacyId,
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/novels/get-novel-data：${rows.length} 条',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST get-novel-data'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final idx =
                                          await postLegacyNovelsGetNovelIndex(
                                            token,
                                            p.legacyId,
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/novels/get-novel-index：'
                                            '${idx.length} 条',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST get-novel-index'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      final msg =
                                          await postLegacyNovelsAddNovel(
                                            token,
                                            p.legacyId,
                                            const [],
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/novels/add-novel 空 data：$msg',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST add-novel []'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      await postLegacyNovelsBatchDelete(
                                        token,
                                        const [],
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'POST …/novels/batch-delete：unexpected 200',
                                          ),
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST batch-delete []'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    try {
                                      await postLegacyNovelsDeleteNovel(
                                        token,
                                        0,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'POST …/novels/delete-novel：unexpected 200',
                                          ),
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST delete-novel id=0'),
                          ),
                          TextButton(
                            onPressed:
                                novelsBusy[0] ||
                                    novelsLoading[0] ||
                                    assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    novelsRef[0] == null ||
                                    novelsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => novelsBusy[0] = true);
                                    final n = novelsRef[0]!.items.first;
                                    try {
                                      final msg =
                                          await postLegacyNovelsUpdateNovel(
                                            token,
                                            id: n.legacyId,
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
                                            'POST …/novels/update-novel noop #${n.legacyId}：$msg',
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
                                        setDialogState(
                                          () => novelsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST update-novel (noop)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (assetsRef[0] != null)
                        Text(
                          assetsRef[0]!.items.isEmpty
                              ? 'GET …/assets：total=0'
                              : 'GET …/assets：total=${assetsRef[0]!.total} · ${assetsRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsRef[0]!.items.length > 6 ? '…' : ''}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/assets 未加载',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                        ),
                      if (assetsFilterScriptLegacyId[0] != null) ...[
                        const SizedBox(height: 6),
                        if (assetsScriptFilterLoading[0])
                          Text(
                            'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]} …',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          )
                        else if (assetsForScriptRef[0] != null)
                          Text(
                            assetsForScriptRef[0]!.items.isEmpty
                                ? 'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]}：total=0'
                                : 'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]}：total=${assetsForScriptRef[0]!.total} · ${assetsForScriptRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsForScriptRef[0]!.items.length > 6 ? '…' : ''}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          )
                        else
                          Text(
                            'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]} 未加载',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                      ],
                      if (scriptList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: DropdownButton<int?>(
                            value: assetsFilterScriptLegacyId[0],
                            isExpanded: true,
                            hint: const Text('按剧本筛选资产列表'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('（全部，不按剧本筛选）'),
                              ),
                              ...scriptList.map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.legacyId,
                                  child: Text(
                                    '#${s.legacyId} ${s.name ?? ""}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : (v) async {
                                    setDialogState(
                                      () => assetsScriptFilterLoading[0] = true,
                                    );
                                    assetsFilterScriptLegacyId[0] = v;
                                    if (v == null) {
                                      assetsForScriptRef[0] = null;
                                    }
                                    try {
                                      await reloadAssetsAndStats();
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsScriptFilterLoading[0] =
                                              false,
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed:
                              assetsLoading[0] || assetsScriptFilterLoading[0]
                              ? null
                              : () async {
                                  setDialogState(() => assetsLoading[0] = true);
                                  try {
                                    await reloadAssetsAndStats();
                                  } finally {
                                    if (ctx.mounted) {
                                      setDialogState(
                                        () => assetsLoading[0] = false,
                                      );
                                    }
                                  }
                                },
                          child: Text(assetsLoading[0] ? '刷新资产…' : '刷新资产列表'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final r =
                                          await fetchCornerScapeAssetsByLegacyId(
                                            token,
                                            p.legacyId,
                                          );
                                      Uint8List? cornerThumb;
                                      if (r.items.isNotEmpty &&
                                          r
                                              .items
                                              .first
                                              .historyImages
                                              .isNotEmpty) {
                                        final a = r.items.first;
                                        cornerThumb =
                                            await fetchCornerScapeHistoryImagePreviewBytes(
                                              token,
                                              p.legacyId,
                                              a.legacyId,
                                              a.historyImages.first,
                                            );
                                      }
                                      if (!ctx.mounted) return;
                                      final h0 = r.items.isEmpty
                                          ? 0
                                          : r.items.first.historyImages.length;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 6),
                                          content: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (cornerThumb != null) ...[
                                                SizedBox(
                                                  width: 56,
                                                  height: 56,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    child: Image.memory(
                                                      cornerThumb,
                                                      fit: BoxFit.cover,
                                                      gaplessPlayback: true,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  'POST …/assets/corner-scape：'
                                                  '${r.items.length} 条'
                                                  '${r.items.isEmpty ? "" : "，首条 history_images=$h0"}'
                                                  '${cornerThumb == null ? "" : "（预览）"}',
                                                ),
                                              ),
                                            ],
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST corner-scape'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      final ts =
                                          DateTime.now().millisecondsSinceEpoch;
                                      final row = await createProjectAssetImage(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        filePath: 'probe/hist_$ts.png',
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/assets/${first.legacyId}/images：'
                                            '${row.id.substring(0, 8)}…',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST 首条资产图片'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      final list =
                                          await fetchProjectAssetImagesByLegacyIds(
                                            token,
                                            p.legacyId,
                                            first.legacyId,
                                          );
                                      if (list.items.isEmpty) {
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'GET …/images：0 条，可先点「POST 首条资产图片」',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final img = list.items.first;
                                      final one =
                                          await fetchProjectAssetImageByLegacyIds(
                                            token,
                                            p.legacyId,
                                            first.legacyId,
                                            img.id,
                                          );
                                      var fileSuffix = '';
                                      try {
                                        final bytes =
                                            await fetchProjectAssetImageFileByLegacyIds(
                                              token,
                                              p.legacyId,
                                              first.legacyId,
                                              one.id,
                                            );
                                        fileSuffix = ' …/file ${bytes.length}B';
                                      } on RustApiException catch (fe) {
                                        fileSuffix =
                                            ' …/file ${fe.statusCode ?? "?"}';
                                      }
                                      if (!ctx.mounted) return;
                                      final idShort = one.id.length <= 8
                                          ? one.id
                                          : '${one.id.substring(0, 8)}…';
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/images/$idShort：'
                                            'sort=${one.sortIndex} '
                                            'state=${one.state ?? "-"}'
                                            '$fileSuffix',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 资产图片(单条)'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      final ts =
                                          DateTime.now().millisecondsSinceEpoch;
                                      final row = await createProjectAssetImage(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        filePath: 'probe/patch_del_$ts.png',
                                      );
                                      final patched =
                                          await patchProjectAssetImageByLegacyIds(
                                            token,
                                            p.legacyId,
                                            first.legacyId,
                                            row.id,
                                            {
                                              'state': '已完成',
                                              'sort_index': row.sortIndex + 1,
                                            },
                                          );
                                      await deleteProjectAssetImageByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        row.id,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST→PATCH→DEL 资产图片：'
                                            'sort ${row.sortIndex}→${patched.sortIndex} '
                                            'state=${patched.state ?? "-"} 已删',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST→PATCH→DEL 图'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final ts =
                                          DateTime.now().millisecondsSinceEpoch;
                                      await createProjectAssetUnderLegacy(
                                        token,
                                        p.legacyId,
                                        name: 'role_probe_$ts',
                                        type: 'role',
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 POST 测试资产'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST 测试资产'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      final row =
                                          await fetchProjectAssetByLegacyIds(
                                            token,
                                            p.legacyId,
                                            first.legacyId,
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets/${first.legacyId}：'
                                            '${row.name} (${row.assetType})',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 首条资产详情'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final page =
                                          await fetchProjectAssetsByLegacyId(
                                            token,
                                            p.legacyId,
                                            page: 1,
                                            limit: 2,
                                          );
                                      if (!ctx.mounted) return;
                                      final ids = page.items
                                          .map(
                                            (a) =>
                                                '#${a.legacyId}:${a.assetType}',
                                          )
                                          .join(', ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets?page=1&limit=2：'
                                            'total=${page.total}，本页 ${page.items.length} 条'
                                            '${ids.isEmpty ? '' : ' · $ids'}',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 分页 page=1&limit=2'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0]
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    try {
                                      final r =
                                          await fetchProjectAssetsByLegacyId(
                                            token,
                                            p.legacyId,
                                            assetType: 'role',
                                            name: 'probe',
                                          );
                                      if (!ctx.mounted) return;
                                      final ids = r.items
                                          .take(4)
                                          .map(
                                            (a) => '#${a.legacyId}:${a.name}',
                                          )
                                          .join(', ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets?asset_type=role&name=probe：'
                                            'total=${r.total}，返回 ${r.items.length} 条'
                                            '${ids.isEmpty ? '' : ' · $ids'}',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 筛选 type+name'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsFilterScriptLegacyId[0] == null
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final sid = assetsFilterScriptLegacyId[0]!;
                                    try {
                                      final pg =
                                          await fetchProjectAssetsByLegacyId(
                                            token,
                                            p.legacyId,
                                            scriptLegacyId: sid,
                                            page: 1,
                                            limit: 2,
                                          );
                                      if (!ctx.mounted) return;
                                      final ids = pg.items
                                          .map(
                                            (a) =>
                                                '#${a.legacyId}:${a.assetType}',
                                          )
                                          .join(', ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/assets?script_legacy_id=$sid'
                                            '&page=1&limit=2：total=${pg.total}，'
                                            '本页 ${pg.items.length} 条'
                                            '${ids.isEmpty ? '' : ' · $ids'}',
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
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('GET 当前剧本+分页'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final first = assetsRef[0]!.items.first;
                                    try {
                                      await patchProjectAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        first.legacyId,
                                        {'name': '${first.name}·patched'},
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 PATCH 首条资产名称'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('PATCH 首条'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final last = assetsRef[0]!.items.last;
                                    try {
                                      await deleteProjectAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        last.legacyId,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已 DELETE 资产 #${last.legacyId}',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('DELETE 末条'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    scriptList.isEmpty ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final sid = scriptList.first.legacyId;
                                    final aid =
                                        assetsRef[0]!.items.first.legacyId;
                                    try {
                                      await linkScriptToAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        sid,
                                        aid,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '已 PUT 关联 script#$sid · asset#$aid',
                                            ),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('PUT 关联首剧本·首资产'),
                          ),
                          TextButton(
                            onPressed:
                                assetsBusy[0] ||
                                    assetsLoading[0] ||
                                    assetsScriptFilterLoading[0] ||
                                    scriptList.isEmpty ||
                                    assetsRef[0] == null ||
                                    assetsRef[0]!.items.isEmpty
                                ? null
                                : () async {
                                    setDialogState(() => assetsBusy[0] = true);
                                    final sid = scriptList.first.legacyId;
                                    final aid =
                                        assetsRef[0]!.items.first.legacyId;
                                    try {
                                      await unlinkScriptFromAssetByLegacyIds(
                                        token,
                                        p.legacyId,
                                        sid,
                                        aid,
                                      );
                                      if (!ctx.mounted) return;
                                      await reloadAssetsAndStats();
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('已 DELETE 剧本–资产关联'),
                                          ),
                                        );
                                      }
                                    } on RustApiException catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text(e.toString())),
                                        );
                                      }
                                    } finally {
                                      if (ctx.mounted) {
                                        setDialogState(
                                          () => assetsBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('DELETE 取消关联'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${scriptList.length} script(s)'),
                      Wrap(
                        spacing: 4,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed: scriptProbeBusy[0] || saving[0]
                                ? null
                                : () async {
                                    setDialogState(
                                      () => scriptProbeBusy[0] = true,
                                    );
                                    try {
                                      final rows =
                                          await postScriptsGetScriptApi(
                                            token,
                                            p.legacyId,
                                          );
                                      if (!ctx.mounted) return;
                                      final sample = rows.isEmpty
                                          ? '0 条'
                                          : rows
                                                .take(2)
                                                .map(
                                                  (r) =>
                                                      '#${r.legacyId} rel=${r.relatedAssets.length}',
                                                )
                                                .join('; ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/scripts/get-script-api：'
                                            '${rows.length} 条 · $sample',
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
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: const Text('POST get-script-api'),
                          ),
                          TextButton(
                            onPressed:
                                scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(
                                      () => scriptProbeBusy[0] = true,
                                    );
                                    try {
                                      final sid = scriptList.first.legacyId;
                                      final row = await fetchScriptByLegacyId(
                                        token,
                                        sid,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GET …/scripts/legacy/$sid：'
                                            '${row.name ?? "(null)"}',
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
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'script…'
                                  : 'GET scripts/legacy (首条)',
                            ),
                          ),
                          TextButton(
                            onPressed:
                                scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(
                                      () => scriptProbeBusy[0] = true,
                                    );
                                    try {
                                      final sid = scriptList.first.legacyId;
                                      final cur = await fetchScriptByLegacyId(
                                        token,
                                        sid,
                                      );
                                      final patched =
                                          await updateScriptByLegacyId(
                                            token,
                                            sid,
                                            <String, dynamic>{
                                              'name': cur.name ?? '',
                                            },
                                          );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'PATCH …/scripts/legacy/$sid name noop → '
                                            '${patched.name ?? "(null)"}',
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
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'script…'
                                  : 'PATCH scripts/legacy (name noop)',
                            ),
                          ),
                          TextButton(
                            onPressed:
                                scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(
                                      () => scriptProbeBusy[0] = true,
                                    );
                                    try {
                                      final ids = scriptList
                                          .map((s) => s.legacyId)
                                          .toList();
                                      final zip = await exportScriptsZip(
                                        token,
                                        ids,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/scripts/export：${zip.length} bytes · '
                                            '${ids.length} legacy id(s)',
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
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'export…'
                                  : 'POST scripts/export (ZIP)',
                            ),
                          ),
                          TextButton(
                            onPressed:
                                scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(
                                      () => scriptProbeBusy[0] = true,
                                    );
                                    try {
                                      final ids = scriptList
                                          .map((s) => s.legacyId)
                                          .toList();
                                      final rows = await pollScriptExtractState(
                                        token,
                                        ids,
                                      );
                                      if (!ctx.mounted) return;
                                      final sample = rows.isEmpty
                                          ? '（empty：均在提取中或 idle）'
                                          : rows
                                                .take(3)
                                                .map(
                                                  (r) =>
                                                      '#${r.legacyId} state=${r.extractState}',
                                                )
                                                .join('; ');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/extract-state/poll：${rows.length} row(s) $sample',
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
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'poll…'
                                  : 'POST extract-state/poll',
                            ),
                          ),
                          TextButton(
                            onPressed:
                                scriptProbeBusy[0] ||
                                    scriptList.isEmpty ||
                                    saving[0]
                                ? null
                                : () async {
                                    setDialogState(
                                      () => scriptProbeBusy[0] = true,
                                    );
                                    try {
                                      final ids = scriptList
                                          .map((s) => s.legacyId)
                                          .toList();
                                      final acc = await startScriptAssetExtract(
                                        token,
                                        projectLegacyId: p.legacyId,
                                        scriptLegacyIds: ids,
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'POST …/extract-assets：${acc.status} — ${acc.message}',
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
                                        setDialogState(
                                          () => scriptProbeBusy[0] = false,
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              scriptProbeBusy[0]
                                  ? 'extract…'
                                  : 'POST extract-assets',
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: saving[0]
                              ? null
                              : () async {
                                  setDialogState(() => saving[0] = true);
                                  try {
                                    final s =
                                        await createScriptUnderProjectLegacy(
                                          token,
                                          p.legacyId,
                                        );
                                    if (!ctx.mounted) return;
                                    scriptList.add(
                                      ScriptBrief(
                                        legacyId: s.legacyId,
                                        name: s.name,
                                        extractState: s.extractState,
                                      ),
                                    );
                                    try {
                                      statsRef[0] =
                                          await fetchProjectStatsByLegacyId(
                                            token,
                                            p.legacyId,
                                          );
                                    } catch (_) {}
                                    if (!ctx.mounted) return;
                                    setDialogState(() => saving[0] = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '已创建剧本 legacy #${s.legacyId}',
                                        ),
                                      ),
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
                          child: const Text('POST 空剧本'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...scriptList.map(
                        (s) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '#${s.legacyId} ${s.name ?? ""}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: saving[0]
                              ? null
                              : () => _openScriptEditor(
                                  token,
                                  s.legacyId,
                                  onScriptTreeMutated: () async {
                                    final d = await fetchProjectByLegacyId(
                                      token,
                                      p.legacyId,
                                    );
                                    if (!ctx.mounted) return;
                                    scriptList
                                      ..clear()
                                      ..addAll(d.scripts);
                                    try {
                                      statsRef[0] =
                                          await fetchProjectStatsByLegacyId(
                                            token,
                                            p.legacyId,
                                          );
                                    } catch (_) {}
                                    setDialogState(() {});
                                  },
                                ),
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
                                title: const Text('删除项目？'),
                                content: Text(
                                  '将删除 legacy #${p.legacyId} 及关联剧本/分镜（数据库级联），且清除该项目的 agent 记忆。',
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
                              await deleteProjectByLegacyId(token, p.legacyId);
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              await _loadProjects();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('项目已删除')),
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
                            try {
                              await updateProjectByLegacyId(token, p.legacyId, {
                                'name': nameCtrl.text.isEmpty
                                    ? null
                                    : nameCtrl.text,
                                'intro': introCtrl.text.isEmpty
                                    ? null
                                    : introCtrl.text,
                              });
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              await _loadProjects();
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
      introCtrl.dispose();
    }
  }
}
