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
                      _buildProjectNovelProbeSection(
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
                      const SizedBox(height: 12),
                      _buildProjectAssetsProbeSection(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        scriptList: scriptList,
                        assetsRef: assetsRef,
                        assetsForScriptRef: assetsForScriptRef,
                        assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
                        assetsLoading: assetsLoading,
                        assetsScriptFilterLoading: assetsScriptFilterLoading,
                        assetsBusy: assetsBusy,
                        reloadAssetsAndStats: reloadAssetsAndStats,
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
