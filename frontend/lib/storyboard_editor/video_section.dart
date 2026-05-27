part of '../../home_page.dart';

/// Video workbench section extracted from [_StoryboardWorkbenchPanel] to keep
/// individual part files ≤800 lines.
class _StoryboardVideoSection extends StatelessWidget {
  const _StoryboardVideoSection({
    required this.projectId,
    required this.accessToken,
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
    required this.onVideoEstimateChanged,
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

  final String projectId;
  final String accessToken;
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
  final ValueChanged<BillingEstimateResponse?> onVideoEstimateChanged;
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

  String _storyboardResolutionMenuLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case '1080p':
        return l10n.storyboardVideoWorkbenchResolution1080p;
      case '720p':
        return l10n.storyboardVideoWorkbenchResolution720p;
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final latestExportUrl = (latestExportJob?.result?['export_url'] as String?)
        ?.trim();
    final resolvedExportUrl =
        latestExportUrl != null && latestExportUrl.isNotEmpty
        ? resolveRustApiUrl(latestExportUrl)
        : null;
    final repairSuggestions = promptDiagnostics == null
        ? const <String>[]
        : buildStoryboardVideoPromptRepairSuggestions(l10n, promptDiagnostics!);
    final selectedVideoUrl = currentSelectedVideoUrl?.trim() ?? '';
    final hasSelectedVideo = selectedVideoUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.storyboardVideoWorkbenchTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: trackIdCtrl,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchTrackIdLabel,
            helperText: knownTrackIds.isEmpty
                ? l10n.storyboardVideoWorkbenchTrackIdHelperNoTracks
                : l10n.storyboardVideoWorkbenchTrackIdHelperKnown(
                    knownTrackIds.join(', '),
                  ),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: trackNameCtrl,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchNewTrackNameLabel,
            helperText: l10n.storyboardVideoWorkbenchNewTrackNameHelper,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: saving ? null : onAddTrack,
              child: Text(l10n.storyboardVideoWorkbenchAddTrack),
            ),
            TextButton(
              onPressed: saving ? null : onDeleteTrack,
              child: Text(l10n.storyboardVideoWorkbenchDeleteTrack),
            ),
            TextButton(
              onPressed: saving ? null : onGenerateVideoPrompt,
              child: Text(l10n.storyboardVideoWorkbenchGenerateDefaultPrompt),
            ),
            TextButton(
              onPressed: saving ? null : onOpenPatchRegeneration,
              child: Text(l10n.storyboardVideoWorkbenchPatchRegeneration),
            ),
            TextButton(
              onPressed: saving || promptDiagnostics == null
                  ? null
                  : onApplyPromptRepairs,
              child: Text(l10n.storyboardVideoWorkbenchApplyPromptRepairs),
            ),
            TextButton(
              onPressed: saving || loadingWorkbench ? null : onRefreshVideoData,
              child: Text(
                loadingWorkbench
                    ? l10n.storyboardVideoWorkbenchRefreshing
                    : l10n.storyboardVideoWorkbenchRefreshVideoDataManual,
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.storyboardVideoWorkbenchPrimaryHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.storyboardVideoWorkbenchPatchAttributionHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: studioPanelMutedColor(context),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioCheckboxListRow(
          value: autoQualityReviewOnGeneratePrompt,
          onChanged: saving
              ? null
              : (value) =>
                    onAutoQualityReviewOnGeneratePromptChanged(value ?? false),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.storyboardVideoWorkbenchQualityReviewCheckboxTitle),
          subtitle: Text(
            l10n.storyboardVideoWorkbenchQualityReviewCheckboxSubtitle,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: videoDescriptionCtrl,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchSubtitleLabel,
            helperText: l10n.storyboardVideoWorkbenchSubtitleHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            TextButton(
              onPressed: saving ? null : onSaveVideoDescription,
              child: Text(l10n.storyboardVideoWorkbenchSaveSubtitle),
            ),
            TextButton(
              onPressed: saving ? null : onGenerateVoiceover,
              child: Text(
                (productionRow?.voiceoverState ?? '').trim() == 'completed'
                    ? l10n.storyboardVideoWorkbenchRegenerateVoiceover
                    : l10n.storyboardVideoWorkbenchGenerateVoiceover,
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: liveActionReferenceShotsCtrl,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchLiveActionRefsLabel,
            helperText: l10n.storyboardVideoWorkbenchLiveActionRefsHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: liveActionPerformanceNotesCtrl,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchPerformanceNotesLabel,
            helperText: l10n.storyboardVideoWorkbenchPerformanceNotesHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving ? null : onSaveLiveActionReference,
            child: Text(l10n.storyboardVideoWorkbenchSaveLiveAction),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: videoPromptCtrl,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchVideoPromptLabel,
            alignLabelWithHint: true,
          ),
        ),
        if (promptDiagnostics != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          Text(
            buildStoryboardVideoPromptDiagnosticsLine(l10n, promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            buildStoryboardVideoPromptSourceSummary(l10n, promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: studioPanelMutedColor(context),
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            buildStoryboardVideoPromptAnchorSummary(l10n, promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: studioPanelMutedColor(context),
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            buildStoryboardVideoPromptBudgetHint(l10n, promptDiagnostics!),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (repairSuggestions.isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.storyboardVideoWorkbenchRepairSuggestionsPrefix(
                repairSuggestions.join(' / '),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: negativeVideoPromptCtrl,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l10n.storyboardVideoWorkbenchNegativePromptLabel,
            helperText: l10n.storyboardVideoWorkbenchNegativePromptHelper,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: videoDurationCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.storyboardVideoWorkbenchDurationSecondsLabel,
                ),
              ),
            ),
            const SizedBox(width: StudioSpacing.sm),
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: resolution,
                decoration: InputDecoration(
                  labelText: l10n.storyboardVideoWorkbenchResolutionLabel,
                ),
                items: (modelDetail?.resolutions.isNotEmpty ?? false)
                    ? modelDetail!.resolutions
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                _storyboardResolutionMenuLabel(l10n, item),
                              ),
                            ),
                          )
                          .toList(growable: false)
                    : [
                        DropdownMenuItem(
                          value: '1080p',
                          child: Text(
                            l10n.storyboardVideoWorkbenchResolution1080p,
                          ),
                        ),
                        DropdownMenuItem(
                          value: '720p',
                          child: Text(
                            l10n.storyboardVideoWorkbenchResolution720p,
                          ),
                        ),
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
        const SizedBox(height: StudioSpacing.xs),
        Row(
          children: [
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: mode,
                decoration: InputDecoration(
                  labelText: l10n.storyboardVideoWorkbenchModeLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'standard',
                    child: Text(l10n.storyboardVideoWorkbenchModeStandard),
                  ),
                  DropdownMenuItem(
                    value: 'fast',
                    child: Text(l10n.storyboardVideoWorkbenchModeFast),
                  ),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        onModeChanged(value);
                      },
              ),
            ),
            const SizedBox(width: StudioSpacing.sm),
            Expanded(
              child: StudioModelCostControls(
                accessToken: accessToken,
                projectUuid: projectId,
                studioStepSlug: 'storyboard',
                modelSlot: 'video',
                taskKind: 'storyboard_video',
                typeFilter: 'video',
                quantity: int.tryParse(videoDurationCtrl.text.trim()) ?? 5,
                enabled: !saving,
                onEstimateChanged: onVideoEstimateChanged,
              ),
            ),
          ],
        ),
        StudioCheckboxListRow(
          value: audio,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.storyboardVideoWorkbenchIncludeAudioTitle),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: saving ? null : (value) => onAudioChanged(value ?? false),
        ),
        StudioDenseActionRow(
          spacing: StudioSpacing.xs,
          children: [
            FilledButton(
              style: studioFormPrimaryButtonStyle(context),
              onPressed: saving ? null : onSubmitVideoGeneration,
              child: Text(
                saving
                    ? l10n.storyboardVideoWorkbenchGenerating
                    : l10n.storyboardVideoWorkbenchGenerateVideoOneClick,
              ),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: saving ? null : onExportCurrentVideo,
              child: Text(l10n.storyboardVideoWorkbenchExportCurrentVideoJob),
            ),
            TextButton(
              onPressed: saving || loadingExportJob
                  ? null
                  : onRefreshExportJob,
              child: Text(
                loadingExportJob
                    ? l10n.storyboardVideoWorkbenchRefreshingExportJob
                    : l10n.storyboardVideoWorkbenchRefreshExportJobStatus,
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.storyboardVideoWorkbenchSingleTrackHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: studioPanelMutedColor(context),
          ),
        ),
        if (latestExportJob != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.storyboardVideoWorkbenchLatestExportJobLine(
              latestExportJob!.numericTaskId,
              latestExportJob!.status,
              latestExportJob!.updatedAt,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (resolvedExportUrl != null)
            SelectableText(
              '${l10n.storyboardVideoWorkbenchExportLinkPrefix} $resolvedExportUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if ((latestExportJob!.errorMessage ?? '').trim().isNotEmpty)
            Text(
              '${l10n.storyboardVideoWorkbenchExportErrorPrefix} ${latestExportJob!.errorMessage}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
        if (workbenchLine != null) ...[
          const SizedBox(height: StudioSpacing.xs),
          Text(workbenchLine!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: StudioSpacing.sm),
        Text(
          l10n.storyboardVideoWorkbenchSelectedVideoHeading,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          hasSelectedVideo
              ? l10n.storyboardVideoWorkbenchSelectedVideoDetailSelected
              : l10n.storyboardVideoWorkbenchSelectedVideoDetailEmpty,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: studioPanelMutedColor(context),
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        if (hasSelectedVideo) ...[
          SelectableText(
            selectedVideoUrl,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioDenseActionRow(
            spacing: StudioSpacing.xs,
            children: [
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: saving ? null : onExportCurrentVideo,
                child: Text(l10n.storyboardVideoWorkbenchExportSelectedVideo),
              ),
              TextButton(
                onPressed: saving ? null : onOpenPatchRegeneration,
                child: Text(l10n.storyboardVideoWorkbenchContinuePatch),
              ),
              TextButton(
                onPressed: saving ? null : onDeleteCurrentVideo,
                child: Text(l10n.storyboardVideoWorkbenchDeleteSelectedVideo),
              ),
            ],
          ),
        ] else
          Text(
            l10n.storyboardVideoWorkbenchPickCandidateFirst,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          l10n.storyboardVideoWorkbenchCandidatesHeading,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: StudioSpacing.xs),
        if (storyboardVideos.isEmpty)
          StudioEmptyState.emptyData(
            title: l10n.storyboardVideoWorkbenchCandidatesEmpty,
          )
        else ...<Widget>[
          Text(
            l10n.storyboardVideoWorkbenchCandidatesDetail,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioSpacing.xs),
          ...storyboardVideos.take(3).map((video) {
          final state = video.state ?? '';
          final duration = video.duration ?? '';
          final videoUrl = video.videoUrl?.trim() ?? '';
          final isCurrent = hasSelectedVideo && videoUrl == selectedVideoUrl;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.videoUrl ?? l10n.storyboardVideoWorkbenchVideoUrlMissing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                [
                  if (isCurrent)
                    l10n.storyboardVideoWorkbenchCandidateMetaCurrent,
                  if (state.trim().isNotEmpty)
                    l10n.storyboardVideoWorkbenchCandidateMetaState(
                      state.trim(),
                    ),
                  if (video.trackId != null)
                    l10n.storyboardVideoWorkbenchCandidateMetaTrack(
                      video.trackId!,
                    ),
                  if (duration.trim().isNotEmpty)
                    l10n.storyboardVideoWorkbenchCandidateMetaDuration(
                      duration.trim(),
                    ),
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDenseActionRow(
                spacing: StudioSpacing.xs,
                children: [
                  if (isCurrent)
                    FilledButton.tonal(
                      style: studioFormTonalButtonStyle(context),
                      onPressed: null,
                      child: Text(
                        l10n.storyboardVideoWorkbenchCurrentSelectedBadge,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: saving || videoUrl.isEmpty
                          ? null
                          : () => onSelectVideo(video),
                      child: Text(
                        l10n.storyboardVideoWorkbenchSetAsCurrentVideo,
                      ),
                    ),
                  TextButton(
                    onPressed: saving ? null : onOpenPatchRegeneration,
                    child: Text(
                      isCurrent
                          ? l10n.storyboardVideoWorkbenchPatchContinue
                          : l10n.storyboardVideoWorkbenchPatchShort,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              const Divider(height: 1),
              const SizedBox(height: StudioSpacing.xs),
            ],
          );
        }),
        ],
        if (generateData != null &&
            (generateData!.generatingJobs.isNotEmpty ||
                generateData!.videoWritebackSummary.inFlightGenerationJobCount >
                    0)) ...[
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.storyboardVideoWorkbenchInFlightJobsHeading,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Builder(
            builder: (ctx) {
              final s = generateData!.videoWritebackSummary;
              if (s.scriptStoryboardCount == 0) {
                return const SizedBox.shrink();
              }
              final pending = s.storyboardNumericIdsPendingWriteback;
              final summaryText = pending.isEmpty
                  ? l10n.storyboardVideoWorkbenchWritebackSummaryNoPending(
                      s.scriptStoryboardCount,
                      s.storyboardNumericIdsWithPersistedVideo.length,
                      s.storyboardNumericIdsWithInFlightGeneration.length,
                    )
                  : l10n.storyboardVideoWorkbenchWritebackSummaryWithPending(
                      s.scriptStoryboardCount,
                      s.storyboardNumericIdsWithPersistedVideo.length,
                      s.storyboardNumericIdsWithInFlightGeneration.length,
                      pending.length,
                    );
              return Padding(
                padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                child: Text(
                  summaryText,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              );
            },
          ),
          const SizedBox(height: StudioSpacing.xs),
          ...generateData!.generatingJobs
              .take(3)
              .map(
                (job) => StudioListRow(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(job.kind),
                  subtitle: Text(
                    l10n.storyboardVideoWorkbenchJobSubtitle(
                      job.status,
                      job.updatedAt,
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
