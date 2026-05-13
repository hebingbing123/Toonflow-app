// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

/// Batch operations for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionBatchOperationsExtension
    on _ShortVideoSpaceSectionState {
  /// Batch enable selected shots
  Future<void> _batchEnableShots({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required String projectUuid,
    required int scriptId,
    required String token,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
    BuildContext? dialogContext,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedStoryboardIds.isEmpty) {
      showFeedback(l10n.shortVideoBatchSelectShotsToEnableFirst, isSuccess: false);
      return;
    }

    // Build operations list - only include shots that have video URLs
    final operations = <Map<String, dynamic>>[];
    for (final storyboardId in selectedStoryboardIds) {
      final entry = allEntries.firstWhere(
        (e) => e.storyboardNumericId == storyboardId,
        orElse: () => throw Exception('Shot not found: $storyboardId'),
      );

      if (entry.selectedMediaUrl.trim().isEmpty) {
        // Skip shots without video URLs
        continue;
      }

      operations.add({
        'storyboardId': storyboardId,
        'videoUrl': entry.selectedMediaUrl,
      });
    }

    if (operations.isEmpty) {
      showFeedback(
        l10n.shortVideoBatchNoShotsWithVideoUrl,
        isSuccess: false,
      );
      return;
    }

    // Show progress dialog if context is provided
    if (dialogContext != null && dialogContext.mounted) {
      await _showBatchOperationProgress(
        context: dialogContext,
        title: l10n.shortVideoBatchEnableTitle,
        operations: operations,
        executeOperation: (operation) async {
          await postWorkbenchSelectVideoV1(
            token,
            projectUuid: projectUuid,
            scriptId: scriptId,
            storyboardId: operation['storyboardId'] as int,
            videoUrl: operation['videoUrl'] as String,
          );
        },
        onComplete: (successful, failed, failedItems) async {
          showFeedback(
            l10n.shortVideoBatchEnableFinished(successful, failed),
            isSuccess: failed == 0,
          );
          await refreshData();
        },
      );
    } else {
      // Fallback to old behavior if no context
      try {
        final response = await postProductionWorkbenchBatchSelectVideoV1(
          token,
          projectUuid: projectUuid,
          scriptId: scriptId,
          operations: operations,
        );

        showFeedback(
          l10n.shortVideoBatchEnableFinished(response.success, response.failed),
          isSuccess: response.failed == 0,
        );

        await refreshData();
      } on RustApiException catch (e) {
        showFeedback(
          l10n.shortVideoBatchEnableFailedError(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      } catch (e) {
        showFeedback(
          l10n.shortVideoBatchEnableFailedError(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      }
    }
  }

  /// Batch disable selected shots
  Future<void> _batchDisableShots({
    required Set<int> selectedStoryboardIds,
    required String projectUuid,
    required int scriptId,
    required String token,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
    BuildContext? dialogContext,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedStoryboardIds.isEmpty) {
      showFeedback(l10n.shortVideoBatchSelectShotsToDisableFirst, isSuccess: false);
      return;
    }

    // Show confirmation dialog
    if (dialogContext != null && dialogContext.mounted) {
      final confirmed = await showBatchDisableConfirmation(
        dialogContext,
        shotCount: selectedStoryboardIds.length,
        showDontShowAgain: true,
      );

      if (confirmed != true) {
        return;
      }
    }

    // Build operations list
    final operations = selectedStoryboardIds
        .map((id) => {'storyboardId': id})
        .toList();

    // Show progress dialog if context is provided
    if (dialogContext != null && dialogContext.mounted) {
      await _showBatchOperationProgress(
        context: dialogContext,
        title: l10n.shortVideoBatchDisableTitle,
        operations: operations,
        executeOperation: (operation) async {
          await postWorkbenchDeleteVideoV1(
            token,
            projectUuid: projectUuid,
            scriptId: scriptId,
            storyboardId: operation['storyboardId'] as int,
          );
        },
        onComplete: (successful, failed, failedItems) async {
          showFeedback(
            l10n.shortVideoBatchDisableFinished(successful, failed),
            isSuccess: failed == 0,
          );
          await refreshData();
        },
      );
    } else {
      // Fallback to old behavior if no context
      try {
        final response = await postProductionWorkbenchBatchDeleteVideoV1(
          token,
          projectUuid: projectUuid,
          scriptId: scriptId,
          storyboardIds: selectedStoryboardIds.toList(),
        );

        showFeedback(
          l10n.shortVideoBatchDisableFinished(response.success, response.failed),
          isSuccess: response.failed == 0,
        );

        await refreshData();
      } on RustApiException catch (e) {
        showFeedback(
          l10n.shortVideoBatchDisableFailedError(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      } catch (e) {
        showFeedback(
          l10n.shortVideoBatchDisableFailedError(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      }
    }
  }

  /// Batch update duration for selected shots
  Future<void> _batchUpdateDuration({
    required Set<int> selectedStoryboardIds,
    required String projectUuid,
    required int scriptId,
    required String token,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedStoryboardIds.isEmpty) {
      showFeedback(l10n.shortVideoBatchSelectShotsDurationFirst, isSuccess: false);
      return;
    }

    // Prompt for duration
    final ctrl = TextEditingController();
    final duration = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final dlgL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dlgL10n.shortVideoBatchDurationDialogTitle),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: dlgL10n.shortVideoBatchDurationLabel,
              hintText: dlgL10n.shortVideoBatchDurationHint,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dlgL10n.storyboardEditorDialogCancel),
            ),
            FilledButton(
              onPressed: () {
                final sec = int.tryParse(ctrl.text.trim());
                Navigator.of(ctx).pop(sec);
              },
              child: Text(dlgL10n.shortVideoBatchAlignAndSave),
            ),
          ],
        );
      },
    );
    ctrl.dispose();

    if (duration == null || duration <= 0 || duration > 300) {
      return;
    }

    // Build operations list
    final operations = selectedStoryboardIds
        .map((id) => {'storyboardId': id, 'duration': duration})
        .toList();

    // Show progress dialog
    if (context.mounted) {
      await _showBatchOperationProgress(
        context: context,
        title: l10n.shortVideoBatchDurationProgressTitle,
        operations: operations,
        executeOperation: (operation) async {
          await postStoryboardUpdateDurationV1(
            token,
            projectUuid: projectUuid,
            scriptId: scriptId,
            storyboardId: operation['storyboardId'] as int,
            duration: operation['duration'] as int,
          );
        },
        onComplete: (successful, failed, failedItems) async {
          showFeedback(
            l10n.shortVideoBatchDurationFinished(successful, failed),
            isSuccess: failed == 0,
          );
          await refreshData();
        },
      );
    }
  }

  /// Batch replace videos for selected shots
  Future<void> _batchReplaceVideos({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required String projectUuid,
    required int scriptId,
    required String token,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
    required Future<void> Function() refreshData,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (selectedStoryboardIds.isEmpty) {
      showFeedback(l10n.shortVideoBatchSelectShotsReplaceFirst, isSuccess: false);
      return;
    }

    // Prompt for replacement pattern
    final patternCtrl = TextEditingController();
    final replacementCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final dlgL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(dlgL10n.shortVideoBatchReplaceDialogTitle),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: patternCtrl,
                  decoration: InputDecoration(
                    labelText: dlgL10n.shortVideoBatchReplaceFindPatternLabel,
                    hintText: dlgL10n.shortVideoBatchReplaceFindPatternHint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replacementCtrl,
                  decoration: InputDecoration(
                    labelText: dlgL10n.shortVideoBatchReplaceWithLabel,
                    hintText: dlgL10n.shortVideoBatchReplaceWithHint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dlgL10n.shortVideoBatchReplaceUrlDescription,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(dlgL10n.storyboardEditorDialogCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop({
                  'pattern': patternCtrl.text.trim(),
                  'replacement': replacementCtrl.text.trim(),
                });
              },
              child: Text(dlgL10n.shortVideoBatchApplyReplacement),
            ),
          ],
        );
      },
    );
    patternCtrl.dispose();
    replacementCtrl.dispose();

    if (result == null || result['pattern']!.isEmpty) {
      return;
    }

    final pattern = result['pattern']!;
    final replacement = result['replacement']!;

    // Build operations list
    final operations = <Map<String, dynamic>>[];
    for (final storyboardId in selectedStoryboardIds) {
      final entry = allEntries.firstWhere(
        (e) => e.storyboardNumericId == storyboardId,
        orElse: () => throw Exception('Shot not found: $storyboardId'),
      );

      if (entry.selectedMediaUrl.trim().isEmpty) {
        continue;
      }

      // Apply replacement
      String newUrl;
      try {
        final regex = RegExp(pattern);
        newUrl = entry.selectedMediaUrl.replaceAll(regex, replacement);
      } catch (e) {
        // If regex fails, try simple string replacement
        newUrl = entry.selectedMediaUrl.replaceAll(pattern, replacement);
      }

      if (newUrl != entry.selectedMediaUrl) {
        operations.add({'storyboardId': storyboardId, 'videoUrl': newUrl});
      }
    }

    if (operations.isEmpty) {
      showFeedback(
        l10n.shortVideoBatchReplaceNoMatch,
        isSuccess: false,
      );
      return;
    }

    try {
      final response = await postProductionWorkbenchBatchSelectVideoV1(
        token,
        projectUuid: projectUuid,
        scriptId: scriptId,
        operations: operations,
      );

      showFeedback(
        l10n.shortVideoBatchReplaceFinished(response.success, response.failed),
        isSuccess: response.failed == 0,
      );

      await refreshData();
    } on RustApiException catch (e) {
      showFeedback(
        l10n.shortVideoBatchReplaceFailedError(
          describeUserVisibleApiError(l10n, e),
        ),
        isSuccess: false,
      );
    } catch (e) {
      showFeedback(
        l10n.shortVideoBatchReplaceFailedError(
          describeUserVisibleApiError(l10n, e),
        ),
        isSuccess: false,
      );
    }
  }

  /// Batch generate voiceover for selected shots
  Future<void> _batchGenerateVoiceover({
    required Set<int> selectedStoryboardIds,
    required List<_AssemblyClipDeskOpEntry> allEntries,
    required BuildContext context,
    required Function(String message, {required bool isSuccess}) showFeedback,
  }) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final l10n = AppLocalizations.of(context)!;

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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final dlgL10n = AppLocalizations.of(ctx)!;
            final progress = eligibleShots.isEmpty
                ? 0.0
                : totalProcessed / eligibleShots.length;
            final progressPercent = (progress * 100).toStringAsFixed(0);

            return AlertDialog(
              title: Text(dlgL10n.shortVideoBatchGenerateVoiceoverTitle),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    Text(
                      dlgL10n.shortVideoBatchVoiceoverQueueProgress(
                        totalProcessed,
                        eligibleShots.length,
                        progressPercent,
                      ),
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dlgL10n.shortVideoBatchVoiceoverQueueStats(
                        totalSuccessful,
                        totalFailed,
                      ),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    if (failedItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        dlgL10n.shortVideoBatchVoiceoverQueueFailedHeading,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: failedItems.length,
                          itemBuilder: (ctx, idx) {
                            final item = failedItems[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
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
    } on RustApiException catch (e) {
      totalProcessed = eligibleShots.length;
      totalFailed = eligibleShots.length;
      for (final shot in eligibleShots) {
        failedItems.add(
          BatchOperationFailedItem(
            shotId: shot.storyboardNumericId,
            errorMessage: describeUserVisibleApiError(l10n, e),
          ),
        );
      }
      showFeedback(
        l10n.shortVideoBatchVoiceoverGenFailedError(
          describeUserVisibleApiError(l10n, e),
        ),
        isSuccess: false,
      );
    } catch (e) {
      totalProcessed = eligibleShots.length;
      totalFailed = eligibleShots.length;
      for (final shot in eligibleShots) {
        failedItems.add(
          BatchOperationFailedItem(
            shotId: shot.storyboardNumericId,
            errorMessage: describeUserVisibleApiError(l10n, e),
          ),
        );
      }
      showFeedback(
        l10n.shortVideoBatchVoiceoverGenFailedError(
          describeUserVisibleApiError(l10n, e),
        ),
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
    final l10n = AppLocalizations.of(context)!;

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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final dlgL10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(dlgL10n.shortVideoBatchGeneratingVoiceover)),
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
    } on RustApiException catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      showFeedback(
        l10n.shortVideoBatchVoiceoverSingleFailedError(
          describeUserVisibleApiError(l10n, e),
        ),
        isSuccess: false,
      );
    } catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      showFeedback(
        l10n.shortVideoBatchVoiceoverSingleFailedError(
          describeUserVisibleApiError(l10n, e),
        ),
        isSuccess: false,
      );
    }
  }

  /// Show batch operation progress dialog
  ///
  /// Executes operations one by one and displays real-time progress
  Future<void> _showBatchOperationProgress({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> operations,
    required Future<void> Function(Map<String, dynamic> operation)
    executeOperation,
    required Future<void> Function(
      int successful,
      int failed,
      List<BatchOperationFailedItem> failedItems,
    )
    onComplete,
  }) async {
    var completed = 0;
    var successful = 0;
    var failed = 0;
    final failedItems = <BatchOperationFailedItem>[];
    var isCancelled = false;
    final l10n = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // Execute operations asynchronously
            Future<void> executeOperations() async {
              for (final operation in operations) {
                if (isCancelled) break;

                try {
                  await executeOperation(operation);
                  successful++;
                } catch (e) {
                  failed++;
                  final storyboardId = operation['storyboardId'] as int;
                  final errorMessage = describeUserVisibleApiError(l10n, e);
                  failedItems.add(
                    BatchOperationFailedItem(
                      shotId: storyboardId,
                      errorMessage: errorMessage,
                    ),
                  );
                }

                completed++;
                if (ctx.mounted) {
                  setState(() {});
                }
              }

              // Call onComplete callback
              await onComplete(successful, failed, failedItems);
            }

            // Start execution if not already started
            if (completed == 0 && !isCancelled) {
              executeOperations();
            }

            final isComplete = completed >= operations.length || isCancelled;

            return BatchOperationProgressDialog(
              title: title,
              total: operations.length,
              completed: completed,
              successful: successful,
              failed: failed,
              failedItems: failedItems,
              isComplete: isComplete,
              onCancel: isComplete
                  ? null
                  : () {
                      setState(() {
                        isCancelled = true;
                      });
                    },
              onRetryFailed: failedItems.isEmpty
                  ? null
                  : () async {
                      // Close current dialog
                      Navigator.of(ctx).pop();

                      // Retry failed operations
                      final retryOperations = failedItems
                          .map(
                            (item) => operations.firstWhere(
                              (op) => op['storyboardId'] == item.shotId,
                            ),
                          )
                          .toList();

                      if (context.mounted) {
                        await _showBatchOperationProgress(
                          context: context,
                          title: l10n.shortVideoBatchOperationRetryTitle(title),
                          operations: retryOperations,
                          executeOperation: executeOperation,
                          onComplete: onComplete,
                        );
                      }
                    },
            );
          },
        );
      },
    );
  }
}
