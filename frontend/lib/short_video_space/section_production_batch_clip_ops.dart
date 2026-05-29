part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionBatchClipOps on _ShortVideoSpaceSectionState {
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
      } catch (e) {
        if (!mounted) return;
        showFeedback(
          l10n.shortVideoBatchEnableFailedError(
            describeUserVisibleApiErrorResolved(context, e),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
      } catch (e) {
        if (!mounted) return;
        showFeedback(
          l10n.shortVideoBatchDisableFailedError(
            describeUserVisibleApiErrorResolved(context, e),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    if (selectedStoryboardIds.isEmpty) {
      showFeedback(l10n.shortVideoBatchSelectShotsDurationFirst, isSuccess: false);
      return;
    }

    // Prompt for duration
    final ctrl = TextEditingController();
    final duration = await showStudioDialog<int>(
      context: context,
      builder: (ctx) {
        final dlgL10n = resolveAppLocalizationsForErrors(ctx);
        return StudioAlertDialog(
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
              style: studioFormPrimaryButtonStyle(ctx),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    if (selectedStoryboardIds.isEmpty) {
      showFeedback(l10n.shortVideoBatchSelectShotsReplaceFirst, isSuccess: false);
      return;
    }

    // Prompt for replacement pattern
    final patternCtrl = TextEditingController();
    final replacementCtrl = TextEditingController();
    final result = await showStudioDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        final dlgL10n = resolveAppLocalizationsForErrors(ctx);
        return StudioAlertDialog(
          title: Text(dlgL10n.shortVideoBatchReplaceDialogTitle),
          content: SizedBox(
            width: studioConstrainedDialogWidth(context, maxWidth: 500),
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
                const SizedBox(height: StudioSpacing.sm),
                TextField(
                  controller: replacementCtrl,
                  decoration: InputDecoration(
                    labelText: dlgL10n.shortVideoBatchReplaceWithLabel,
                    hintText: dlgL10n.shortVideoBatchReplaceWithHint,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
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
              style: studioFormPrimaryButtonStyle(ctx),
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
    } catch (e) {
      if (!context.mounted) return;
      showFeedback(
        l10n.shortVideoBatchReplaceFailedError(
          describeUserVisibleApiErrorResolved(context, e),
        ),
        isSuccess: false,
      );
    }
  }

}
