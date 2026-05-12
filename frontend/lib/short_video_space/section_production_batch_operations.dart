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
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要启用的镜头', isSuccess: false);
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
      showFeedback('所选镜头都没有可用的视频 URL', isSuccess: false);
      return;
    }

    // Show progress dialog if context is provided
    if (dialogContext != null && dialogContext.mounted) {
      await _showBatchOperationProgress(
        context: dialogContext,
        title: '批量启用镜头',
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
            '批量启用完成：成功 $successful 个，失败 $failed 个',
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
          '批量启用完成：成功 ${response.success} 个，失败 ${response.failed} 个',
          isSuccess: response.failed == 0,
        );

        await refreshData();
      } on RustApiException catch (e) {
        showFeedback('批量启用失败：${e.statusCode ?? '-'}', isSuccess: false);
      } catch (e) {
        showFeedback('批量启用失败：$e', isSuccess: false);
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
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要禁用的镜头', isSuccess: false);
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
        title: '批量禁用镜头',
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
            '批量禁用完成：成功 $successful 个，失败 $failed 个',
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
          '批量禁用完成：成功 ${response.success} 个，失败 ${response.failed} 个',
          isSuccess: response.failed == 0,
        );

        await refreshData();
      } on RustApiException catch (e) {
        showFeedback('批量禁用失败：${e.statusCode ?? '-'}', isSuccess: false);
      } catch (e) {
        showFeedback('批量禁用失败：$e', isSuccess: false);
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
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要对齐时长的镜头', isSuccess: false);
      return;
    }

    // Prompt for duration
    final ctrl = TextEditingController();
    final duration = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量时长对齐'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '时长（秒）',
            hintText: '输入 1~300',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final sec = int.tryParse(ctrl.text.trim());
              Navigator.of(ctx).pop(sec);
            },
            child: const Text('对齐并写回'),
          ),
        ],
      ),
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
        title: '批量时长对齐',
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
            '批量时长对齐完成：成功 $successful 个，失败 $failed 个',
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
    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要替换的镜头', isSuccess: false);
      return;
    }

    // Prompt for replacement pattern
    final patternCtrl = TextEditingController();
    final replacementCtrl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量替换视频 URL'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: patternCtrl,
                decoration: const InputDecoration(
                  labelText: '查找模式（支持正则表达式）',
                  hintText: '例如：/v1/',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: replacementCtrl,
                decoration: const InputDecoration(
                  labelText: '替换为',
                  hintText: '例如：/v2/',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '将对所选镜头的视频 URL 执行查找替换操作',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop({
                'pattern': patternCtrl.text.trim(),
                'replacement': replacementCtrl.text.trim(),
              });
            },
            child: const Text('执行替换'),
          ),
        ],
      ),
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
      showFeedback('没有镜头需要替换（未匹配到模式）', isSuccess: false);
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
        '批量替换完成：成功 ${response.success} 个，失败 ${response.failed} 个',
        isSuccess: response.failed == 0,
      );

      await refreshData();
    } on RustApiException catch (e) {
      showFeedback('批量替换失败：${e.statusCode ?? '-'}', isSuccess: false);
    } catch (e) {
      showFeedback('批量替换失败：$e', isSuccess: false);
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

    if (token == null || token.isEmpty || project == null) {
      showFeedback('无法获取项目信息', isSuccess: false);
      return;
    }

    if (selectedStoryboardIds.isEmpty) {
      showFeedback('请先选择要生成配音的镜头', isSuccess: false);
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
      showFeedback('所选镜头都没有可用的配音文本', isSuccess: false);
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
            final progress = eligibleShots.isEmpty
                ? 0.0
                : totalProcessed / eligibleShots.length;
            final progressPercent = (progress * 100).toStringAsFixed(0);

            return AlertDialog(
              title: const Text('批量生成配音'),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    Text(
                      '进度：$totalProcessed / ${eligibleShots.length} ($progressPercent%)',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '成功：$totalSuccessful · 失败：$totalFailed',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                    if (failedItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '失败项：',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                                '分镜 #${item.shotId}: ${item.errorMessage}',
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
                    child: const Text('完成'),
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
            errorMessage: '${e.statusCode ?? "未知错误"}: ${e.message}',
          ),
        );
      }
      showFeedback('批量配音生成失败：${e.statusCode ?? "-"}', isSuccess: false);
    } catch (e) {
      totalProcessed = eligibleShots.length;
      totalFailed = eligibleShots.length;
      for (final shot in eligibleShots) {
        failedItems.add(
          BatchOperationFailedItem(
            shotId: shot.storyboardNumericId,
            errorMessage: e.toString(),
          ),
        );
      }
      showFeedback('批量配音生成失败：$e', isSuccess: false);
    }

    // Final feedback
    if (totalFailed == 0) {
      showFeedback('批量配音生成完成：已为 $totalSuccessful 个镜头入队任务', isSuccess: true);
    } else {
      showFeedback(
        '批量配音生成完成：成功 $totalSuccessful，失败 $totalFailed',
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

    if (token == null || token.isEmpty || project == null) {
      showFeedback('无法获取项目信息', isSuccess: false);
      return;
    }

    if (!item.voiceoverScriptReady) {
      showFeedback('该镜头没有可用的配音文本', isSuccess: false);
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
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在生成配音...'),
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
          '分镜 #${item.storyboardNumericId} 配音生成任务已入队',
          isSuccess: true,
        );

        // Refresh project data to show updated voiceover status
        await _loadProjectOverview();
      } else {
        showFeedback('配音生成失败：未能创建任务', isSuccess: false);
      }
    } on RustApiException catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      showFeedback(
        '配音生成失败：${e.statusCode ?? "-"} - ${e.message}',
        isSuccess: false,
      );
    } catch (e) {
      // Close progress dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      showFeedback('配音生成失败：$e', isSuccess: false);
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
                  final errorMessage = e is RustApiException
                      ? '错误代码: ${e.statusCode ?? '-'}'
                      : e.toString();
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
                          title: '$title（重试）',
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
