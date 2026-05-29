part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionBatchVoiceover on _ShortVideoSpaceSectionState {
  Future<void> _batchGenerateVoiceover({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
  }) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final l10n = resolveAppLocalizationsForErrors(context);

    if (token == null || token.isEmpty || project == null) {
      showFeedback(l10n.shortVideoBatchCannotLoadProject, isSuccess: false);
      return;
    }

    if (selectedStoryboardIds.isEmpty) {
      showFeedback(
        l10n.shortVideoBatchSelectShotsVoiceoverFirst,
        isSuccess: false,
      );
      return;
    }

    // Filter shots that have voiceover script ready
    final eligibleShots = allEntries
        .where(
          (e) =>
              selectedStoryboardIds.contains(e.storyboardNumericId) &&
              e.voiceoverScriptReady,
        )
        .toList();

    if (eligibleShots.isEmpty) {
      showFeedback(
        l10n.shortVideoBatchNoVoiceoverTextSelected,
        isSuccess: false,
      );
      return;
    }

    // Show voiceover settings dialog to configure TTS parameters
    final settings = await _openVoiceoverSettingsDialog(
      context: context,
      initialSettings: _ttsRetrySettings,
    );

    if (settings == null) {
      // User cancelled
      return;
    }
    _ttsRetrySettings = settings;

    final requestShots = eligibleShots
        .map(
          (shot) => TtsGenerateRequestV1(
            projectId: project.id,
            shotId: shot.storyboardId,
            text: shot.subtitleText,
            provider: settings.provider,
            voiceId: settings.voiceId,
            emotion: settings.emotion,
            speed: settings.speed,
          ),
        )
        .toList(growable: false);

    // Show progress dialog
    var totalProcessed = 0;
    var totalSuccessful = 0;
    var totalFailed = 0;
    final failedItems = <BatchOperationFailedItem>[];

    if (!context.mounted) return;

    await showStudioDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final dlgL10n = resolveAppLocalizationsForErrors(ctx);
            final progress = eligibleShots.isEmpty
                ? 0.0
                : totalProcessed / eligibleShots.length;
            final progressPercent = (progress * 100).toStringAsFixed(0);

            return StudioAlertDialog(
              title: Text(dlgL10n.shortVideoBatchGenerateVoiceoverTitle),
              content: SizedBox(
                width: studioConstrainedDialogWidth(context, maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: StudioSpacing.sm),
                    Text(
                      dlgL10n.shortVideoBatchVoiceoverQueueProgress(
                        totalProcessed,
                        eligibleShots.length,
                        progressPercent,
                      ),
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      dlgL10n.shortVideoBatchVoiceoverQueueStats(
                        totalSuccessful,
                        totalFailed,
                      ),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    if (failedItems.isNotEmpty) ...[
                      const SizedBox(height: StudioSpacing.sm),
                      const Divider(),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        dlgL10n.shortVideoBatchVoiceoverQueueFailedHeading,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      SizedBox(
                        height: studioAdaptiveDialogHeight(
                          context,
                          fraction: 0.18,
                          min: 96,
                          max: 200,
                        ),
                        child: ListView.builder(
                          itemCount: failedItems.length,
                          itemBuilder: (ctx, idx) {
                            final item = failedItems[idx];
                            return studioStaggeredItem(
                              idx,
                              entranceKey: failedItems.length,
                              child: Padding(
                              padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
                              child: Text(
                                dlgL10n.shortVideoBatchVoiceoverQueueFailedLine(
                                  item.shotId,
                                  item.errorMessage,
                                ),
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(ctx).colorScheme.error,
                                    ),
                              ),
                            ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (totalProcessed >= eligibleShots.length)
                  FilledButton(
                    style: studioFormPrimaryButtonStyle(ctx),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(dlgL10n.shortVideoBatchVoiceoverQueueDone),
                  )
                else
                  const SizedBox.shrink(),
              ],
            );
          },
        );
      },
    );

    try {
      final response = await postTtsBatchGenerateV1(
        token,
        TtsBatchGenerateRequestV1(projectId: project.id, shots: requestShots),
      );

      totalProcessed = eligibleShots.length;
      totalSuccessful = response.succeeded;
      totalFailed = response.failed;
    } catch (e) {
      if (!context.mounted) return;
      final errorText = describeUserVisibleApiErrorResolved(context, e);
      totalProcessed = eligibleShots.length;
      totalFailed = eligibleShots.length;
      for (final shot in eligibleShots) {
        failedItems.add(
          BatchOperationFailedItem(
            shotId: shot.storyboardNumericId,
            errorMessage: errorText,
          ),
        );
      }
      showFeedback(
        l10n.shortVideoBatchVoiceoverGenFailedError(errorText),
        isSuccess: false,
      );
    }

    // Final feedback
    if (totalFailed == 0) {
      showFeedback(
        l10n.shortVideoBatchVoiceoverDoneJobs(totalSuccessful),
        isSuccess: true,
      );
    } else {
      showFeedback(
        l10n.shortVideoBatchVoiceoverDonePartial(totalSuccessful, totalFailed),
        isSuccess: false,
      );
    }

    // Refresh project data to show updated voiceover status
    await _loadProjectOverview();
  }

  /// Generate voiceover for a single shot
  Future<void> _generateSingleVoiceover({
    required _AssemblyClipDeskOpEntry item,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
  }) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final l10n = resolveAppLocalizationsForErrors(context);

    if (token == null || token.isEmpty || project == null) {
      showFeedback(l10n.shortVideoBatchCannotLoadProject, isSuccess: false);
      return;
    }

    if (!item.voiceoverScriptReady) {
      showFeedback(l10n.shortVideoBatchShotNoVoiceoverText, isSuccess: false);
      return;
    }

    // Show voiceover settings dialog to configure TTS parameters
    final settings = await _openVoiceoverSettingsDialog(
      context: context,
      initialSettings: _ttsRetrySettings,
    );

    if (settings == null) {
      // User cancelled
      return;
    }
    _ttsRetrySettings = settings;

    // Show progress indicator
    if (!context.mounted) return;

    showStudioDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dlgL10n = resolveAppLocalizationsForErrors(dialogContext);
        return StudioAlertDialog(
          content: Row(
            children: [
              StudioAsyncDataView(
                loading: true,
                loadingPlaceholder: StudioLoadingPlaceholder.list,
                loadingItemCount: 1,
                scrollableLoading: false,
                child: Row(
                  children: <Widget>[
                    const StudioRepaintBoundary(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    const SizedBox(width: StudioSpacing.sm),
                    Expanded(
                      child: Text(dlgL10n.shortVideoBatchGeneratingVoiceover),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final response = await postTtsGenerateV1(
        token,
        TtsGenerateRequestV1(
          projectId: project.id,
          shotId: item.storyboardId,
          text: item.subtitleText,
          provider: settings.provider,
          voiceId: settings.voiceId,
          emotion: settings.emotion,
          speed: settings.speed,
        ),
      );

      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (response.taskId.isNotEmpty) {
        showFeedback(
          l10n.shortVideoBatchVoiceoverJobEnqueued(item.storyboardNumericId),
          isSuccess: true,
        );

        // Refresh project data to show updated voiceover status
        await _loadProjectOverview();
      } else {
        showFeedback(
          l10n.shortVideoBatchVoiceoverCouldNotCreateTask,
          isSuccess: false,
        );
      }
    } catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (!context.mounted) return;

      showFeedback(
        l10n.shortVideoBatchVoiceoverSingleFailedError(
          describeUserVisibleApiErrorResolved(context, e),
        ),
        isSuccess: false,
      );
    }
  }

  /// Show batch operation progress dialog
  ///
}
