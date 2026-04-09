part of '../home_page.dart';

class _StoryboardWorkbenchPanel extends StatefulWidget {
  const _StoryboardWorkbenchPanel({
    required this.token,
    required this.storyLegacyId,
    required this.projectLegacyId,
    required this.scriptLegacyId,
    required this.scriptStoryboard,
    required this.readPromptText,
    required this.readVideoDescriptionText,
  });

  final String token;
  final int storyLegacyId;
  final int projectLegacyId;
  final int scriptLegacyId;
  final StoryboardRow scriptStoryboard;
  final String Function() readPromptText;
  final String Function() readVideoDescriptionText;

  @override
  State<_StoryboardWorkbenchPanel> createState() =>
      _StoryboardWorkbenchPanelState();
}

class _StoryboardWorkbenchPanelState extends State<_StoryboardWorkbenchPanel> {
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _trackIdCtrl;
  late final TextEditingController _trackNameCtrl;
  late final TextEditingController _videoPromptCtrl;
  late final TextEditingController _videoDurationCtrl;

  bool _saving = false;
  bool _loadingProduction = false;
  bool _loadingWorkbench = false;
  ProductionStoryboardItemV1? _productionRow;
  List<ProductionStoryboardItemV1> _productionRows = const [];
  VideoModelDetail? _modelDetail;
  GetGenerateDataResponse? _generateData;
  String? _productionError;
  String? _workbenchLine;
  String _mode = 'standard';
  String _resolution = '1080p';
  bool _audio = false;

  @override
  void initState() {
    super.initState();
    _imageUrlCtrl = TextEditingController();
    _trackIdCtrl = TextEditingController();
    _trackNameCtrl = TextEditingController();
    _videoPromptCtrl = TextEditingController();
    _videoDurationCtrl = TextEditingController(text: '5');
    Future<void>.microtask(
      () => _refreshAll(syncImageUrl: true, syncTrackId: true),
    );
  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _trackIdCtrl.dispose();
    _trackNameCtrl.dispose();
    _videoPromptCtrl.dispose();
    _videoDurationCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _refreshProductionData({
    bool syncImageUrl = false,
    bool syncTrackId = false,
  }) async {
    setState(() {
      _loadingProduction = true;
      _productionError = null;
    });
    try {
      final productionRow = await postStoryboardGetDataV1(
        widget.token,
        storyboardId: widget.storyLegacyId,
      );
      final productionRows = await postProductionGetStoryboardDataV1(
        widget.token,
        projectId: widget.projectLegacyId,
        scriptId: widget.scriptLegacyId,
      );
      if (!mounted) return;
      setState(() {
        _productionRow = productionRow;
        _productionRows = productionRows.data;
        if (syncImageUrl) {
          _imageUrlCtrl.text = productionRow.url ?? '';
        }
        if (syncTrackId && productionRow.trackId != null) {
          _trackIdCtrl.text = productionRow.trackId!.toString();
        }
        if (_videoPromptCtrl.text.trim().isEmpty &&
            (productionRow.prompt ?? '').trim().isNotEmpty) {
          _videoPromptCtrl.text = productionRow.prompt!.trim();
        }
        if ((_videoDurationCtrl.text.trim().isEmpty ||
                int.tryParse(_videoDurationCtrl.text.trim()) == null) &&
            (productionRow.duration ?? '').trim().isNotEmpty) {
          _videoDurationCtrl.text = productionRow.duration!.trim();
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _productionError = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _productionError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingProduction = false);
      }
    }
  }

  Future<void> _refreshWorkbenchData() async {
    setState(() {
      _loadingWorkbench = true;
      _workbenchLine = null;
    });
    try {
      final model = await postWorkbenchGetVideoModelDetailV1(widget.token);
      final generateData = await postWorkbenchGetGenerateDataV1(
        widget.token,
        projectId: widget.projectLegacyId,
        scriptId: widget.scriptLegacyId,
      );
      if (!mounted) return;
      setState(() {
        _modelDetail = model;
        _generateData = generateData;
        if (!model.resolutions.contains(_resolution)) {
          _resolution = model.resolutions.isEmpty
              ? '1080p'
              : model.resolutions.first;
        }
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _workbenchLine = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _workbenchLine = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingWorkbench = false);
      }
    }
  }

  Future<void> _refreshAll({
    bool syncImageUrl = false,
    bool syncTrackId = false,
  }) async {
    await _refreshProductionData(
      syncImageUrl: syncImageUrl,
      syncTrackId: syncTrackId,
    );
    await _refreshWorkbenchData();
  }

  Future<void> _runDialogAction(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildStoryboardPreviewCard() {
    final outline = Theme.of(context).colorScheme.outline;
    final imageUrl = _productionRow?.url?.trim();
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
            _storyboardProductionMetaLine(_productionRow),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          if (_loadingProduction)
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
          if ((_productionRow?.prompt ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _productionRow!.prompt!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final knownTrackIds = collectStoryboardTrackIds(
      scriptStoryboard: widget.scriptStoryboard,
      productionStoryboard: _productionRow,
      productionStoryboards: _productionRows,
      generatedVideos: _generateData?.generatedVideos ?? const [],
    );
    final storyboardVideos = storyboardScopedVideos(
      _generateData?.generatedVideos ?? const [],
      widget.storyLegacyId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStoryboardPreviewCard(),
        if (_productionError != null) ...[
          const SizedBox(height: 8),
          Text(
            _productionError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('图片工作台', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _imageUrlCtrl,
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
              onPressed: _saving
                  ? null
                  : () => _runDialogAction(() async {
                      final preview = await postStoryboardPreviewImageV1(
                        widget.token,
                        storyboardId: widget.storyLegacyId,
                      );
                      _imageUrlCtrl.text = preview.imageUrl ?? '';
                      await _refreshProductionData();
                    }),
              child: Text(_saving ? '处理中…' : '读取当前预览'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _runDialogAction(() async {
                      final imageUrl = _imageUrlCtrl.text.trim();
                      if (imageUrl.isEmpty) {
                        throw const FormatException('图片 URL 不能为空');
                      }
                      final response = await postStoryboardUpdateUrlV1(
                        widget.token,
                        storyboardId: widget.storyLegacyId,
                        imageUrl: imageUrl,
                      );
                      _imageUrlCtrl.text = response.imageUrl;
                      await _refreshProductionData();
                    }),
              child: const Text('保存图片 URL'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _runDialogAction(() async {
                      await postStoryboardRemoveFrameV1(
                        widget.token,
                        storyboardId: widget.storyLegacyId,
                      );
                      _imageUrlCtrl.clear();
                      await _refreshProductionData();
                    }),
              child: const Text('清空画面'),
            ),
            TextButton(
              onPressed: _saving || _loadingProduction
                  ? null
                  : () => _refreshProductionData(
                      syncImageUrl: true,
                      syncTrackId: true,
                    ),
              child: Text(_loadingProduction ? '刷新中…' : '刷新制作数据'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('视频工作台', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _trackIdCtrl,
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
          controller: _trackNameCtrl,
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
              onPressed: _saving
                  ? null
                  : () => _runDialogAction(() async {
                      final name = _trackNameCtrl.text.trim();
                      if (name.isEmpty) {
                        throw const FormatException('轨道名称不能为空');
                      }
                      final response = await postWorkbenchAddTrackV1(
                        widget.token,
                        projectId: widget.projectLegacyId,
                        scriptId: widget.scriptLegacyId,
                        trackName: name,
                      );
                      _trackIdCtrl.text = response.trackId.toString();
                      _trackNameCtrl.clear();
                      await _refreshAll(syncTrackId: true);
                    }),
              child: const Text('新增轨道'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _runDialogAction(() async {
                      final trackId = int.tryParse(_trackIdCtrl.text.trim());
                      if (trackId == null || trackId <= 0) {
                        throw const FormatException('请填写有效轨道 ID');
                      }
                      await postWorkbenchDeleteTrackV1(
                        widget.token,
                        projectId: widget.projectLegacyId,
                        scriptId: widget.scriptLegacyId,
                        trackId: trackId,
                      );
                      if (_productionRow?.trackId == trackId) {
                        _trackIdCtrl.clear();
                      }
                      await _refreshAll(syncTrackId: true);
                    }),
              child: const Text('删除轨道'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _runDialogAction(() async {
                      final generated =
                          await postWorkbenchGenerateVideoPromptV1(
                            widget.token,
                            projectId: widget.projectLegacyId,
                            scriptId: widget.scriptLegacyId,
                            imageUrl: resolveStoryboardSourceImageUrl(
                              productionStoryboard: _productionRow,
                              draftImageUrl: _imageUrlCtrl.text,
                            ),
                            description:
                                widget.readVideoDescriptionText().trim().isEmpty
                                ? widget.readPromptText().trim()
                                : widget.readVideoDescriptionText().trim(),
                          );
                      _videoPromptCtrl.text = generated.prompt;
                      _videoDurationCtrl.text = generated.duration.toString();
                    }),
              child: const Text('生成默认视频提示词'),
            ),
            TextButton(
              onPressed: _saving || _loadingWorkbench
                  ? null
                  : _refreshWorkbenchData,
              child: Text(_loadingWorkbench ? '刷新中…' : '刷新视频数据'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _videoPromptCtrl,
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
                controller: _videoDurationCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '时长（秒）'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _resolution,
                decoration: const InputDecoration(labelText: '分辨率'),
                items: (_modelDetail?.resolutions.isNotEmpty ?? false)
                    ? _modelDetail!.resolutions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(growable: false)
                    : const [
                        DropdownMenuItem(value: '1080p', child: Text('1080p')),
                        DropdownMenuItem(value: '720p', child: Text('720p')),
                      ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _resolution = value);
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
                initialValue: _mode,
                decoration: const InputDecoration(labelText: '生成模式'),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('standard')),
                  DropdownMenuItem(value: 'fast', child: Text('fast')),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _mode = value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '模型'),
                child: Text(_modelDetail?.modelId ?? '等待加载模型信息'),
              ),
            ),
          ],
        ),
        CheckboxListTile(
          value: _audio,
          contentPadding: EdgeInsets.zero,
          title: const Text('生成视频时携带音频'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: _saving
              ? null
              : (value) => setState(() => _audio = value ?? false),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _saving
                ? null
                : () => _runDialogAction(() async {
                    final sourceImage = resolveStoryboardSourceImageUrl(
                      productionStoryboard: _productionRow,
                      draftImageUrl: _imageUrlCtrl.text,
                    );
                    if (sourceImage == null) {
                      throw const FormatException('生成视频前需要先提供图片 URL 或当前预览图');
                    }
                    final trackId = int.tryParse(_trackIdCtrl.text.trim());
                    if (trackId == null || trackId <= 0) {
                      throw const FormatException('生成视频前请填写有效轨道 ID');
                    }
                    final duration = int.tryParse(
                      _videoDurationCtrl.text.trim(),
                    );
                    if (duration == null || duration <= 0) {
                      throw const FormatException('视频时长必须是正整数');
                    }
                    final prompt = _videoPromptCtrl.text.trim();
                    if (prompt.isEmpty) {
                      throw const FormatException('视频提示词不能为空');
                    }
                    final status = await postProductionWorkbenchGenerateVideoV1(
                      widget.token,
                      projectId: widget.projectLegacyId,
                      scriptId: widget.scriptLegacyId,
                      uploadData: [
                        <String, dynamic>{
                          'id': widget.storyLegacyId,
                          'sources': sourceImage,
                        },
                      ],
                      prompt: prompt,
                      model: _modelDetail?.modelId ?? 'kling-v1',
                      mode: _mode,
                      resolution: _resolution,
                      duration: duration,
                      audio: _audio,
                      trackId: trackId,
                    );
                    if (!mounted) return;
                    setState(() => _workbenchLine = '视频任务已提交，HTTP $status');
                    await _refreshWorkbenchData();
                  }),
            child: Text(_saving ? '提交中…' : '提交视频生成'),
          ),
        ),
        if (_workbenchLine != null) ...[
          const SizedBox(height: 8),
          Text(_workbenchLine!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Text('当前分镜的视频候选', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          storyboardVideos.isEmpty
              ? '还没有与当前 storyboard 关联的已生成视频。'
              : '优先展示当前 storyboard 的视频结果，可一键设为当前选中视频。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        ...storyboardVideos
            .take(3)
            .map(
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
                    if (video.trackId != null) '轨道 ${video.trackId}',
                    if ((video.duration ?? '').trim().isNotEmpty)
                      '时长 ${video.duration}',
                  ].join(' · '),
                ),
                trailing: TextButton(
                  onPressed: _saving || (video.videoUrl ?? '').trim().isEmpty
                      ? null
                      : () => _runDialogAction(() async {
                          await postWorkbenchSelectVideoV1(
                            widget.token,
                            projectId: widget.projectLegacyId,
                            scriptId: widget.scriptLegacyId,
                            storyboardId: widget.storyLegacyId,
                            videoUrl: video.videoUrl!.trim(),
                          );
                          await _refreshProductionData(syncTrackId: true);
                        }),
                  child: const Text('设为当前视频'),
                ),
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _saving
                ? null
                : () => _runDialogAction(() async {
                    await postWorkbenchDeleteVideoV1(
                      widget.token,
                      projectId: widget.projectLegacyId,
                      scriptId: widget.scriptLegacyId,
                      storyboardId: widget.storyLegacyId,
                    );
                    await _refreshProductionData(syncTrackId: true);
                    await _refreshWorkbenchData();
                  }),
            child: const Text('删除当前已选视频'),
          ),
        ),
        if ((_generateData?.generatingJobs.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          Text('进行中的视频任务', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          ..._generateData!.generatingJobs
              .take(3)
              .map(
                (job) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(job.kind),
                  subtitle: Text('状态 ${job.status} · ${job.updatedAt}'),
                ),
              ),
        ],
      ],
    );
  }
}
