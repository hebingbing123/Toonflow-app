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
    required this.resolution,
    required this.mode,
    required this.audio,
    required this.autoQualityReviewOnGeneratePrompt,
    required this.modelDetail,
    required this.generateData,
    required this.productionRow,
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
  final String resolution;
  final String mode;
  final bool audio;
  final bool autoQualityReviewOnGeneratePrompt;
  final VideoModelDetail? modelDetail;
  final GetGenerateDataResponse? generateData;
  final ProductionStoryboardItemV1? productionRow;
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
              child: const Text('生成默认视频提示词'),
            ),
            TextButton(
              onPressed: saving || loadingWorkbench ? null : onRefreshVideoData,
              child: Text(loadingWorkbench ? '刷新中…' : '刷新视频数据'),
            ),
          ],
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
          child: TextButton(
            onPressed: saving ? null : onSaveVideoDescription,
            child: const Text('保存字幕/旁白文案'),
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
                child: Text(saving ? '提交中…' : '提交视频生成'),
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
        ...storyboardVideos.take(3).map((video) {
          final state = video.state ?? '';
          final duration = video.duration ?? '';
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              video.videoUrl ?? '视频 URL 缺失',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (state.trim().isNotEmpty) '状态 $state',
                if (video.trackId != null) '轨道 ${video.trackId}',
                if (duration.trim().isNotEmpty) '时长 $duration',
              ].join(' · '),
            ),
            trailing: TextButton(
              onPressed: saving || (video.videoUrl ?? '').trim().isEmpty
                  ? null
                  : () => onSelectVideo(video),
              child: const Text('设为当前视频'),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving ? null : onDeleteCurrentVideo,
            child: const Text('删除当前已选视频'),
          ),
        ),
        if ((generateData?.generatingJobs.isNotEmpty ?? false)) ...[
          const SizedBox(height: 8),
          Text('进行中的视频任务', style: Theme.of(context).textTheme.labelLarge),
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
