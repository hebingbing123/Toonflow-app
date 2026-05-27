part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

/// Assembly and clip desk operations for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionAssemblyExtension
    on _ShortVideoSpaceSectionState {
  static const _terminalJobStatuses = <String>{
    'succeeded',
    'failed',
    'cancelled',
  };
  static const _preAssemblyJobKind = 'short_video.pre_assembly';
  static const _exportJobKind = 'video.export';

  Future<void> _refreshActiveExportTaskDetails(String taskId) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty || taskId.trim().isEmpty) {
      return;
    }
    try {
      final task = await getExportTaskByIdV1(token, taskId);
      if (!mounted) return;
      setState(() {
        if (_activeAssemblyJob?.kind == _exportJobKind &&
            _activeAssemblyJob?.id == task.id) {
          _activeExportTask = task;
        }
      });
    } catch (_) {}
  }

  Future<void> _refreshActiveAssemblyJob() async {
    final token = widget.accessToken?.trim();
    final jobId = _activeAssemblyJob?.id;
    if (token == null || token.isEmpty || jobId == null || jobId.isEmpty) {
      return;
    }
    try {
      final row = await fetchJob(token, jobId);
      if (!mounted) return;
      setState(() {
        _activeAssemblyJob = row;
        if (row.kind != _exportJobKind) {
          _activeExportTask = null;
        }
      });
      _syncLatestSuccessfulExportFromJob(row);
      if (row.kind == _exportJobKind) {
        unawaited(_refreshActiveExportTaskDetails(row.id));
      }
    } catch (_) {}
  }

  void _beginAssemblyJobTracking(
    String jobId, {
    String kind = _preAssemblyJobKind,
  }) {
    _assemblyJobPollTimer?.cancel();
    setState(() {
      _activeAssemblyJob = JobRow(
        id: jobId,
        numericTaskId: 0,
        ownerUserId: '',
        kind: kind,
        status: 'queued',
        payload: const {},
        createdAt: DateTime.now().toUtc().toIso8601String(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      if (kind != _exportJobKind) {
        _activeExportTask = null;
      }
    });
    if (kind == _exportJobKind) {
      unawaited(_refreshActiveExportTaskDetails(jobId));
    }
    _assemblyJobPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollActiveAssemblyJobOnce());
    });
    unawaited(_pollActiveAssemblyJobOnce());
  }

  Future<void> _pollActiveAssemblyJobOnce() async {
    final token = widget.accessToken?.trim();
    final jobId = _activeAssemblyJob?.id;
    if (token == null || token.isEmpty || jobId == null) {
      return;
    }
    try {
      final row = await fetchJob(token, jobId);
      if (!mounted) return;
      final wasTerminal = _activeAssemblyJob != null &&
          _terminalJobStatuses.contains(_activeAssemblyJob!.status);
      setState(() {
        _activeAssemblyJob = row;
        if (row.kind != _exportJobKind) {
          _activeExportTask = null;
        }
      });
      _syncLatestSuccessfulExportFromJob(row);
      if (row.kind == _exportJobKind) {
        unawaited(_refreshActiveExportTaskDetails(row.id));
      }
      if (_terminalJobStatuses.contains(row.status)) {
        _assemblyJobPollTimer?.cancel();
        _assemblyJobPollTimer = null;
        if (!wasTerminal) {
          _invalidateProductionSnapshots(
            includeJobs: true,
            extra: const <StudioSnapshotKey>[StudioSnapshotKey.assemblyVersions],
          );
          if (row.kind == _preAssemblyJobKind && row.status == 'succeeded') {
            unawaited(_loadDraftsAndVersions());
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _cancelActiveAssemblyJob() async {
    final token = widget.accessToken?.trim();
    final job = _activeAssemblyJob;
    if (token == null || token.isEmpty || job == null) return;
    try {
      final updated = await cancelJob(token, job.id);
      if (!mounted) return;
      setState(() {
        _activeAssemblyJob = updated;
        if (updated.kind != _exportJobKind) {
          _activeExportTask = null;
        }
      });
      _syncLatestSuccessfulExportFromJob(updated);
      if (updated.kind == _exportJobKind) {
        unawaited(_refreshActiveExportTaskDetails(updated.id));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(describeUserVisibleApiErrorResolved(context, e))),
      );
    }
  }

  Future<void> _retryActiveAssemblyJob() async {
    final token = widget.accessToken?.trim();
    final job = _activeAssemblyJob;
    if (token == null || token.isEmpty || job == null) return;
    try {
      final updated = await retryJob(token, job.id);
      if (!mounted) return;
      setState(() {
        _activeAssemblyJob = updated;
        if (updated.kind != _exportJobKind) {
          _activeExportTask = null;
        }
      });
      _syncLatestSuccessfulExportFromJob(updated);
      if (updated.kind == _exportJobKind) {
        unawaited(_refreshActiveExportTaskDetails(updated.id));
      }
      _beginAssemblyJobTracking(updated.id, kind: updated.kind);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(describeUserVisibleApiErrorResolved(context, e))),
      );
    }
  }

  Future<void> _createDraftFromPreAssemblyJob() async {
    final job = _activeAssemblyJob;
    final result = job?.result;
    if (result is! Map<String, dynamic>) {
      return;
    }
    final manifestPath =
        result['manifest_path'] as String? ?? result['disk_path'] as String?;
    if (manifestPath == null || manifestPath.trim().isEmpty) {
      return;
    }
    final versionName =
        'pre-asm ${DateTime.now().toIso8601String().substring(0, 16)}';
    await _handleCreateVersion(versionName);
    if (!mounted) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(l10n.shortVideoSpaceAssemblyInputCreateDraftFromJob)),
    );
  }

  Future<void> _startPreAssemblyFlow() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null ||
        token.isEmpty ||
        project == null ||
        _preAssemblyActionBusy) {
      return;
    }

    setState(() {
      _preAssemblyActionBusy = true;
    });
    try {
      final gate = buildAssemblyGateUi(
        l10n: resolveAppLocalizationsForErrors(context),
        exportCheck: _shortVideoExportCheck,
        assembly: _shortVideoAssembly,
      );
      if (!gate.canPreAssembly) {
        if (!mounted) return;
        final l10n = resolveAppLocalizationsForErrors(context);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(l10n.shortVideoSpaceAssemblyGatePreAssemblyBlocked),
          ),
        );
        return;
      }
      final response = await postProjectShortVideoPreAssemblyByProjectId(
        token,
        project.id,
      );
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      _beginAssemblyJobTracking(response.jobId, kind: _preAssemblyJobKind);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoSpacePreAssemblyEnqueued(
              response.summary.shotCount,
              response.summary.blockingShotCount,
              response.jobId.substring(0, 8),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      reportRustOrDescribeApiError(
        e,
        l10n: l10n,
        onErrorChanged: (msg) {
          if (!mounted || msg == null || e is RustApiException) {
            return;
          }
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(l10n.shortVideoSpacePreAssemblyFailed(msg)),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _preAssemblyActionBusy = false;
        });
      }
    }
  }

  Future<void> _startExportFlow() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null ||
        token.isEmpty ||
        project == null ||
        _exportActionBusy) {
      return;
    }

    final settings = await _openExportSettingsDialog(context: context);
    if (settings == null || !mounted) {
      return;
    }

    setState(() {
      _exportActionBusy = true;
    });
    final gate = buildAssemblyGateUi(
      l10n: resolveAppLocalizationsForErrors(context),
      exportCheck: _shortVideoExportCheck,
      assembly: _shortVideoAssembly,
    );
    if (!gate.canExport) {
      if (!mounted) return;
      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            gate.blockingReasonLines.isNotEmpty
                ? gate.blockingReasonLines.first
                : l10n.shortVideoSpacePublishExportCheckBlockingHeadline,
          ),
        ),
      );
      return;
    }

    try {
      final format = settings.format.trim().toLowerCase();
      final enqueue = await postProjectShortVideoExportByProjectId(
        token,
        project.id,
        format: format.isEmpty ? 'mp4' : format,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeAssemblyJob = JobRow(
          id: enqueue.jobId,
          numericTaskId: 0,
          ownerUserId: '',
          kind: _exportJobKind,
          status: 'queued',
          payload: const {},
          createdAt: DateTime.now().toUtc().toIso8601String(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        );
      });
      _beginAssemblyJobTracking(enqueue.jobId, kind: _exportJobKind);
      final progressResult = await _openExportProgressDialog(
        context: context,
        taskId: enqueue.jobId,
      );
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      if (progressResult.openHistoryRequested) {
        final historyResult = await _openExportHistoryDialog(
          context: context,
          currentTaskId: enqueue.jobId,
        );
        if (!mounted) {
          return;
        }
        await _applyExportHistoryDialogResult(historyResult);
      } else {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              progressResult.completed
                  ? l10n.shortVideoSpaceProductionAssemblyExportCompleted
                  : l10n.shortVideoSpaceProductionAssemblyExportNotCompleted,
            ),
          ),
        );
      }
      _invalidateProductionSnapshots(
        includeJobs: true,
        extra: const <StudioSnapshotKey>[StudioSnapshotKey.assemblyVersions],
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      reportRustOrDescribeApiError(
        e,
        l10n: l10n,
        onErrorChanged: (msg) {
          if (!mounted || msg == null || e is RustApiException) {
            return;
          }
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                l10n.shortVideoSpaceProductionAssemblyExportStartFailed(msg),
              ),
            ),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportActionBusy = false;
        });
      }
    }
  }

  Future<void> _openExportHistoryFlow() async {
    if (_selectedProject == null || _exportActionBusy) {
      return;
    }
    final result = await _openExportHistoryDialog(context: context);
    if (!mounted) {
      return;
    }
    await _applyExportHistoryDialogResult(result);
  }

  void _syncLatestSuccessfulExportFromJob(JobRow job) {
    if (job.kind != _exportJobKind || job.status != 'succeeded') {
      return;
    }
    final item = exportHistoryItemFromJob(job);
    if (item.outputUrl == null || item.outputUrl!.trim().isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _latestSuccessfulExport = item;
    });
  }

  Future<void> _refreshLatestSuccessfulExport() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      if (mounted) {
        setState(() {
          _latestSuccessfulExport = null;
        });
      }
      return;
    }
    try {
      final jobs = await fetchJobs(
        token,
        kind: _exportJobKind,
        status: 'succeeded',
        limit: 50,
      );
      if (!mounted || _selectedProjectId != project.id) {
        return;
      }
      final items = jobs
          .where((job) => job.payload['project_uuid']?.toString() == project.id)
          .map(exportHistoryItemFromJob)
          .where((item) => item.outputUrl?.trim().isNotEmpty ?? false)
          .toList(growable: false);
      items.sort((a, b) {
        final aTime = a.completedAt ?? a.createdAt;
        final bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      setState(() {
        _latestSuccessfulExport = items.isEmpty ? null : items.first;
      });
    } catch (_) {}
  }

  Future<void> _downloadLatestSuccessfulExport() async {
    final item = _latestSuccessfulExport;
    final url = item?.outputUrl?.trim();
    if (item == null || url == null || url.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return;
        }
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          l10n.shortVideoSpaceDialogExportHistoryDownloadLinkCopied(
            getFormatDisplayName(l10n, item.format.toLowerCase()),
          ),
        ),
      ),
    );
  }

  Future<void> _applyExportHistoryDialogResult(
    ExportHistoryDialogResult result,
  ) async {
    if (result.openProductionWorkspaceRequested) {
      widget.onOpenProductionWorkspace();
    }
    final taskId = result.focusedTaskId?.trim();
    if (taskId == null || taskId.isEmpty) {
      return;
    }
    if (result.shouldTrackFocusedTask) {
      final token = widget.accessToken?.trim();
      if (token != null && token.isNotEmpty) {
        try {
          final job = await fetchJob(token, taskId);
          if (!mounted) {
            return;
          }
          setState(() {
            _activeAssemblyJob = job;
          });
          if (!_terminalJobStatuses.contains(job.status)) {
            _beginAssemblyJobTracking(job.id, kind: job.kind);
          }
        } catch (_) {}
      }
    }
    await _refreshLatestSuccessfulExport();
    _invalidateProductionSnapshots(
      includeJobs: true,
      extra: const <StudioSnapshotKey>[StudioSnapshotKey.assemblyVersions],
    );
  }

  /// Show operation feedback with auto-dismiss after 3 seconds
  void _showOperationFeedback(String message, {required bool isSuccess}) {
    setState(() {
      _projectConfigLine = message;
      _operationFeedbackIsSuccess = isSuccess;
    });

    // Auto-clear after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _projectConfigLine = null;
          _operationFeedbackIsSuccess = null;
        });
      }
    });
  }

  Future<String?> _promptReplacementVideoUrl(
    BuildContext context, {
    String initialValue = '',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = await showStudioDialog<String>(
      context: context,
      builder: (ctx) {
        return StudioAlertDialog(
          title: Text(l10n.shortVideoSpaceProductionAssemblyReplaceVideoTitle),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: l10n.shortVideoSpaceProductionAssemblyVideoUrlLabel,
              hintText: l10n.shortVideoSpaceProductionAssemblyVideoUrlHint,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.shortVideoSpaceProductionAssemblyCancel),
            ),
            FilledButton(
              style: studioFormPrimaryButtonStyle(ctx),
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text(
                l10n.shortVideoSpaceProductionAssemblyWriteBackVersion,
              ),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  /// Show audio preview dialog for voiceover
  ///
  /// **Validates: Requirements 5**
  void _showAudioPreviewDialog({
    required BuildContext context,
    required String audioUrl,
  }) {
    showStudioDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StudioDialogFrame(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AudioPreviewPlayer(
              audioUrl: audioUrl,
              autoPlay: false,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAssemblyClipDeskOps() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final assembly = _shortVideoAssembly;
    if (token == null || token.isEmpty || project == null || assembly == null) {
      return;
    }
    final entries = <_AssemblyClipDeskOpEntry>[
      for (final group in assembly.scripts)
        for (final shot in group.shots)
          _AssemblyClipDeskOpEntry(
            scriptNumericId: group.scriptNumericId,
            storyboardId: shot.storyboardId,
            storyboardNumericId: shot.storyboardNumericId,
            sbIndex: shot.sbIndex,
            selectedMediaUrl: (shot.selectedMediaUrl ?? '').trim(),
            selectedMediaKind: shot.selectedMediaKind,
            durationText: (shot.duration ?? '').trim(),
            subtitleText: (shot.subtitleText ?? '').trim(),
            voiceoverScriptReady: shot.voiceoverScriptReady,
            voiceoverAssetReady: shot.voiceoverAssetReady,
            voiceoverState: shot.voiceoverState ?? '',
            voiceoverAudioUrl: (shot.voiceoverAudioUrl ?? '').trim(),
            voiceoverError: (shot.voiceoverError ?? '').trim(),
          ),
    ];
    if (entries.isEmpty) {
      return;
    }
    var ordered = List<_AssemblyClipDeskOpEntry>.from(entries);
    final initialOrdered = List<_AssemblyClipDeskOpEntry>.from(entries);
    final pausedStoryboardIds = <int>{
      for (final item in entries)
        if (item.selectedMediaUrl.isEmpty) item.storyboardNumericId,
    };
    var filterState = FilterState.empty();
    var filterPresets = <FilterPreset>[]; // Filter presets storage
    var operationInProgress = false;
    var selectedStoryboardIds = <int>{}; // Batch selection state
    if (!mounted) return;
    await showStudioDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final l10n = resolveAppLocalizationsForErrors(ctx);
            Future<void> runDisable(_AssemblyClipDeskOpEntry item) async {
              try {
                await postWorkbenchDeleteVideoV1(
                  token,
                  projectUuid: project.id,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                );
                pausedStoryboardIds.add(item.storyboardNumericId);

                // Record operation for undo/redo
                _recordDisableOperation(
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  previousVideoUrl: item.selectedMediaUrl,
                );

                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyShotDisabled(
                      item.storyboardNumericId,
                    ),
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyDisableFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              }
            }

            Future<void> runEnableOrReplace(
              _AssemblyClipDeskOpEntry item, {
              String? replacementUrl,
            }) async {
              final seedUrl = (replacementUrl ?? item.selectedMediaUrl).trim();
              if (seedUrl.isEmpty) {
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.shortVideoSpaceProductionAssemblyNoVideoUrl,
                    ),
                  ),
                );
                return;
              }
              try {
                // Store previous URL for undo/redo
                final previousUrl = item.selectedMediaUrl;
                final isReplace =
                    replacementUrl != null && previousUrl.isNotEmpty;

                await postWorkbenchSelectVideoV1(
                  token,
                  projectUuid: project.id,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  videoUrl: seedUrl,
                );

                // Record operation for undo/redo
                if (isReplace) {
                  _recordReplaceOperation(
                    scriptId: item.scriptNumericId,
                    storyboardId: item.storyboardNumericId,
                    previousVideoUrl: previousUrl,
                    newVideoUrl: seedUrl,
                  );
                } else {
                  _recordEnableOperation(
                    scriptId: item.scriptNumericId,
                    storyboardId: item.storyboardNumericId,
                    videoUrl: seedUrl,
                  );
                }

                pausedStoryboardIds.remove(item.storyboardNumericId);
                if (replacementUrl != null) {
                  final idx = ordered.indexWhere(
                    (entry) =>
                        entry.storyboardNumericId == item.storyboardNumericId,
                  );
                  if (idx >= 0) {
                    ordered[idx] = ordered[idx].copyWith(
                      selectedMediaUrl: seedUrl,
                    );
                  }
                }
                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyShotWriteBack(
                      item.storyboardNumericId,
                    ),
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyWriteBackFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              }
            }

            Future<void> persistReorder() async {
              final byScript = <int, List<int>>{};
              for (final item in ordered) {
                byScript
                    .putIfAbsent(item.scriptNumericId, () => <int>[])
                    .add(item.storyboardNumericId);
              }
              setLocalState(() {
                operationInProgress = true;
              });
              try {
                for (final entry in byScript.entries) {
                  final scriptNumericId = entry.key;
                  final orderedStoryboardIds = entry.value;
                  final flowData = await fallbackOnRustApiException(
                    () => fetchProductionFlowDataV1(
                      token,
                      projectUuid: project.id,
                      episodesId: scriptNumericId,
                    ),
                    <String, dynamic>{},
                  );
                  flowData['storyboard'] = orderedStoryboardIds
                      .map((id) => <String, dynamic>{'id': id})
                      .toList(growable: false);
                  final code = await postProductionSaveFlowDataV1(
                    token,
                    projectUuid: project.id,
                    episodesId: scriptNumericId,
                    data: flowData,
                  );
                  if (code != 200) {
                    throw RustApiException(
                      'save flow failed',
                      statusCode: code,
                    );
                  }
                }
                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyReorderPersisted,
                    isSuccess: true,
                  );
                }
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyReorderFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              } finally {
                setLocalState(() {
                  operationInProgress = false;
                });
              }
            }

            Future<void> runAlignDuration(
              _AssemblyClipDeskOpEntry item,
              int durationSeconds,
            ) async {
              try {
                // Store previous duration for undo/redo
                final previousDuration =
                    int.tryParse(
                      item.durationText.replaceAll(RegExp(r'[^0-9]'), ''),
                    ) ??
                    0;

                final status = await postStoryboardUpdateDurationV1(
                  token,
                  projectUuid: project.id,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  duration: durationSeconds,
                );
                if (status != 200) {
                  throw RustApiException(
                    'update storyboard duration failed',
                    statusCode: status,
                  );
                }

                // Record operation for undo/redo
                _recordDurationOperation(
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  previousDuration: previousDuration,
                  newDuration: durationSeconds,
                );

                final idx = ordered.indexWhere(
                  (entry) =>
                      entry.storyboardNumericId == item.storyboardNumericId,
                );
                if (idx >= 0) {
                  ordered[idx] = ordered[idx].copyWith(
                    durationText: '${durationSeconds}s',
                  );
                }
                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyShotAligned(
                      item.storyboardNumericId,
                      durationSeconds,
                    ),
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyAlignFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              }
            }

            int? parseDurationSeconds(String value) {
              final trimmed = value.trim().toLowerCase();
              if (trimmed.isEmpty) return null;
              final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
              if (digits == null) return null;
              return int.tryParse(digits.group(1)!);
            }

            String subtitleMismatchLine(_AssemblyClipDeskOpEntry item) {
              final durationSec = parseDurationSeconds(item.durationText);
              final hasSubtitle = item.subtitleText.isNotEmpty;
              if (hasSubtitle && durationSec == null) {
                return l10n
                    .shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing;
              }
              if (!hasSubtitle && (durationSec ?? 0) > 0) {
                return l10n
                    .shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty;
              }
              if (hasSubtitle && (durationSec ?? 0) <= 0) {
                return l10n
                    .shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal;
              }
              return l10n
                  .shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch;
            }

            bool hasSubtitleDurationMismatch(_AssemblyClipDeskOpEntry item) {
              final durationSec = parseDurationSeconds(item.durationText);
              final hasSubtitle = item.subtitleText.isNotEmpty;
              if (hasSubtitle && durationSec == null) return true;
              if (!hasSubtitle && (durationSec ?? 0) > 0) return true;
              if (hasSubtitle && (durationSec ?? 0) <= 0) return true;
              return false;
            }

            bool hasQualityIssue(_AssemblyClipDeskOpEntry item) {
              return item.voiceoverState == 'failed' ||
                  hasSubtitleDurationMismatch(item);
            }

            bool matchesSearch(_AssemblyClipDeskOpEntry item) {
              final keyword = filterState.searchKeyword.trim().toLowerCase();
              if (keyword.isEmpty) {
                return true;
              }
              final searchTargets = <String>[
                item.storyboardNumericId.toString(),
                item.scriptNumericId.toString(),
                item.selectedMediaUrl,
                if (filterState.searchInSubtitles) item.subtitleText,
                if (filterState.searchInVoiceover) ...[
                  item.voiceoverState,
                  item.voiceoverError,
                  item.voiceoverAudioUrl,
                ],
              ];
              return searchTargets.any(
                (value) => value.toLowerCase().contains(keyword),
              );
            }

            /// Build highlighted text widget for search results
            Widget buildHighlightedText(
              String text,
              String keyword, {
              TextStyle? style,
            }) {
              if (keyword.isEmpty || text.isEmpty) {
                return Text(text, style: style);
              }

              final lowerText = text.toLowerCase();
              final lowerKeyword = keyword.toLowerCase();
              final matches = <int>[];

              // Find all occurrences of the keyword
              var startIndex = 0;
              while (true) {
                final index = lowerText.indexOf(lowerKeyword, startIndex);
                if (index == -1) break;
                matches.add(index);
                startIndex = index + lowerKeyword.length;
              }

              if (matches.isEmpty) {
                return Text(text, style: style);
              }

              // Build text spans with highlighting
              final spans = <TextSpan>[];
              var currentIndex = 0;

              for (final matchIndex in matches) {
                // Add text before match
                if (matchIndex > currentIndex) {
                  spans.add(
                    TextSpan(
                      text: text.substring(currentIndex, matchIndex),
                      style: style,
                    ),
                  );
                }

                // Add highlighted match
                spans.add(
                  TextSpan(
                    text: text.substring(
                      matchIndex,
                      matchIndex + lowerKeyword.length,
                    ),
                    style: (style ?? const TextStyle()).copyWith(
                      backgroundColor: StudioTokens.of(ctx).primarySoft,
                      color: StudioTokens.of(ctx).textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                currentIndex = matchIndex + lowerKeyword.length;
              }

              // Add remaining text
              if (currentIndex < text.length) {
                spans.add(
                  TextSpan(text: text.substring(currentIndex), style: style),
                );
              }

              return RichText(text: TextSpan(children: spans));
            }

            bool matchesStatusFilters(_AssemblyClipDeskOpEntry item) {
              if (filterState.statusFilters.isEmpty) {
                return true;
              }
              final paused = pausedStoryboardIds.contains(
                item.storyboardNumericId,
              );
              final durationSec = parseDurationSeconds(item.durationText);
              final hasSubtitle = item.subtitleText.isNotEmpty;
              final hasVoiceover =
                  item.voiceoverScriptReady || item.voiceoverAssetReady;
              for (final filter in filterState.statusFilters) {
                switch (filter) {
                  case ShotStatusFilter.enabled:
                    if (!paused) return true;
                    break;
                  case ShotStatusFilter.disabled:
                    if (paused) return true;
                    break;
                  case ShotStatusFilter.hasVideo:
                    if (item.selectedMediaUrl.isNotEmpty) return true;
                    break;
                  case ShotStatusFilter.noVideo:
                    if (item.selectedMediaUrl.isEmpty) return true;
                    break;
                  case ShotStatusFilter.hasDuration:
                    if ((durationSec ?? 0) > 0) return true;
                    break;
                  case ShotStatusFilter.noDuration:
                    if ((durationSec ?? 0) <= 0) return true;
                    break;
                  case ShotStatusFilter.hasSubtitle:
                    if (hasSubtitle) return true;
                    break;
                  case ShotStatusFilter.noSubtitle:
                    if (!hasSubtitle) return true;
                    break;
                  case ShotStatusFilter.hasVoiceover:
                    if (hasVoiceover) return true;
                    break;
                  case ShotStatusFilter.noVoiceover:
                    if (!hasVoiceover) return true;
                    break;
                  case ShotStatusFilter.voiceoverFailed:
                    if (item.voiceoverState == 'failed') return true;
                    break;
                }
              }
              return false;
            }

            bool matchesQualityFilters(_AssemblyClipDeskOpEntry item) {
              if (filterState.qualityFilters.isEmpty) {
                return true;
              }
              final qualityIssue = hasQualityIssue(item);
              final postProductionReady =
                  item.selectedMediaUrl.isNotEmpty &&
                  parseDurationSeconds(item.durationText) != null;
              for (final filter in filterState.qualityFilters) {
                switch (filter) {
                  case QualityFilter.hasBadExample:
                    if (qualityIssue) return true;
                    break;
                  case QualityFilter.noBadExample:
                    if (!qualityIssue) return true;
                    break;
                  case QualityFilter.generationStage:
                    if (!postProductionReady) return true;
                    break;
                  case QualityFilter.postProductionStage:
                    if (postProductionReady) return true;
                    break;
                  case QualityFilter.hasDegradation:
                    if (qualityIssue ||
                        pausedStoryboardIds.contains(
                          item.storyboardNumericId,
                        )) {
                      return true;
                    }
                    break;
                  case QualityFilter.noDegradation:
                    if (!qualityIssue &&
                        !pausedStoryboardIds.contains(
                          item.storyboardNumericId,
                        )) {
                      return true;
                    }
                    break;
                }
              }
              return false;
            }

            List<_AssemblyClipDeskOpEntry> buildVisibleEntries() {
              return ordered
                  .where((item) {
                    return matchesSearch(item) &&
                        matchesStatusFilters(item) &&
                        matchesQualityFilters(item);
                  })
                  .toList(growable: false);
            }

            // 计算当前总时长（实时更新）
            int calculateCurrentTotalDuration() {
              var total = 0;
              for (final item in ordered) {
                // 排除已暂停镜头
                if (pausedStoryboardIds.contains(item.storyboardNumericId)) {
                  continue;
                }
                final durationSec = parseDurationSeconds(item.durationText);
                if (durationSec != null && durationSec > 0) {
                  total += durationSec;
                }
              }
              return total;
            }

            String formatDurationHHMMSS(int totalSeconds) {
              final hours = totalSeconds ~/ 3600;
              final minutes = (totalSeconds % 3600) ~/ 60;
              final seconds = totalSeconds % 60;
              return '${hours.toString().padLeft(2, '0')}:'
                  '${minutes.toString().padLeft(2, '0')}:'
                  '${seconds.toString().padLeft(2, '0')}';
            }

            final currentTotalDuration = calculateCurrentTotalDuration();
            final currentTotalFormatted = formatDurationHHMMSS(
              currentTotalDuration,
            );
            final visibleEntries = buildVisibleEntries();

            return StudioAlertDialog(
              title: Text(l10n.shortVideoSpaceProductionAssemblyBasicOpsTitle),
              content: SizedBox(
                width: studioConstrainedDialogWidth(context, maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shortVideoSpaceProductionAssemblyBasicOpsDescription,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.shortVideoSpaceProductionAssemblyBasicOpsNote,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    // 显示成片总时长
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 20,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.shortVideoSpaceProductionAssemblyTotalDuration(
                              currentTotalDuration,
                              currentTotalFormatted,
                            ),
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilterPanel(
                      initialFilter: filterState,
                      onFilterChanged: (nextFilter) {
                        setLocalState(() {
                          filterState = nextFilter;
                        });
                      },
                      presets: filterPresets,
                      onPresetsChanged: (newPresets) {
                        setLocalState(() {
                          filterPresets = newPresets;
                        });
                      },
                      onSearchFocusNodeCreated: (focusNode) {
                        _setSearchFocusNode(focusNode);
                      },
                    ),
                    const SizedBox(height: 8),
                    // Batch operation toolbar
                    if (visibleEntries.isNotEmpty)
                      BatchOperationToolbar(
                        totalCount: visibleEntries.length,
                        selectedIds: selectedStoryboardIds,
                        onSelectionChanged: (newSelection) {
                          setLocalState(() {
                            selectedStoryboardIds = newSelection;
                          });
                        },
                        onSelectAll: () {
                          setLocalState(() {
                            selectedStoryboardIds = visibleEntries
                                .map((e) => e.storyboardNumericId)
                                .toSet();
                          });
                        },
                        onDeselectAll: () {
                          setLocalState(() {
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchEnable: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchEnableShots(
                            selectedStoryboardIds: selectedStoryboardIds,
                            allEntries: ordered,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                            dialogContext: ctx,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchDisable: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchDisableShots(
                            selectedStoryboardIds: selectedStoryboardIds,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                            dialogContext: ctx,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchUpdateDuration: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchUpdateDuration(
                            selectedStoryboardIds: selectedStoryboardIds,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchReplace: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchReplaceVideos(
                            selectedStoryboardIds: selectedStoryboardIds,
                            allEntries: ordered,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchGenerateVoiceover: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchGenerateVoiceover(
                            selectedStoryboardIds: selectedStoryboardIds,
                            allEntries: ordered,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        isOperationInProgress: operationInProgress,
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StudioDenseActionRow(
                        children: [
                          FilledButton.tonalIcon(
                            style: studioFormIconLabeledButtonStyle(context),
                            onPressed: operationInProgress
                                ? null
                                : () => unawaited(persistReorder()),
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblySaveReorder,
                            ),
                          ),
                          OutlinedButton.icon(
                            style: studioFormOutlinedIconLabeledButtonStyle(context),
                            onPressed: operationInProgress
                                ? null
                                : () {
                                    ordered =
                                        List<_AssemblyClipDeskOpEntry>.from(
                                          initialOrdered,
                                        );
                                    setLocalState(() {});
                                  },
                            icon: const Icon(Icons.undo_outlined),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyUndoToOpen,
                            ),
                          ),
                          OutlinedButton.icon(
                            style: studioFormOutlinedIconLabeledButtonStyle(context),
                            onPressed: operationInProgress
                                ? null
                                : () => unawaited(
                                    _openTtsTaskCenterDialog(
                                      context: ctx,
                                      token: token,
                                      projectId: project.id,
                                      entries: ordered,
                                    ),
                                  ),
                            icon: const Icon(Icons.record_voice_over_outlined),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyVoiceoverTasks,
                            ),
                          ),
                          // Undo/Redo buttons
                          _buildUndoRedoToolbar(),
                        ],
                      ),
                    ),
                    const SizedBox(height: StudioLayoutSpacing.inlineGap),
                    Flexible(
                      child: visibleEntries.isEmpty
                          ? Center(
                              child: Text(
                                l10n.shortVideoSpaceProductionAssemblyNoShotsFiltered,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            )
                          : _buildVirtualScrollList(
                              visibleEntries: visibleEntries,
                              ordered: ordered,
                              pausedStoryboardIds: pausedStoryboardIds,
                              selectedStoryboardIds: selectedStoryboardIds,
                              operationInProgress: operationInProgress,
                              filterState: filterState,
                              ctx: ctx,
                              l10n: l10n,
                              setLocalState: setLocalState,
                              runDisable: runDisable,
                              runEnableOrReplace: runEnableOrReplace,
                              runAlignDuration: runAlignDuration,
                              parseDurationSeconds: parseDurationSeconds,
                              subtitleMismatchLine: subtitleMismatchLine,
                              buildHighlightedText: buildHighlightedText,
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
  }

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
              poller ??= Timer.periodic(
                const Duration(seconds: 4),
                (_) => unawaited(loadTasks()),
              );
              if (tasks.isEmpty && loading && errorMessage == null) {
                unawaited(loadTasks());
              }
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
                  height: 420,
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
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (loading || requestBusy)
                                ? null
                                : () => unawaited(loadTasks()),
                            icon: const Icon(Icons.refresh_outlined),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyRefresh,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
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
                            icon: const Icon(Icons.replay_outlined),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyBatchRetryFailed(
                                retryableFilteredTasks.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      if (errorMessage != null)
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : tasks.isEmpty
                            ? Center(
                                child: Text(
                                  l10n.shortVideoSpaceProductionAssemblyNoVoiceoverTasks,
                                ),
                              )
                            : ListView.separated(
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
                                  return ListTile(
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
                                      spacing: 4,
                                      children: [
                                        if (hasAudio)
                                          IconButton(
                                            tooltip: l10n
                                                .shortVideoSpaceProductionAssemblyPreviewAudio,
                                            onPressed: () {
                                              _showAudioPreviewDialog(
                                                context: ctx,
                                                audioUrl: task.audioUrl!.trim(),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.play_circle_outline,
                                            ),
                                          ),
                                        if (hasAudio)
                                          IconButton(
                                            tooltip: l10n
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
                                            icon: const Icon(Icons.link),
                                          ),
                                        if (canCancel)
                                          TextButton(
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
                                            child: Text(
                                              l10n.shortVideoSpaceProductionAssemblyCancelTask,
                                            ),
                                          ),
                                        if (canRetry)
                                          TextButton(
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
                                            child: Text(
                                              l10n.shortVideoSpaceProductionAssemblyRetryTask,
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
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

  /// Build virtual scroll list with FlutterListView for efficient rendering
  ///
  /// **Validates: Requirements 29**
  ///
  /// Automatically enables virtual scrolling when item count > 100
  Widget _buildVirtualScrollList({
    required List<_AssemblyClipDeskOpEntry> visibleEntries,
    required List<_AssemblyClipDeskOpEntry> ordered,
    required Set<int> pausedStoryboardIds,
    required Set<int> selectedStoryboardIds,
    required bool operationInProgress,
    required FilterState filterState,
    required BuildContext ctx,
    required AppLocalizations l10n,
    required void Function(void Function()) setLocalState,
    required Future<void> Function(_AssemblyClipDeskOpEntry) runDisable,
    required Future<void> Function(
      _AssemblyClipDeskOpEntry, {
      String? replacementUrl,
    })
    runEnableOrReplace,
    required Future<void> Function(_AssemblyClipDeskOpEntry, int)
    runAlignDuration,
    required int? Function(String) parseDurationSeconds,
    required String Function(_AssemblyClipDeskOpEntry) subtitleMismatchLine,
    required Widget Function(String, String, {TextStyle? style})
    buildHighlightedText,
  }) {
    // Use virtual scrolling when item count > 100 for performance
    final useVirtualScrolling = visibleEntries.length > 100;

    if (useVirtualScrolling) {
      // Use FlutterListView for virtual scrolling
      return FlutterListView(
        delegate: FlutterListViewDelegate(
          (context, idx) {
            final item = visibleEntries[idx];
            return _buildShotCard(
              item: item,
              ordered: ordered,
              pausedStoryboardIds: pausedStoryboardIds,
              selectedStoryboardIds: selectedStoryboardIds,
              operationInProgress: operationInProgress,
              filterState: filterState,
              ctx: ctx,
              l10n: l10n,
              setLocalState: setLocalState,
              runDisable: runDisable,
              runEnableOrReplace: runEnableOrReplace,
              runAlignDuration: runAlignDuration,
              parseDurationSeconds: parseDurationSeconds,
              subtitleMismatchLine: subtitleMismatchLine,
              buildHighlightedText: buildHighlightedText,
            );
          },
          childCount: visibleEntries.length,
          // Configure cache extent for better performance
          // This determines how many pixels of content to cache outside the viewport
          onItemKey: (idx) =>
              visibleEntries[idx].storyboardNumericId.toString(),
        ),
      );
    } else {
      // Use standard ListView.builder for smaller lists
      return ListView.builder(
        itemCount: visibleEntries.length,
        itemBuilder: (context, idx) {
          final item = visibleEntries[idx];
          return _buildShotCard(
            item: item,
            ordered: ordered,
            pausedStoryboardIds: pausedStoryboardIds,
            selectedStoryboardIds: selectedStoryboardIds,
            operationInProgress: operationInProgress,
            filterState: filterState,
            ctx: ctx,
            l10n: l10n,
            setLocalState: setLocalState,
            runDisable: runDisable,
            runEnableOrReplace: runEnableOrReplace,
            runAlignDuration: runAlignDuration,
            parseDurationSeconds: parseDurationSeconds,
            subtitleMismatchLine: subtitleMismatchLine,
            buildHighlightedText: buildHighlightedText,
          );
        },
      );
    }
  }

  /// Build a single shot card widget
  Widget _buildShotCard({
    required _AssemblyClipDeskOpEntry item,
    required List<_AssemblyClipDeskOpEntry> ordered,
    required Set<int> pausedStoryboardIds,
    required Set<int> selectedStoryboardIds,
    required bool operationInProgress,
    required FilterState filterState,
    required BuildContext ctx,
    required AppLocalizations l10n,
    required void Function(void Function()) setLocalState,
    required Future<void> Function(_AssemblyClipDeskOpEntry) runDisable,
    required Future<void> Function(
      _AssemblyClipDeskOpEntry, {
      String? replacementUrl,
    })
    runEnableOrReplace,
    required Future<void> Function(_AssemblyClipDeskOpEntry, int)
    runAlignDuration,
    required int? Function(String) parseDurationSeconds,
    required String Function(_AssemblyClipDeskOpEntry) subtitleMismatchLine,
    required Widget Function(String, String, {TextStyle? style})
    buildHighlightedText,
  }) {
    final actualIndex = ordered.indexOf(item);
    final paused = pausedStoryboardIds.contains(item.storyboardNumericId);
    final canMoveUp = actualIndex > 0;
    final canMoveDown = actualIndex < ordered.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox for batch selection
            Checkbox(
              value: selectedStoryboardIds.contains(item.storyboardNumericId),
              onChanged: operationInProgress
                  ? null
                  : (checked) {
                      setLocalState(() {
                        if (checked == true) {
                          selectedStoryboardIds.add(item.storyboardNumericId);
                        } else {
                          selectedStoryboardIds.remove(
                            item.storyboardNumericId,
                          );
                        }
                      });
                    },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shortVideoSpaceProductionAssemblyScriptShotOrder(
                      item.scriptNumericId,
                      item.storyboardNumericId,
                      actualIndex + 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    paused
                        ? l10n.shortVideoSpaceProductionAssemblyStatusPaused
                        : l10n.shortVideoSpaceProductionAssemblyStatusEnabled(
                            item.selectedMediaKind,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l10n.shortVideoSpaceProductionAssemblyDurationLabel),
                      buildHighlightedText(
                        item.durationText.isEmpty
                            ? l10n.shortVideoSpaceProductionAssemblyDurationNotSet
                            : item.durationText,
                        filterState.searchKeyword,
                      ),
                      Text(l10n.shortVideoSpaceProductionAssemblySubtitleLabel),
                      Flexible(
                        child: buildHighlightedText(
                          item.subtitleText.isEmpty
                              ? l10n.shortVideoSpaceProductionAssemblySubtitleEmpty
                              : item.subtitleText,
                          filterState.searchInSubtitles
                              ? filterState.searchKeyword
                              : '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 配音状态展示
                  Text(
                    '${item.voiceoverScriptReady ? l10n.shortVideoSpaceProductionAssemblyVoiceoverScriptReady : l10n.shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady} · '
                    '${item.voiceoverAssetReady ? l10n.shortVideoSpaceProductionAssemblyVoiceoverAssetReady : l10n.shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady}',
                  ),
                  if (item.voiceoverState.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyVoiceoverStatusLabel,
                        ),
                        buildHighlightedText(
                          item.voiceoverState,
                          filterState.searchInVoiceover
                              ? filterState.searchKeyword
                              : '',
                        ),
                      ],
                    ),
                  ],
                  if (item.voiceoverAudioUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyVoiceoverAudioLabel,
                        ),
                        Flexible(
                          child: buildHighlightedText(
                            item.voiceoverAudioUrl,
                            filterState.searchInVoiceover
                                ? filterState.searchKeyword
                                : '',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.voiceoverState == 'failed' &&
                      item.voiceoverError.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyVoiceoverErrorLabel,
                        ),
                        Flexible(
                          child: buildHighlightedText(
                            item.voiceoverError,
                            filterState.searchInVoiceover
                                ? filterState.searchKeyword
                                : '',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${l10n.shortVideoSpaceProductionAssemblyMismatchCheckLabel}${subtitleMismatchLine(item)}',
                  ),
                  const SizedBox(height: 8),
                  StudioDenseActionRow(
                    children: [
                      OutlinedButton(
                        style: studioFormSecondaryButtonStyle(context),
                        onPressed: (canMoveUp && !operationInProgress)
                            ? () {
                                final current = ordered[actualIndex];
                                ordered[actualIndex] = ordered[actualIndex - 1];
                                ordered[actualIndex - 1] = current;
                                setLocalState(() {});
                              }
                            : null,
                        child: Text(
                          l10n.shortVideoSpaceProductionAssemblyMoveUp,
                        ),
                      ),
                      OutlinedButton(
                        style: studioFormSecondaryButtonStyle(context),
                        onPressed: (canMoveDown && !operationInProgress)
                            ? () {
                                final current = ordered[actualIndex];
                                ordered[actualIndex] = ordered[actualIndex + 1];
                                ordered[actualIndex + 1] = current;
                                setLocalState(() {});
                              }
                            : null,
                        child: Text(
                          l10n.shortVideoSpaceProductionAssemblyMoveDown,
                        ),
                      ),
                      FilledButton.tonal(
                        style: studioFormTonalButtonStyle(context),
                        onPressed: operationInProgress
                            ? null
                            : () {
                                if (paused) {
                                  unawaited(runEnableOrReplace(item));
                                } else {
                                  unawaited(runDisable(item));
                                }
                              },
                        child: Text(
                          paused
                              ? l10n.shortVideoSpaceProductionAssemblyEnable
                              : l10n.shortVideoSpaceProductionAssemblyPause,
                        ),
                      ),
                      OutlinedButton(
                        style: studioFormSecondaryButtonStyle(context),
                        onPressed: operationInProgress
                            ? null
                            : () async {
                                final ctrl = TextEditingController(
                                  text:
                                      parseDurationSeconds(
                                        item.durationText,
                                      )?.toString() ??
                                      '',
                                );
                                final picked = await showStudioDialog<int>(
                                  context: ctx,
                                  builder: (dCtx) => StudioAlertDialog(
                                    title: Text(
                                      l10n.shortVideoSpaceProductionAssemblySingleShotDurationTitle,
                                    ),
                                    content: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: l10n
                                            .shortVideoSpaceProductionAssemblySingleShotDurationLabel,
                                        hintText: l10n
                                            .shortVideoSpaceProductionAssemblySingleShotDurationHint,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dCtx).pop(),
                                        child: Text(
                                          l10n.shortVideoSpaceProductionAssemblyCancel,
                                        ),
                                      ),
                                      FilledButton(
                                        style: studioFormPrimaryButtonStyle(context),
                                        onPressed: () {
                                          final sec = int.tryParse(
                                            ctrl.text.trim(),
                                          );
                                          Navigator.of(dCtx).pop(sec);
                                        },
                                        child: Text(
                                          l10n.shortVideoSpaceProductionAssemblyAlignAndWriteBack,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                ctrl.dispose();
                                if (picked == null ||
                                    picked <= 0 ||
                                    picked > 300) {
                                  return;
                                }
                                unawaited(runAlignDuration(item, picked));
                              },
                        child: Text(
                          l10n.shortVideoSpaceProductionAssemblyAlignDuration,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: operationInProgress
                            ? null
                            : () async {
                                final nextUrl =
                                    await _promptReplacementVideoUrl(
                                      ctx,
                                      initialValue: item.selectedMediaUrl,
                                    );
                                if ((nextUrl ?? '').trim().isEmpty) {
                                  return;
                                }
                                unawaited(
                                  runEnableOrReplace(
                                    item,
                                    replacementUrl: nextUrl,
                                  ),
                                );
                              },
                        child: Text(
                          l10n.shortVideoSpaceProductionAssemblyReplaceVersion,
                        ),
                      ),
                      // Generate voiceover button
                      if (item.voiceoverScriptReady)
                        FilledButton.icon(
                          style: studioFormIconLabeledButtonStyle(context),
                          onPressed: operationInProgress
                              ? null
                              : () async {
                                  await _generateSingleVoiceover(
                                    item: item,
                                    context: ctx,
                                    showFeedback: _showOperationFeedback,
                                  );
                                  setLocalState(() {});
                                },
                          icon: const Icon(Icons.record_voice_over),
                          label: Text(
                            l10n.shortVideoSpaceProductionAssemblyGenerateVoiceover,
                          ),
                        ),
                      // Preview voiceover audio button
                      if (item.voiceoverAudioUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: operationInProgress
                              ? null
                              : () {
                                  _showAudioPreviewDialog(
                                    context: ctx,
                                    audioUrl: item.voiceoverAudioUrl,
                                  );
                                },
                          icon: const Icon(Icons.play_circle_outline),
                          label: Text(
                            l10n.shortVideoSpaceProductionAssemblyPreviewVoiceover,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssemblyDefaultsEditor() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final subtitleCtrl = TextEditingController(text: _subtitleStyle);
    final bgmCtrl = TextEditingController(text: _bgmStrategy);
    try {
      if (!mounted) return;
      await showStudioDialog<void>(
        context: context,
        builder: (ctx) {
          final l10n = resolveAppLocalizationsForErrors(ctx);
          return StudioAlertDialog(
            title: Text(
              l10n.shortVideoSpaceProductionAssemblyAssemblyStyleTitle,
            ),
            content: SizedBox(
              width: studioConstrainedDialogWidth(context, maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subtitleCtrl,
                    decoration: InputDecoration(
                      labelText: l10n
                          .shortVideoSpaceProductionAssemblySubtitleStyleLabel,
                      hintText: l10n
                          .shortVideoSpaceProductionAssemblySubtitleStyleHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bgmCtrl,
                    decoration: InputDecoration(
                      labelText: l10n
                          .shortVideoSpaceProductionAssemblyBgmStrategyLabel,
                      hintText:
                          l10n.shortVideoSpaceProductionAssemblyBgmStrategyHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.shortVideoSpaceProductionAssemblyStyleNote,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.shortVideoSpaceProductionAssemblyCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(ctx),
                onPressed: () async {
                  final nextSubtitle = subtitleCtrl.text.trim();
                  final nextBgm = bgmCtrl.text.trim();
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  final rootL10n = resolveAppLocalizationsForErrors(context);
                  try {
                    final updated = await updateProjectByProjectId(
                      token,
                      project.id,
                      <String, dynamic>{
                        'subtitleStyle': nextSubtitle.isEmpty
                            ? null
                            : nextSubtitle,
                        'bgmStrategy': nextBgm.isEmpty ? null : nextBgm,
                      },
                    );
                    if (!mounted) return;
                    setState(() {
                      _subtitleStyle = updated.subtitleStyle ?? '';
                      _bgmStrategy = updated.bgmStrategy ?? '';
                      _projects = _projects
                          .map((row) => row.id == updated.id ? updated : row)
                          .toList(growable: false);
                    });
                    final subtitleDisplay = _subtitleStyle.trim().isEmpty
                        ? rootL10n.shortVideoSpaceProductionAssemblyStyleDefault
                        : _subtitleStyle.trim();
                    final bgmDisplay = _bgmStrategy.trim().isEmpty
                        ? rootL10n.shortVideoSpaceProductionAssemblyStyleDefault
                        : _bgmStrategy.trim();
                    _showOperationFeedback(
                      rootL10n.shortVideoSpaceProductionAssemblyStyleUpdated(
                        subtitleDisplay,
                        bgmDisplay,
                      ),
                      isSuccess: true,
                    );
                    _invalidateProductionSnapshots();
                  } catch (e) {
                    if (!mounted) return;
                    _showOperationFeedback(
                      rootL10n
                          .shortVideoSpaceProductionAssemblyStyleWriteBackFailed(
                            describeUserVisibleApiErrorResolved(context, e),
                          ),
                      isSuccess: false,
                    );
                  }
                },
                child: Text(
                  l10n.shortVideoSpaceProductionAssemblySaveAndRefresh,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      subtitleCtrl.dispose();
      bgmCtrl.dispose();
    }
  }
}

class _AssemblyClipDeskOpEntry {
  const _AssemblyClipDeskOpEntry({
    required this.scriptNumericId,
    required this.storyboardId,
    required this.storyboardNumericId,
    required this.sbIndex,
    required this.selectedMediaUrl,
    required this.selectedMediaKind,
    required this.durationText,
    required this.subtitleText,
    required this.voiceoverScriptReady,
    required this.voiceoverAssetReady,
    required this.voiceoverState,
    required this.voiceoverAudioUrl,
    required this.voiceoverError,
  });

  final int scriptNumericId;
  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String selectedMediaUrl;
  final String selectedMediaKind;
  final String durationText;
  final String subtitleText;
  final bool voiceoverScriptReady;
  final bool voiceoverAssetReady;
  final String voiceoverState;
  final String voiceoverAudioUrl;
  final String voiceoverError;

  _AssemblyClipDeskOpEntry copyWith({
    String? selectedMediaUrl,
    String? durationText,
    String? subtitleText,
  }) {
    return _AssemblyClipDeskOpEntry(
      scriptNumericId: scriptNumericId,
      storyboardId: storyboardId,
      storyboardNumericId: storyboardNumericId,
      sbIndex: sbIndex,
      selectedMediaUrl: selectedMediaUrl ?? this.selectedMediaUrl,
      selectedMediaKind: selectedMediaKind,
      durationText: durationText ?? this.durationText,
      subtitleText: subtitleText ?? this.subtitleText,
      voiceoverScriptReady: voiceoverScriptReady,
      voiceoverAssetReady: voiceoverAssetReady,
      voiceoverState: voiceoverState,
      voiceoverAudioUrl: voiceoverAudioUrl,
      voiceoverError: voiceoverError,
    );
  }
}
