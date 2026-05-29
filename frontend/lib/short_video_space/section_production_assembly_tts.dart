part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionAssemblyTts on _ShortVideoSpaceSectionState {
  Future<void> _openTtsTaskCenterDialog({
    required BuildContext context,
    required String token,
    required String projectId,
    required List<_AssemblyClipDeskOpEntry> entries,
  }) async {
    final shotNumericById = <String, int>{
      for (final item in entries)
        if (item.storyboardId.trim().isNotEmpty)
          item.storyboardId: item.storyboardNumericId,
    };
    final scriptByShotNumeric = <int, int>{
      for (final item in entries)
        item.storyboardNumericId: item.scriptNumericId,
    };
    var tasks = const <TtsTaskV1>[];
    var loading = true;
    var requestBusy = false;
    var statusFilter = _ttsTaskCenterStatusFilter;
    var groupedByShot = _ttsTaskCenterGroupedByShot;
    var keyword = _ttsTaskCenterKeyword;
    String? errorMessage;
    StateSetter? updateDialogState;
    Timer? poller;

    try {
      await showStudioDialog<void>(
        context: context,
        builder: (dialogContext) {
          final dialogL10n = resolveAppLocalizationsForErrors(dialogContext);

          Future<void> loadTasks() async {
            final setState = updateDialogState;
            if (setState == null) return;
            setState(() {
              loading = true;
            });
            try {
              final next = await getTtsTasksV1(
                token,
                projectId: projectId,
                status: statusFilter.isEmpty ? null : statusFilter,
                limit: 100,
                offset: 0,
              );
              setState(() {
                tasks = next;
                errorMessage = null;
                loading = false;
              });
            } catch (e) {
              setState(() {
                errorMessage = dialogL10n
                    .shortVideoSpaceProductionAssemblyLoadFailed(
                      describeUserVisibleApiErrorResolved(dialogContext, e),
                    );
                loading = false;
              });
            }
          }

          return StatefulBuilder(
            builder: (ctx, setState) {
              updateDialogState = setState;
              final l10n = dialogL10n;
              StudioScheduler.scheduleOnceUntil('tts_task_center_poll', () {
                poller ??= Timer.periodic(
                  const Duration(seconds: 4),
                  (_) => unawaited(loadTasks()),
                );
              });
              StudioScheduler.scheduleOnceUntil(
                'tts_task_center_initial_load',
                () {
                  if (tasks.isEmpty && loading && errorMessage == null) {
                    unawaited(loadTasks());
                  }
                },
              );
              final latestTaskByShotId = <String, TtsTaskV1>{};
              if (!loading && groupedByShot) {
                for (final task in tasks) {
                  final shotId = (task.shotId ?? '').trim();
                  if (shotId.isEmpty) continue;
                  final current = latestTaskByShotId[shotId];
                  if (current == null ||
                      current.updatedAt.isBefore(task.updatedAt)) {
                    latestTaskByShotId[shotId] = task;
                  }
                }
              }
              final visibleTasks = groupedByShot
                  ? latestTaskByShotId.values.toList(growable: false)
                  : tasks;
              bool matchesKeyword(TtsTaskV1 task) {
                final q = keyword.trim().toLowerCase();
                if (q.isEmpty) return true;
                final taskIdHit = task.taskId.toLowerCase().contains(q);
                final shotNumeric = task.shotId == null
                    ? null
                    : shotNumericById[task.shotId!];
                final scriptNumeric = shotNumeric == null
                    ? null
                    : scriptByShotNumeric[shotNumeric];
                final shotHit = shotNumeric?.toString().contains(q) == true;
                final scriptHit = scriptNumeric?.toString().contains(q) == true;
                return taskIdHit || shotHit || scriptHit;
              }

              final filteredTasks = visibleTasks
                  .where(matchesKeyword)
                  .toList(growable: false);
              final retryableFilteredTasks = filteredTasks
                  .where(
                    (task) =>
                        task.status == 'failed' &&
                        task.taskId.trim().isNotEmpty,
                  )
                  .toList(growable: false);
              return StudioAlertDialog(
                title: Text(
                  l10n.shortVideoSpaceProductionAssemblyVoiceoverTaskCenterTitle,
                ),
                content: SizedBox(
                  width: studioConstrainedDialogWidth(context, maxWidth: 760),
                  height: studioAdaptiveDialogHeight(
                    context,
                    fraction: 0.52,
                    min: 300,
                    max: 520,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StudioDropdownButton<String>(
                            value: statusFilter,
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(
                                  l10n.shortVideoSpaceProductionAssemblyAllStatus,
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'queued',
                                child: Text(
                                  shortVideoPublishJobStatusLabel(
                                    l10n,
                                    'queued',
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'running',
                                child: Text(
                                  shortVideoPublishJobStatusLabel(
                                    l10n,
                                    'running',
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'succeeded',
                                child: Text(
                                  shortVideoPublishJobStatusLabel(
                                    l10n,
                                    'succeeded',
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'failed',
                                child: Text(
                                  shortVideoPublishJobStatusLabel(
                                    l10n,
                                    'failed',
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'cancelled',
                                child: Text(
                                  shortVideoPublishJobStatusLabel(
                                    l10n,
                                    'cancelled',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: requestBusy
                                ? null
                                : (next) {
                                    setState(() {
                                      statusFilter = next ?? '';
                                      _ttsTaskCenterStatusFilter = statusFilter;
                                    });
                                    unawaited(loadTasks());
                                  },
                          ),
                          const SizedBox(width: StudioSpacing.xs),
                          StudioDebouncedAction(
                            enabled: !loading && !requestBusy,
                            onPressed: (loading || requestBusy)
                                ? null
                                : () async => loadTasks(),
                            builder: (context, onPressed) => OutlinedButton.icon(
                              onPressed: onPressed,
                              icon: const Icon(Icons.refresh_outlined),
                              label: Text(
                                l10n.shortVideoSpaceProductionAssemblyRefresh,
                              ),
                            ),
                          ),
                          const SizedBox(width: StudioSpacing.xs),
                          FilterChip(
                            selected: groupedByShot,
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyGroupByShot,
                            ),
                            onSelected: requestBusy
                                ? null
                                : (selected) {
                                    setState(() {
                                      groupedByShot = selected;
                                      _ttsTaskCenterGroupedByShot =
                                          groupedByShot;
                                    });
                                  },
                          ),
                          const SizedBox(width: StudioSpacing.xs),
                          StudioDebouncedAction(
                            enabled:
                                !loading &&
                                !requestBusy &&
                                retryableFilteredTasks.isNotEmpty,
                            onPressed:
                                (loading ||
                                    requestBusy ||
                                    retryableFilteredTasks.isEmpty)
                                ? null
                                : () async {
                                    final retrySettings =
                                        await _openVoiceoverSettingsDialog(
                                          context: ctx,
                                          initialSettings: _ttsRetrySettings,
                                        );
                                    if (retrySettings == null) {
                                      return;
                                    }
                                    _ttsRetrySettings = retrySettings;
                                    setState(() {
                                      requestBusy = true;
                                    });
                                    var succeeded = 0;
                                    var failed = 0;
                                    for (final task in retryableFilteredTasks) {
                                      try {
                                        await postTtsRetryV1(
                                          token,
                                          TtsRetryRequestV1(
                                            taskId: task.taskId,
                                            provider: retrySettings.provider,
                                            voiceId: retrySettings.voiceId,
                                            emotion: retrySettings.emotion,
                                            speed: retrySettings.speed,
                                          ),
                                        );
                                        succeeded += 1;
                                      } catch (_) {
                                        failed += 1;
                                      }
                                    }
                                    if (!mounted) return;
                                    _showOperationFeedback(
                                      l10n.shortVideoSpaceProductionAssemblyBatchRetryCompleted(
                                        succeeded,
                                        failed,
                                      ),
                                      isSuccess: failed == 0,
                                    );
                                    await loadTasks();
                                    setState(() {
                                      requestBusy = false;
                                    });
                                  },
                            builder: (context, onPressed) => OutlinedButton.icon(
                              onPressed: onPressed,
                              icon: const Icon(Icons.replay_outlined),
                              label: Text(
                                l10n.shortVideoSpaceProductionAssemblyBatchRetryFailed(
                                  retryableFilteredTasks.length,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      TextField(
                        enabled: !requestBusy,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n
                              .shortVideoSpaceProductionAssemblyFilterTaskIdScriptShot,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            keyword = value;
                            _ttsTaskCenterKeyword = keyword;
                          });
                        },
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      if (errorMessage != null)
                        StudioApiErrorCallout(
                          error: errorMessage!,
                          onRetry: () => unawaited(loadTasks()),
                          emphasis: StudioApiErrorCalloutEmphasis.subtle,
                        ),
                      const SizedBox(height: StudioSpacing.xs),
                      if (!loading && tasks.isNotEmpty)
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyTaskSummary(
                            tasks.length,
                            tasks.where((t) => t.status == 'queued').length,
                            tasks.where((t) => t.status == 'running').length,
                            tasks.where((t) => t.status == 'succeeded').length,
                            tasks.where((t) => t.status == 'failed').length,
                            tasks.where((t) => t.status == 'cancelled').length,
                            filteredTasks.length,
                            visibleTasks.length,
                          ),
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      if (!loading && tasks.isNotEmpty)
                        const SizedBox(height: StudioSpacing.xs),
                      Expanded(
                        child: StudioAsyncDataView(
                          loading: loading,
                          loadingPlaceholder: StudioLoadingPlaceholder.list,
                          loadingItemCount: 4,
                          isEmpty: tasks.isEmpty,
                          empty: Center(
                            child: StudioEmptyState.emptyData(
                              title: l10n
                                  .shortVideoSpaceProductionAssemblyNoVoiceoverTasks,
                              icon: Icons.record_voice_over_outlined,
                            ),
                          ),
                          child: ListView.separated(
                                itemCount: groupedByShot
                                    ? filteredTasks.length
                                    : filteredTasks.length,
                                separatorBuilder: (context, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final task = filteredTasks[index];
                                  final shotNumeric = task.shotId == null
                                      ? null
                                      : shotNumericById[task.shotId!];
                                  final scriptNumeric = shotNumeric == null
                                      ? null
                                      : scriptByShotNumeric[shotNumeric];
                                  final canCancel =
                                      task.status == 'queued' ||
                                      task.status == 'running';
                                  final hasAudio = (task.audioUrl ?? '')
                                      .trim()
                                      .isNotEmpty;
                                  final canRetry =
                                      task.status == 'failed' &&
                                      task.taskId.trim().isNotEmpty;
                                  final audioSuffix = hasAudio
                                      ? l10n.shortVideoSpaceProductionAssemblyTaskSubtitleAudioReady
                                      : '';
                                  final errorSuffix =
                                      task.error != null &&
                                          task.error!.isNotEmpty
                                      ? l10n.shortVideoSpaceProductionAssemblyTaskSubtitleError(
                                          task.error!,
                                        )
                                      : '';
                                  return studioStaggeredItem(
                                    index,
                                    entranceKey: filteredTasks.length,
                                    child: StudioListRow(
                                    onCopy: hasAudio
                                        ? () async {
                                            await Clipboard.setData(
                                              ClipboardData(
                                                text: task.audioUrl!.trim(),
                                              ),
                                            );
                                            if (!mounted) return;
                                            _showOperationFeedback(
                                              l10n.shortVideoSpaceProductionAssemblyAudioLinkCopied,
                                              isSuccess: true,
                                            );
                                          }
                                        : null,
                                    copyLabel: l10n
                                        .shortVideoSpaceProductionAssemblyCopyAudioLink,
                                    onCancel: canCancel && !requestBusy
                                        ? () async {
                                            setState(() {
                                              requestBusy = true;
                                            });
                                            try {
                                              await postTtsCancelV1(
                                                token,
                                                task.taskId,
                                              );
                                              if (!mounted) return;
                                              _showOperationFeedback(
                                                l10n.shortVideoSpaceProductionAssemblyTaskCancelled(
                                                  task.taskId.substring(0, 8),
                                                ),
                                                isSuccess: true,
                                              );
                                              await loadTasks();
                                            } catch (e) {
                                              if (!mounted) return;
                                              _showOperationFeedback(
                                                l10n.shortVideoSpaceProductionAssemblyCancelFailed(
                                                  describeUserVisibleApiError(
                                                    l10n,
                                                    e,
                                                  ),
                                                ),
                                                isSuccess: false,
                                              );
                                            } finally {
                                              setState(() {
                                                requestBusy = false;
                                              });
                                            }
                                          }
                                        : null,
                                    cancelLabel: l10n
                                        .shortVideoSpaceProductionAssemblyCancelTask,
                                    dense: true,
                                    title: Text(
                                      l10n.shortVideoSpaceProductionAssemblyTaskEntry(
                                        groupedByShot
                                            ? l10n.shortVideoSpaceProductionAssemblyLatestTask
                                            : l10n.shortVideoSpaceProductionAssemblyTask,
                                        task.taskId.substring(0, 8),
                                        shortVideoPublishJobStatusLabel(
                                          l10n,
                                          task.status,
                                        ),
                                      ),
                                    ),
                                    subtitle: Text(
                                      l10n.shortVideoSpaceProductionAssemblyTaskSubtitle(
                                        '${scriptNumeric ?? '-'}',
                                        '${shotNumeric ?? '-'}',
                                        audioSuffix,
                                        errorSuffix,
                                      ),
                                    ),
                                    trailing: Wrap(
                                      spacing: StudioSpacing.chromeActionGap,
                                      children: [
                                        if (hasAudio)
                                          StudioIconButton(
                                            icon: Icons.play_circle_outline,
                                            label: l10n
                                                .shortVideoSpaceProductionAssemblyPreviewAudio,
                                            onPressed: () {
                                              _showAudioPreviewDialog(
                                                context: ctx,
                                                audioUrl: task.audioUrl!.trim(),
                                              );
                                            },
                                          ),
                                        if (hasAudio)
                                          StudioIconButton(
                                            icon: Icons.link,
                                            label: l10n
                                                .shortVideoSpaceProductionAssemblyCopyAudioLink,
                                            onPressed: () async {
                                              await Clipboard.setData(
                                                ClipboardData(
                                                  text: task.audioUrl!.trim(),
                                                ),
                                              );
                                              if (!mounted) return;
                                              _showOperationFeedback(
                                                l10n.shortVideoSpaceProductionAssemblyAudioLinkCopied,
                                                isSuccess: true,
                                              );
                                            },
                                          ),
                                        if (canCancel)
                                          StudioDebouncedAction(
                                            enabled: !requestBusy,
                                            onPressed: requestBusy
                                                ? null
                                                : () async {
                                                    setState(() {
                                                      requestBusy = true;
                                                    });
                                                    try {
                                                      await postTtsCancelV1(
                                                        token,
                                                        task.taskId,
                                                      );
                                                      if (!mounted) return;
                                                      _showOperationFeedback(
                                                        l10n.shortVideoSpaceProductionAssemblyTaskCancelled(
                                                          task.taskId.substring(
                                                            0,
                                                            8,
                                                          ),
                                                        ),
                                                        isSuccess: true,
                                                      );
                                                      await loadTasks();
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      _showOperationFeedback(
                                                        l10n.shortVideoSpaceProductionAssemblyCancelFailed(
                                                          describeUserVisibleApiError(
                                                            l10n,
                                                            e,
                                                          ),
                                                        ),
                                                        isSuccess: false,
                                                      );
                                                    } finally {
                                                      setState(() {
                                                        requestBusy = false;
                                                      });
                                                    }
                                                  },
                                            builder: (context, onPressed) =>
                                                TextButton(
                                              onPressed: onPressed,
                                              child: Text(
                                                l10n.shortVideoSpaceProductionAssemblyCancelTask,
                                              ),
                                            ),
                                          ),
                                        if (canRetry)
                                          StudioDebouncedAction(
                                            enabled: !requestBusy,
                                            onPressed: requestBusy
                                                ? null
                                                : () async {
                                                    final retrySettings =
                                                        await _openVoiceoverSettingsDialog(
                                                          context: ctx,
                                                          initialSettings:
                                                              _ttsRetrySettings,
                                                        );
                                                    if (retrySettings == null) {
                                                      return;
                                                    }
                                                    _ttsRetrySettings =
                                                        retrySettings;
                                                    setState(() {
                                                      requestBusy = true;
                                                    });
                                                    try {
                                                      final response =
                                                          await postTtsRetryV1(
                                                            token,
                                                            TtsRetryRequestV1(
                                                              taskId:
                                                                  task.taskId,
                                                              provider:
                                                                  retrySettings
                                                                      .provider,
                                                              voiceId:
                                                                  retrySettings
                                                                      .voiceId,
                                                              emotion:
                                                                  retrySettings
                                                                      .emotion,
                                                              speed:
                                                                  retrySettings
                                                                      .speed,
                                                            ),
                                                          );
                                                      if (!mounted) return;
                                                      _showOperationFeedback(
                                                        l10n.shortVideoSpaceProductionAssemblyTaskRetried(
                                                          response.taskId
                                                              .substring(0, 8),
                                                        ),
                                                        isSuccess: true,
                                                      );
                                                      await loadTasks();
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      _showOperationFeedback(
                                                        l10n.shortVideoSpaceProductionAssemblyRetryFailed(
                                                          describeUserVisibleApiError(
                                                            l10n,
                                                            e,
                                                          ),
                                                        ),
                                                        isSuccess: false,
                                                      );
                                                    } finally {
                                                      setState(() {
                                                        requestBusy = false;
                                                      });
                                                    }
                                                  },
                                            builder: (context, onPressed) =>
                                                TextButton(
                                              onPressed: onPressed,
                                              child: Text(
                                                l10n.shortVideoSpaceProductionAssemblyRetryTask,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  );
                                },
                              ),
                          ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.shortVideoSpaceProductionAssemblyClose),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      poller?.cancel();
    }
  }
}
