part of '../home_page.dart';

extension _HomePageEditors on _HomePageState {
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
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 0,
                          children: [
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => generalLegacyBusy[0] = true,
                                      );
                                      try {
                                        final rows =
                                            await postGeneralGetSingleProject(
                                              token,
                                              p.legacyId,
                                            );
                                        if (!ctx.mounted) return;
                                        final line = rows.isEmpty
                                            ? '0 行'
                                            : rows
                                                  .map(
                                                    (r) =>
                                                        '#${r.legacyId} ${r.name ?? ""}',
                                                  )
                                                  .join('; ');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/general/get-single-project：$line',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => generalLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                generalLegacyBusy[0]
                                    ? 'general…'
                                    : 'POST general get-single-project',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => generalLegacyBusy[0] = true,
                                      );
                                      try {
                                        final origIntro = introCtrl.text;
                                        final probeIntro = origIntro.isEmpty
                                            ? '[flutter general probe]'
                                            : '$origIntro [flutter general probe]';
                                        final msg1 =
                                            await postGeneralUpdateProject(
                                              token,
                                              <String, dynamic>{
                                                'id': p.legacyId,
                                                'intro': probeIntro,
                                              },
                                            );
                                        final restoreBody = <String, dynamic>{
                                          'id': p.legacyId,
                                          if (origIntro.isEmpty)
                                            'intro': null
                                          else
                                            'intro': origIntro,
                                        };
                                        final msg2 =
                                            await postGeneralUpdateProject(
                                              token,
                                              restoreBody,
                                            );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/general/update-project：$msg1 → restored ($msg2)',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => generalLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                generalLegacyBusy[0]
                                    ? 'general…'
                                    : 'POST general update-project',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => generalLegacyBusy[0] = true,
                                      );
                                      final pr = detail.project;
                                      try {
                                        final updated =
                                            await updateProjectByLegacyId(
                                              token,
                                              p.legacyId,
                                              <String, dynamic>{
                                                'name': pr.name ?? '',
                                              },
                                            );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'PATCH …/projects/legacy/${p.legacyId} '
                                              'name noop → ${updated.name ?? "(null)"}',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => generalLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                generalLegacyBusy[0]
                                    ? 'general…'
                                    : 'PATCH projects/legacy (name noop)',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => projectLegacyBusy[0] = true,
                                      );
                                      try {
                                        final rows =
                                            await postProjectGetProject(token);
                                        if (!ctx.mounted) return;
                                        final line = rows.isEmpty
                                            ? '0 项'
                                            : rows
                                                  .map(
                                                    (r) =>
                                                        '#${r.legacyId} ${r.name ?? ""}',
                                                  )
                                                  .join('; ');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/project/get-project：$line',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => projectLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                projectLegacyBusy[0]
                                    ? 'project…'
                                    : 'POST project get-project',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => projectLegacyBusy[0] = true,
                                      );
                                      final pr = detail.project;
                                      try {
                                        final msg =
                                            await postProjectEditProject(
                                              token,
                                              id: pr.legacyId,
                                              name: pr.name ?? '',
                                              intro: pr.intro ?? '',
                                              type: pr.mode ?? '',
                                              artStyle: pr.artStyle ?? '',
                                              directorManual:
                                                  pr.directorManual ?? '',
                                              videoRatio: pr.videoRatio ?? '',
                                              imageModel: pr.imageModel ?? '',
                                              videoModel: pr.videoModel ?? '',
                                              imageQuality:
                                                  pr.imageQuality ?? '',
                                              projectType: pr.projectType ?? '',
                                              mode: pr.mode ?? '',
                                            );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/project/edit-project noop #${pr.legacyId}：$msg',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => projectLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                projectLegacyBusy[0]
                                    ? 'project…'
                                    : 'POST project edit (noop)',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => projectLegacyBusy[0] = true,
                                      );
                                      try {
                                        await postProjectDeleteProject(
                                          token,
                                          0,
                                        );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'POST …/project/delete-project：unexpected 200',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (!ctx.mounted) return;
                                        if (e.statusCode == 400) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'POST …/project/delete-project id=0 -> 400 (expected)',
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => projectLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                projectLegacyBusy[0]
                                    ? 'project…'
                                    : 'POST project delete id=0',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => projectLegacyBusy[0] = true,
                                      );
                                      try {
                                        await postProjectEditProject(
                                          token,
                                          id: 0,
                                          name: '',
                                          intro: '',
                                          type: '',
                                          artStyle: '',
                                          directorManual: '',
                                          videoRatio: '',
                                          imageModel: '',
                                          videoModel: '',
                                          imageQuality: '',
                                          projectType: '',
                                          mode: '',
                                        );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'POST …/project/edit-project：unexpected 200',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (!ctx.mounted) return;
                                        if (e.statusCode == 400) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'POST …/project/edit-project id=0 -> 400 (expected)',
                                              ),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => projectLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                projectLegacyBusy[0]
                                    ? 'project…'
                                    : 'POST project edit id=0',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => projectLegacyBusy[0] = true,
                                      );
                                      final probeName =
                                          '[flutter legacy add-probe] ${DateTime.now().toIso8601String()}';
                                      try {
                                        await postProjectAddProject(
                                          token,
                                          projectType: '',
                                          name: probeName,
                                          intro: '',
                                          type: '',
                                          artStyle: '',
                                          directorManual: '',
                                          videoRatio: '',
                                          imageModel: '',
                                          videoModel: '',
                                          imageQuality: '',
                                          mode: '',
                                        );
                                        final all = await postProjectGetProject(
                                          token,
                                        );
                                        if (!ctx.mounted) return;
                                        ProjectRow? match;
                                        for (final r in all) {
                                          if (r.name == probeName) {
                                            match = r;
                                            break;
                                          }
                                        }
                                        if (match == null) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'add-project ok but get-project missing name="$probeName"',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        await postProjectDeleteProject(
                                          token,
                                          match.legacyId,
                                        );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST add-project → delete legacy#${match.legacyId} ok',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => projectLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                projectLegacyBusy[0]
                                    ? 'project…'
                                    : 'POST project add→del',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => tasksLegacyBusy[0] = true,
                                      );
                                      try {
                                        final items = await postTasksGetProject(
                                          token,
                                        );
                                        if (!ctx.mounted) return;
                                        final line = items.isEmpty
                                            ? '0 项'
                                            : items
                                                  .map(
                                                    (e) => '#${e.id} ${e.name}',
                                                  )
                                                  .join('; ');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/tasks/get-project：$line',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => tasksLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                tasksLegacyBusy[0]
                                    ? 'tasks…'
                                    : 'POST tasks get-project',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => tasksLegacyBusy[0] = true,
                                      );
                                      try {
                                        final rows =
                                            await postTasksGetTaskCategories(
                                              token,
                                            );
                                        if (!ctx.mounted) return;
                                        final line = rows.isEmpty
                                            ? '0 类'
                                            : rows
                                                  .map((e) => e.taskClass)
                                                  .join(', ');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/tasks/get-task-categories：$line',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => tasksLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                tasksLegacyBusy[0]
                                    ? 'tasks…'
                                    : 'POST tasks get-task-categories',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => tasksLegacyBusy[0] = true,
                                      );
                                      try {
                                        final r = await postTasksGetTaskApi(
                                          token,
                                          page: 1,
                                          limit: 10,
                                          projectId: p.legacyId,
                                        );
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'POST …/tasks/get-task-api：'
                                              'total=${r.total} · '
                                              '${r.data.length} 条本页',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => tasksLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                tasksLegacyBusy[0]
                                    ? 'tasks…'
                                    : 'POST tasks get-task-api',
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  generalLegacyBusy[0] ||
                                      tasksLegacyBusy[0] ||
                                      projectLegacyBusy[0]
                                  ? null
                                  : () async {
                                      setDialogState(
                                        () => tasksLegacyBusy[0] = true,
                                      );
                                      try {
                                        await postTasksTaskDetails(token, 1);
                                        if (!ctx.mounted) return;
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'POST …/tasks/task-details：501（预期）',
                                            ),
                                          ),
                                        );
                                      } on RustApiException catch (e) {
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (ctx.mounted) {
                                          setDialogState(
                                            () => tasksLegacyBusy[0] = false,
                                          );
                                        }
                                      }
                                    },
                              child: Text(
                                tasksLegacyBusy[0]
                                    ? 'tasks…'
                                    : 'POST tasks task-details (501)',
                              ),
                            ),
                          ],
                        ),
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

  Future<void> _openStoryboardEditor(
    String token,
    int storyLegacyId, {
    Future<void> Function()? onStoryboardTreeMutated,
  }) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    try {
      final row = await fetchStoryboardByLegacyId(token, storyLegacyId);
      if (!mounted) return;
      promptCtrl.text = row.prompt ?? '';
      stateCtrl.text = row.state ?? '';
      videoCtrl.text = row.videoDesc ?? '';
      sbIdxCtrl.text = row.sbIndex?.toString() ?? '';
      sgiCtrl.text = row.shouldGenerateImage?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Storyboard #${row.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: promptCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'prompt (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'state (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: videoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'video_desc (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sbIdxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'sb_index (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sgiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'should_generate_image (empty = clear)',
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
                                title: const Text('删除分镜？'),
                                content: Text(
                                  '将删除 storyboard #${row.legacyId}。',
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
                              await deleteStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('分镜已删除')),
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
                            int? sbIdx;
                            final sbs = sbIdxCtrl.text.trim();
                            if (sbs.isNotEmpty) {
                              sbIdx = int.tryParse(sbs);
                              if (sbIdx == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('sb_index 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            int? sgi;
                            final sgis = sgiCtrl.text.trim();
                            if (sgis.isNotEmpty) {
                              sgi = int.tryParse(sgis);
                              if (sgi == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'should_generate_image 须为整数',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                                {
                                  'prompt': promptCtrl.text.isEmpty
                                      ? null
                                      : promptCtrl.text,
                                  'state': stateCtrl.text.isEmpty
                                      ? null
                                      : stateCtrl.text,
                                  'video_desc': videoCtrl.text.isEmpty
                                      ? null
                                      : videoCtrl.text,
                                  'sb_index': sbs.isEmpty ? null : sbIdx,
                                  'should_generate_image': sgis.isEmpty
                                      ? null
                                      : sgi,
                                },
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
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
      promptCtrl.dispose();
      stateCtrl.dispose();
      videoCtrl.dispose();
      sbIdxCtrl.dispose();
      sgiCtrl.dispose();
    }
  }
}
