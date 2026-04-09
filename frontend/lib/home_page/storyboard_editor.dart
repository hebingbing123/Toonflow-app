part of '../home_page.dart';

extension _HomePageStoryboardEditor on _HomePageState {
  String _storyboardProductionMetaLine(ProductionStoryboardItemV1? row) {
    if (row == null) return '制作视图尚未加载';
    final parts = <String>[
      if (row.sbIndex != null) '序号 ${row.sbIndex}',
      if ((row.state ?? '').trim().isNotEmpty) '状态 ${row.state}',
      if ((row.duration ?? '').trim().isNotEmpty) '时长 ${row.duration}',
      if (row.trackId != null) '轨道 ${row.trackId}',
    ];
    if (parts.isEmpty) {
      return '制作视图已加载';
    }
    return parts.join(' · ');
  }

  Widget _buildStoryboardPreviewCard({
    required BuildContext context,
    required ProductionStoryboardItemV1? productionRow,
    required bool loading,
  }) {
    final outline = Theme.of(context).colorScheme.outline;
    final imageUrl = productionRow?.url?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: outline.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前画面', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            _storyboardProductionMetaLine(productionRow),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (imageUrl == null || imageUrl.isEmpty)
            Text(
              '当前分镜还没有选中的画面。可以先填写图片 URL，或先读取当前预览再继续生成视频。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: outline),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 180,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    '图片预览失败\n$imageUrl',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          if ((productionRow?.prompt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              productionRow!.prompt!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openStoryboardEditor(
    String token,
    int storyLegacyId, {
    required int projectLegacyId,
    required int scriptLegacyId,
    Future<void> Function()? onStoryboardTreeMutated,
  }) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();
    final trackIdCtrl = TextEditingController();
    final trackNameCtrl = TextEditingController();
    final videoPromptCtrl = TextEditingController();
    final videoDurationCtrl = TextEditingController(text: '5');
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
          final bootstrapped = <bool>[false];
          final saving = <bool>[false];
          final loadingProduction = <bool>[false];
          final loadingWorkbench = <bool>[false];
          final productionRowRef = <ProductionStoryboardItemV1?>[null];
          final productionRowsRef = <List<ProductionStoryboardItemV1>>[
            const [],
          ];
          final modelDetailRef = <VideoModelDetail?>[null];
          final generateDataRef = <GetGenerateDataResponse?>[null];
          final productionErrorRef = <String?>[null];
          final workbenchLineRef = <String?>[null];
          final modeRef = <String>['standard'];
          final resolutionRef = <String>['1080p'];
          final audioRef = <bool>[false];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              Future<void> refreshProductionData({
                bool syncImageUrl = false,
                bool syncTrackId = false,
              }) async {
                loadingProduction[0] = true;
                productionErrorRef[0] = null;
                setDialogState(() {});
                try {
                  final productionRow = await postStoryboardGetDataV1(
                    token,
                    storyboardId: storyLegacyId,
                  );
                  final productionRows =
                      await postProductionGetStoryboardDataV1(
                        token,
                        projectId: projectLegacyId,
                        scriptId: scriptLegacyId,
                      );
                  productionRowRef[0] = productionRow;
                  productionRowsRef[0] = productionRows.data;
                  if (syncImageUrl) {
                    imageUrlCtrl.text = productionRow.url ?? '';
                  }
                  if (syncTrackId && productionRow.trackId != null) {
                    trackIdCtrl.text = productionRow.trackId!.toString();
                  }
                  if (videoPromptCtrl.text.trim().isEmpty &&
                      (productionRow.prompt ?? '').trim().isNotEmpty) {
                    videoPromptCtrl.text = productionRow.prompt!.trim();
                  }
                  if ((videoDurationCtrl.text.trim().isEmpty ||
                          int.tryParse(videoDurationCtrl.text.trim()) ==
                              null) &&
                      (productionRow.duration ?? '').trim().isNotEmpty) {
                    videoDurationCtrl.text = productionRow.duration!.trim();
                  }
                } on RustApiException catch (e) {
                  productionErrorRef[0] = e.toString();
                } catch (e) {
                  productionErrorRef[0] = e.toString();
                } finally {
                  loadingProduction[0] = false;
                  if (ctx.mounted) {
                    setDialogState(() {});
                  }
                }
              }

              Future<void> refreshWorkbenchData() async {
                loadingWorkbench[0] = true;
                workbenchLineRef[0] = null;
                setDialogState(() {});
                try {
                  final model = await postWorkbenchGetVideoModelDetailV1(token);
                  final generateData = await postWorkbenchGetGenerateDataV1(
                    token,
                    projectId: projectLegacyId,
                    scriptId: scriptLegacyId,
                  );
                  modelDetailRef[0] = model;
                  generateDataRef[0] = generateData;
                  if (!model.resolutions.contains(resolutionRef[0])) {
                    resolutionRef[0] = model.resolutions.isEmpty
                        ? '1080p'
                        : model.resolutions.first;
                  }
                } on RustApiException catch (e) {
                  workbenchLineRef[0] = e.toString();
                } catch (e) {
                  workbenchLineRef[0] = e.toString();
                } finally {
                  loadingWorkbench[0] = false;
                  if (ctx.mounted) {
                    setDialogState(() {});
                  }
                }
              }

              Future<void> refreshAll({
                bool syncImageUrl = false,
                bool syncTrackId = false,
              }) async {
                await refreshProductionData(
                  syncImageUrl: syncImageUrl,
                  syncTrackId: syncTrackId,
                );
                await refreshWorkbenchData();
              }

              Future<void> runDialogAction(
                Future<void> Function() action,
              ) async {
                setDialogState(() => saving[0] = true);
                try {
                  await action();
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } on FormatException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => saving[0] = false);
                  }
                }
              }

              if (!bootstrapped[0]) {
                bootstrapped[0] = true;
                Future<void>.microtask(
                  () => refreshAll(syncImageUrl: true, syncTrackId: true),
                );
              }

              final currentProduction = productionRowRef[0];
              final generateData = generateDataRef[0];
              final modelDetail = modelDetailRef[0];
              final knownTrackIds = collectStoryboardTrackIds(
                scriptStoryboard: row,
                productionStoryboard: currentProduction,
                productionStoryboards: productionRowsRef[0],
                generatedVideos: generateData?.generatedVideos ?? const [],
              );
              final storyboardVideos = storyboardScopedVideos(
                generateData?.generatedVideos ?? const [],
                storyLegacyId,
              );

              return AlertDialog(
                title: Text('Storyboard #${row.legacyId}'),
                content: SizedBox(
                  width: 720,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStoryboardPreviewCard(
                          context: ctx,
                          productionRow: currentProduction,
                          loading: loadingProduction[0],
                        ),
                        if (productionErrorRef[0] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            productionErrorRef[0]!,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: promptCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '分镜提示词（留空则清空）',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(
                            labelText: '状态（留空则清空）',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: videoCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '视频描述（留空则清空）',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sbIdxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '分镜序号（留空则清空）',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: sgiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '是否需要出图（留空则清空）',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '图片工作台',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: imageUrlCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '当前图片 URL / data URI',
                            helperText: '支持 HTTP URL 或 data:image/...;base64。',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: saving[0]
                                  ? null
                                  : () => runDialogAction(() async {
                                      final preview =
                                          await postStoryboardPreviewImageV1(
                                            token,
                                            storyboardId: storyLegacyId,
                                          );
                                      imageUrlCtrl.text =
                                          preview.imageUrl ?? '';
                                      await refreshProductionData();
                                    }),
                              child: Text(saving[0] ? '处理中…' : '读取当前预览'),
                            ),
                            TextButton(
                              onPressed: saving[0]
                                  ? null
                                  : () => runDialogAction(() async {
                                      final imageUrl = imageUrlCtrl.text.trim();
                                      if (imageUrl.isEmpty) {
                                        throw const FormatException(
                                          '图片 URL 不能为空',
                                        );
                                      }
                                      final response =
                                          await postStoryboardUpdateUrlV1(
                                            token,
                                            storyboardId: storyLegacyId,
                                            imageUrl: imageUrl,
                                          );
                                      imageUrlCtrl.text = response.imageUrl;
                                      await refreshProductionData();
                                    }),
                              child: const Text('保存图片 URL'),
                            ),
                            TextButton(
                              onPressed: saving[0]
                                  ? null
                                  : () => runDialogAction(() async {
                                      await postStoryboardRemoveFrameV1(
                                        token,
                                        storyboardId: storyLegacyId,
                                      );
                                      imageUrlCtrl.clear();
                                      await refreshProductionData();
                                    }),
                              child: const Text('清空画面'),
                            ),
                            TextButton(
                              onPressed: saving[0] || loadingProduction[0]
                                  ? null
                                  : () => refreshProductionData(
                                      syncImageUrl: true,
                                      syncTrackId: true,
                                    ),
                              child: Text(
                                loadingProduction[0] ? '刷新中…' : '刷新制作数据',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '视频工作台',
                          style: Theme.of(ctx).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: trackIdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '轨道 ID',
                            helperText: knownTrackIds.isEmpty
                                ? '当前还没有已知轨道，可先新建。'
                                : '已发现轨道：${knownTrackIds.join(", ")}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: trackNameCtrl,
                          decoration: const InputDecoration(
                            labelText: '新轨道名称',
                            helperText: '新增后会自动回填轨道 ID。',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: saving[0]
                                  ? null
                                  : () => runDialogAction(() async {
                                      final name = trackNameCtrl.text.trim();
                                      if (name.isEmpty) {
                                        throw const FormatException('轨道名称不能为空');
                                      }
                                      final response =
                                          await postWorkbenchAddTrackV1(
                                            token,
                                            projectId: projectLegacyId,
                                            scriptId: scriptLegacyId,
                                            trackName: name,
                                          );
                                      trackIdCtrl.text = response.trackId
                                          .toString();
                                      trackNameCtrl.clear();
                                      await refreshAll(syncTrackId: true);
                                    }),
                              child: const Text('新增轨道'),
                            ),
                            TextButton(
                              onPressed: saving[0]
                                  ? null
                                  : () => runDialogAction(() async {
                                      final trackId = int.tryParse(
                                        trackIdCtrl.text.trim(),
                                      );
                                      if (trackId == null || trackId <= 0) {
                                        throw const FormatException(
                                          '请填写有效轨道 ID',
                                        );
                                      }
                                      await postWorkbenchDeleteTrackV1(
                                        token,
                                        projectId: projectLegacyId,
                                        scriptId: scriptLegacyId,
                                        trackId: trackId,
                                      );
                                      if (currentProduction?.trackId ==
                                          trackId) {
                                        trackIdCtrl.clear();
                                      }
                                      await refreshAll(syncTrackId: true);
                                    }),
                              child: const Text('删除轨道'),
                            ),
                            TextButton(
                              onPressed: saving[0]
                                  ? null
                                  : () => runDialogAction(() async {
                                      final generated =
                                          await postWorkbenchGenerateVideoPromptV1(
                                            token,
                                            projectId: projectLegacyId,
                                            scriptId: scriptLegacyId,
                                            imageUrl:
                                                resolveStoryboardSourceImageUrl(
                                                  productionStoryboard:
                                                      currentProduction,
                                                  draftImageUrl:
                                                      imageUrlCtrl.text,
                                                ),
                                            description:
                                                videoCtrl.text.trim().isEmpty
                                                ? promptCtrl.text.trim()
                                                : videoCtrl.text.trim(),
                                          );
                                      videoPromptCtrl.text = generated.prompt;
                                      videoDurationCtrl.text = generated
                                          .duration
                                          .toString();
                                    }),
                              child: const Text('生成默认视频提示词'),
                            ),
                            TextButton(
                              onPressed: saving[0] || loadingWorkbench[0]
                                  ? null
                                  : refreshWorkbenchData,
                              child: Text(
                                loadingWorkbench[0] ? '刷新中…' : '刷新视频数据',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: videoPromptCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: '视频生成提示词',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: videoDurationCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '时长（秒）',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: resolutionRef[0],
                                decoration: const InputDecoration(
                                  labelText: '分辨率',
                                ),
                                items:
                                    (modelDetail?.resolutions.isNotEmpty ??
                                        false)
                                    ? modelDetail!.resolutions
                                          .map(
                                            (item) => DropdownMenuItem(
                                              value: item,
                                              child: Text(item),
                                            ),
                                          )
                                          .toList(growable: false)
                                    : const [
                                        DropdownMenuItem(
                                          value: '1080p',
                                          child: Text('1080p'),
                                        ),
                                        DropdownMenuItem(
                                          value: '720p',
                                          child: Text('720p'),
                                        ),
                                      ],
                                onChanged: saving[0]
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setDialogState(
                                          () => resolutionRef[0] = value,
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: modeRef[0],
                                decoration: const InputDecoration(
                                  labelText: '生成模式',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'standard',
                                    child: Text('standard'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fast',
                                    child: Text('fast'),
                                  ),
                                ],
                                onChanged: saving[0]
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setDialogState(
                                          () => modeRef[0] = value,
                                        );
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: '模型',
                                ),
                                child: Text(modelDetail?.modelId ?? '等待加载模型信息'),
                              ),
                            ),
                          ],
                        ),
                        CheckboxListTile(
                          value: audioRef[0],
                          contentPadding: EdgeInsets.zero,
                          title: const Text('生成视频时携带音频'),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: saving[0]
                              ? null
                              : (value) => setDialogState(
                                  () => audioRef[0] = value ?? false,
                                ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: saving[0]
                                ? null
                                : () => runDialogAction(() async {
                                    final sourceImage =
                                        resolveStoryboardSourceImageUrl(
                                          productionStoryboard:
                                              currentProduction,
                                          draftImageUrl: imageUrlCtrl.text,
                                        );
                                    if (sourceImage == null) {
                                      throw const FormatException(
                                        '生成视频前需要先提供图片 URL 或当前预览图',
                                      );
                                    }
                                    final trackId = int.tryParse(
                                      trackIdCtrl.text.trim(),
                                    );
                                    if (trackId == null || trackId <= 0) {
                                      throw const FormatException(
                                        '生成视频前请填写有效轨道 ID',
                                      );
                                    }
                                    final duration = int.tryParse(
                                      videoDurationCtrl.text.trim(),
                                    );
                                    if (duration == null || duration <= 0) {
                                      throw const FormatException('视频时长必须是正整数');
                                    }
                                    final prompt = videoPromptCtrl.text.trim();
                                    if (prompt.isEmpty) {
                                      throw const FormatException('视频提示词不能为空');
                                    }
                                    final status =
                                        await postProductionWorkbenchGenerateVideoV1(
                                          token,
                                          projectId: projectLegacyId,
                                          scriptId: scriptLegacyId,
                                          uploadData: [
                                            <String, dynamic>{
                                              'id': storyLegacyId,
                                              'sources': sourceImage,
                                            },
                                          ],
                                          prompt: prompt,
                                          model:
                                              modelDetail?.modelId ??
                                              'kling-v1',
                                          mode: modeRef[0],
                                          resolution: resolutionRef[0],
                                          duration: duration,
                                          audio: audioRef[0],
                                          trackId: trackId,
                                        );
                                    workbenchLineRef[0] =
                                        '视频任务已提交，HTTP $status';
                                    await refreshWorkbenchData();
                                  }),
                            child: Text(saving[0] ? '提交中…' : '提交视频生成'),
                          ),
                        ),
                        if (workbenchLineRef[0] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            workbenchLineRef[0]!,
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          '当前分镜的视频候选',
                          style: Theme.of(ctx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          storyboardVideos.isEmpty
                              ? '还没有与当前 storyboard 关联的已生成视频。'
                              : '优先展示当前 storyboard 的视频结果，可一键设为当前选中视频。',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...storyboardVideos.take(3).map(
                          (video) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              video.videoUrl ?? '视频 URL 缺失',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if ((video.state ?? '').trim().isNotEmpty)
                                  '状态 ${video.state}',
                                if (video.trackId != null)
                                  '轨道 ${video.trackId}',
                                if ((video.duration ?? '').trim().isNotEmpty)
                                  '时长 ${video.duration}',
                              ].join(' · '),
                            ),
                            trailing: TextButton(
                              onPressed:
                                  saving[0] ||
                                      (video.videoUrl ?? '').trim().isEmpty
                                  ? null
                                  : () => runDialogAction(() async {
                                      await postWorkbenchSelectVideoV1(
                                        token,
                                        projectId: projectLegacyId,
                                        scriptId: scriptLegacyId,
                                        storyboardId: storyLegacyId,
                                        videoUrl: video.videoUrl!.trim(),
                                      );
                                      await refreshProductionData(
                                        syncTrackId: true,
                                      );
                                    }),
                              child: const Text('设为当前视频'),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: saving[0]
                                ? null
                                : () => runDialogAction(() async {
                                    await postWorkbenchDeleteVideoV1(
                                      token,
                                      projectId: projectLegacyId,
                                      scriptId: scriptLegacyId,
                                      storyboardId: storyLegacyId,
                                    );
                                    await refreshProductionData(
                                      syncTrackId: true,
                                    );
                                    await refreshWorkbenchData();
                                  }),
                            child: const Text('删除当前已选视频'),
                          ),
                        ),
                        if ((generateData?.generatingJobs.isNotEmpty ??
                            false)) ...[
                          const SizedBox(height: 8),
                          Text(
                            '进行中的视频任务',
                            style: Theme.of(ctx).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          ...generateData!.generatingJobs.take(3).map(
                            (job) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(job.kind),
                              subtitle: Text('状态 ${job.status} · ${job.updatedAt}'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('删除分镜？'),
                                content: Text('将删除 storyboard #${row.legacyId}。'),
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
                    child: const Text('删除分镜'),
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
                                    const SnackBar(content: Text('分镜序号必须是整数')),
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
                                      content: Text('是否需要出图必须是整数'),
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
                    child: Text(saving[0] ? '保存中…' : '保存修改'),
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
      imageUrlCtrl.dispose();
      trackIdCtrl.dispose();
      trackNameCtrl.dispose();
      videoPromptCtrl.dispose();
      videoDurationCtrl.dispose();
    }
  }
}
