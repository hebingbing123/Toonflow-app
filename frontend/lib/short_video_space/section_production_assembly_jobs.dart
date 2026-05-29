part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionAssemblyJobs on _ShortVideoSpaceSectionState {
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
    _assemblyJobPollBackoffSeconds = 3;
    _scheduleAssemblyJobPoll();
    unawaited(_pollActiveAssemblyJobOnce());
  }

  void _scheduleAssemblyJobPoll() {
    _assemblyJobPollTimer?.cancel();
    _assemblyJobPollTimer = Timer.periodic(
      Duration(seconds: _assemblyJobPollBackoffSeconds),
      (_) => unawaited(_pollActiveAssemblyJobOnce()),
    );
  }

  bool _isAssemblyPollRateLimited(Object error) {
    if (error is RustApiException) {
      return error.statusCode == 429 || error.statusCode == 503;
    }
    return false;
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
          _assemblyTerminalJobStatuses.contains(_activeAssemblyJob!.status);
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
      _assemblyJobPollBackoffSeconds = 3;
      if (_assemblyTerminalJobStatuses.contains(row.status)) {
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
    } catch (e) {
      if (_isAssemblyPollRateLimited(e)) {
        _assemblyJobPollBackoffSeconds =
            (_assemblyJobPollBackoffSeconds * 2).clamp(3, 60);
        if (_activeAssemblyJob != null &&
            !_assemblyTerminalJobStatuses.contains(_activeAssemblyJob!.status)) {
          _scheduleAssemblyJobPoll();
        }
      }
    }
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
      await studioRunWithRenderLock(() async {
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
      }, reason: 'short_video_pre_assembly');
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
    try {
      await studioRunWithRenderLock(() async {
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
      }, reason: 'short_video_export');
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
          if (!_assemblyTerminalJobStatuses.contains(job.status)) {
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
}
