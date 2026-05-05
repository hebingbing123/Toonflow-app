part of '../../home_page.dart';

/// Video workbench section extracted from [_StoryboardWorkbenchPanel] to keep
/// individual part files ≤800 lines.
class _StoryboardVideoSection extends StatelessWidget {
  const _StoryboardVideoSection({
    required this.saving,
    required this.loadingWorkbench,
    required this.trackIdCtrl,
    required this.trackNameCtrl,
    required this.videoDescriptionCtrl,
    required this.videoPromptCtrl,
    required this.negativeVideoPromptCtrl,
    required this.videoDurationCtrl,
    required this.liveActionReferenceShotsCtrl,
    required this.liveActionPerformanceNotesCtrl,
    required this.resolution,
    required this.mode,
    required this.audio,
    required this.autoQualityReviewOnGeneratePrompt,
    required this.modelDetail,
    required this.generateData,
    required this.productionRow,
    required this.currentSelectedVideoUrl,
    required this.workbenchLine,
    required this.promptDiagnostics,
    required this.knownTrackIds,
    required this.storyboardVideos,
    required this.onResolutionChanged,
    required this.onModeChanged,
    required this.onAudioChanged,
    required this.onAutoQualityReviewOnGeneratePromptChanged,
    required this.onAddTrack,
    required this.onDeleteTrack,
    required this.onGenerateVideoPrompt,
    required this.onGenerateVoiceover,
    required this.onSaveLiveActionReference,
    required this.onOpenPatchRegeneration,
    required this.onApplyPromptRepairs,
    required this.onRefreshVideoData,
    required this.loadingExportJob,
    required this.latestExportJob,
    required this.onSubmitVideoGeneration,
    required this.onSaveVideoDescription,
    required this.onExportCurrentVideo,
    required this.onRefreshExportJob,
    required this.onSelectVideo,
    required this.onDeleteCurrentVideo,
  });

  final bool saving;
  final bool loadingWorkbench;
  final TextEditingController trackIdCtrl;
  final TextEditingController trackNameCtrl;
  final TextEditingController videoDescriptionCtrl;
  final TextEditingController videoPromptCtrl;
  final TextEditingController negativeVideoPromptCtrl;
  final TextEditingController videoDurationCtrl;
  final TextEditingController liveActionReferenceShotsCtrl;
  final TextEditingController liveActionPerformanceNotesCtrl;
  final String resolution;
  final String mode;
  final bool audio;
  final bool autoQualityReviewOnGeneratePrompt;
  final VideoModelDetail? modelDetail;
  final GetGenerateDataResponse? generateData;
  final ProductionStoryboardItemV1? productionRow;
  final String? currentSelectedVideoUrl;
  final String? workbenchLine;
  final GenerateVideoPromptDiagnostics? promptDiagnostics;
  final List<int> knownTrackIds;
  final List<VideoItem> storyboardVideos;
  final ValueChanged<String> onResolutionChanged;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<bool> onAudioChanged;
  final ValueChanged<bool> onAutoQualityReviewOnGeneratePromptChanged;
  final VoidCallback onAddTrack;
  final VoidCallback onDeleteTrack;
  final VoidCallback onGenerateVideoPrompt;
  final VoidCallback onGenerateVoiceover;
  final VoidCallback onSaveLiveActionReference;
  final VoidCallback onOpenPatchRegeneration;
  final VoidCallback onApplyPromptRepairs;
  final VoidCallback onRefreshVideoData;
  final bool loadingExportJob;
  final JobRow? latestExportJob;
  final VoidCallback onSubmitVideoGeneration;
  final VoidCallback onSaveVideoDescription;
  final VoidCallback onExportCurrentVideo;
  final VoidCallback onRefreshExportJob;
  final ValueChanged<VideoItem> onSelectVideo;
  final VoidCallback onDeleteCurrentVideo;

  @override
  Widget build(BuildContext context) {
    final latestExportUrl = (latestExportJob?.result?['export_url'] as String?)
        ?.trim();
    final resolvedExportUrl =
        latestExportUrl != null && latestExportUrl.isNotEmpty
        ? resolveRustApiUrl(latestExportUrl)
        : null;
    final repairSuggestions = promptDiagnostics == null
        ? const <String>[]
        : buildStoryboardVideoPromptRepairSuggestions(promptDiagnostics!);
    final selectedVideoUrl = currentSelectedVideoUrl?.trim() ?? '';
    final hasSelectedVideo = selectedVideoUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('视频工作台', style: Theme.of(context).textTheme.titleSmall),
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
              onPressed: saving ? null : onAddTrack,
              child: const Text('新增轨道'),
            ),
            TextButton(
              onPressed: saving ? null : onDeleteTrack,
              child: const Text('删除轨道'),
            ),
            TextButton(
              onPressed: saving ? null : onGenerateVideoPrompt,
              child: const Text('手动生成默认提示词'),
            ),
            TextButton(
              onPressed: saving ? null : onOpenPatchRegeneration,
              child: const Text('局部返工'),
            ),
            TextButton(
              onPressed: saving || promptDiagnostics == null
                  ? null
                  : onApplyPromptRepairs,
              child: const Text('手动应用生成前建议'),
            ),
            TextButton(
              onPressed: saving || loadingWorkbench ? null : onRefreshVideoData,
              child: Text(loadingWorkbench ? '刷新中…' : '手动刷新视频数据'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '默认建议直接点“一键生成视频”。系统会自动补提示词、裁剪低收益片段、压缩重复负向约束并刷新结果；上面这些按钮保留给需要手动干预的场景。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '局部返工只提交最小修复范围；若命中 attribution mode，会返回归因提示，避免把单点问题误当全量重跑。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: autoQualityReviewOnGeneratePrompt,
          onChanged: saving
              ? null
              : (value) =>
                    onAutoQualityReviewOnGeneratePromptChanged(value ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('生成时自动记录质量评审样本'),
          subtitle: const Text('用于统计“命中表演/语气记忆优先策略”的通过率与坏例趋势。'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: videoDescriptionCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '字幕/旁白文案',
            helperText: '导出 SRT、时间线字幕和默认视频提示词会优先使用这里的内容。',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: saving ? null : onSaveVideoDescription,
                child: const Text('保存字幕/旁白文案'),
              ),
              TextButton(
                onPressed: saving ? null : onGenerateVoiceover,
                child: Text(
                  (productionRow?.voiceoverState ?? '').trim() == 'completed'
                      ? '重新生成配音'
                      : '生成配音',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: liveActionReferenceShotsCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '真人参考镜头 URL（每行一条）',
            helperText: '真人模式会把这组参考镜头纳入 readiness；动漫模式可留空。',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: liveActionPerformanceNotesCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '表演 / 口播约束',
            helperText: '例如停顿、情绪强度、镜头真实感、口型同步重点。',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving ? null : onSaveLiveActionReference,
            child: const Text('保存真人参考与表演约束'),
          ),
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
        if (promptDiagnostics != null) ...[
          const SizedBox(height: 6),
          Text(
            buildStoryboardVideoPromptDiagnosticsLine(promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            buildStoryboardVideoPromptSourceSummary(promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            buildStoryboardVideoPromptAnchorSummary(promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            buildStoryboardVideoPromptBudgetHint(promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (repairSuggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '生成前建议：${repairSuggestions.join(' / ')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
        const SizedBox(height: 8),
        TextField(
          controller: negativeVideoPromptCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '负向提示词',
            helperText: '会自动回填当前分镜的失败约束，可按需继续删减或补充。',
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
                decoration: const InputDecoration(labelText: '时长（秒）'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: resolution,
                decoration: const InputDecoration(labelText: '分辨率'),
                items: (modelDetail?.resolutions.isNotEmpty ?? false)
                    ? modelDetail!.resolutions
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
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        onResolutionChanged(value);
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
                initialValue: mode,
                decoration: const InputDecoration(labelText: '生成模式'),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('standard')),
                  DropdownMenuItem(value: 'fast', child: Text('fast')),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        onModeChanged(value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '模型'),
                child: Text(modelDetail?.modelId ?? '等待加载模型信息'),
              ),
            ),
          ],
        ),
        CheckboxListTile(
          value: audio,
          contentPadding: EdgeInsets.zero,
          title: const Text('生成视频时携带音频'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: saving ? null : (value) => onAudioChanged(value ?? false),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: saving ? null : onSubmitVideoGeneration,
                child: Text(saving ? '生成中…' : '一键生成视频'),
              ),
              OutlinedButton(
                onPressed: saving ? null : onExportCurrentVideo,
                child: const Text('导出当前视频（job）'),
              ),
              TextButton(
                onPressed: saving || loadingExportJob
                    ? null
                    : onRefreshExportJob,
                child: Text(loadingExportJob ? '刷新导出任务中…' : '刷新导出任务状态'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '若当前只发现 1 条可用轨道，提交时会自动回填，减少重复填写；存在多条轨道时仍保持手动选择，避免误生成。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        if (latestExportJob != null) ...[
          const SizedBox(height: 8),
          Text(
            '最近导出任务：#${latestExportJob!.numericTaskId} · ${latestExportJob!.status} · ${latestExportJob!.updatedAt}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (resolvedExportUrl != null)
            SelectableText(
              '导出链接：$resolvedExportUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if ((latestExportJob!.errorMessage ?? '').trim().isNotEmpty)
            Text(
              '导出错误：${latestExportJob!.errorMessage}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
        if (workbenchLine != null) ...[
          const SizedBox(height: 8),
          Text(workbenchLine!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Text('当前已选视频', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          hasSelectedVideo
              ? '这条是当前分镜真正会继续导出和复用的视频版本。'
              : '当前还没有已选视频；可先从候选里设为当前，再继续返工或导出。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        if (hasSelectedVideo) ...[
          SelectableText(
            selectedVideoUrl,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: saving ? null : onExportCurrentVideo,
                child: const Text('导出当前视频'),
              ),
              TextButton(
                onPressed: saving ? null : onOpenPatchRegeneration,
                child: const Text('继续局部返工'),
              ),
              TextButton(
                onPressed: saving ? null : onDeleteCurrentVideo,
                child: const Text('删除当前已选视频'),
              ),
            ],
          ),
        ] else
          Text(
            '先从下面的视频候选里选一条更满意的版本，后续返工会更聚焦。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 12),
        Text('当前分镜的视频候选', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          storyboardVideos.isEmpty
              ? '还没有与当前 storyboard 关联的已生成视频。'
              : '优先展示当前 storyboard 的视频结果；可直接设为当前，或继续局部返工。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        ...storyboardVideos.take(3).map((video) {
          final state = video.state ?? '';
          final duration = video.duration ?? '';
          final videoUrl = video.videoUrl?.trim() ?? '';
          final isCurrent = hasSelectedVideo && videoUrl == selectedVideoUrl;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.videoUrl ?? '视频 URL 缺失',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (isCurrent) '当前生效中',
                  if (state.trim().isNotEmpty) '状态 $state',
                  if (video.trackId != null) '轨道 ${video.trackId}',
                  if (duration.trim().isNotEmpty) '时长 $duration',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isCurrent)
                    FilledButton.tonal(
                      onPressed: null,
                      child: const Text('当前已选'),
                    )
                  else
                    TextButton(
                      onPressed: saving || videoUrl.isEmpty
                          ? null
                          : () => onSelectVideo(video),
                      child: const Text('设为当前视频'),
                    ),
                  TextButton(
                    onPressed: saving ? null : onOpenPatchRegeneration,
                    child: Text(isCurrent ? '继续局部返工' : '局部返工'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
            ],
          );
        }),
        if (generateData != null &&
            (generateData!.generatingJobs.isNotEmpty ||
                generateData!.videoWritebackSummary.inFlightGenerationJobCount >
                    0)) ...[
          const SizedBox(height: 8),
          Text('进行中的视频任务', style: Theme.of(context).textTheme.labelLarge),
          Builder(
            builder: (ctx) {
              final s = generateData!.videoWritebackSummary;
              if (s.scriptStoryboardCount == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '成片回写概要：本分镜脚本共 ${s.scriptStoryboardCount} 镜；'
                  '已检测到片媒体路径 ${s.storyboardNumericIdsWithPersistedVideo.length}；'
                  '进行中任务关联 ${s.storyboardNumericIdsWithInFlightGeneration.length} 镜'
                  '${s.storyboardNumericIdsPendingWriteback.isNotEmpty ? '，其中尚未回库的约 ${s.storyboardNumericIdsPendingWriteback.length} 镜（待 worker 完结）' : ''}。',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          ...generateData!.generatingJobs
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
