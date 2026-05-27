// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// Core publish operations: draft management, job enqueueing, publish slice.
extension ShortVideoPublishOperations on _ShortVideoSpaceSectionState {
  Future<
    ({
      PublishPlatformMatrixResponse? matrix,
      bool matrixLoaded,
      bool unavailable,
      List<PublishDraftRow> drafts,
      bool draftsLoaded,
      PublishPrepareCheckResponse? prepare,
      bool prepareLoaded,
      List<PublishJobRow> jobs,
      bool jobsLoaded,
      List<PublishPerformanceAlertRow> perfAlerts,
      bool perfAlertsLoaded,
      List<PublishAttemptAuditRow> audits,
      bool auditsLoaded,
    })
  >
  _capturePublishSlice(
    ProjectRow project,
    String token,
    String? preferredDraftId,
  ) async {
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
      return (
        matrix: null,
        matrixLoaded: false,
        unavailable: false,
        drafts: widget.debugPublishDrafts ?? _publishDrafts,
        draftsLoaded: true,
        prepare: null,
        prepareLoaded: false,
        jobs: const <PublishJobRow>[],
        jobsLoaded: true,
        perfAlerts: const <PublishPerformanceAlertRow>[],
        perfAlertsLoaded: true,
        audits: const <PublishAttemptAuditRow>[],
        auditsLoaded: true,
      );
    }
    var unavailable = false;

    PublishPlatformMatrixResponse? matrix;
    var matrixLoaded = false;
    try {
      matrix = await fetchPublishPlatformMatrix(token, project.id);
      matrixLoaded = true;
    } catch (_) {
      unavailable = true;
    }

    List<PublishDraftRow> drafts;
    var draftsLoaded = false;
    try {
      drafts = await fetchPublishDrafts(token, project.id);
      draftsLoaded = true;
    } catch (_) {
      unavailable = true;
      drafts = <PublishDraftRow>[];
    }

    List<PublishJobRow> jobs;
    var jobsLoaded = false;
    try {
      jobs = await fetchPublishJobs(token, project.id);
      jobsLoaded = true;
    } catch (_) {
      unavailable = true;
      jobs = <PublishJobRow>[];
    }

    List<PublishPerformanceAlertRow> perfAlerts;
    var perfAlertsLoaded = false;
    try {
      perfAlerts = await fetchPublishPerformanceAlerts(token, project.id);
      perfAlertsLoaded = true;
    } catch (_) {
      unavailable = true;
      perfAlerts = <PublishPerformanceAlertRow>[];
    }

    List<PublishAttemptAuditRow> audits;
    var auditsLoaded = false;
    try {
      audits = await fetchPublishAudit(token, project.id, limit: 30);
      auditsLoaded = true;
    } catch (_) {
      unavailable = true;
      audits = <PublishAttemptAuditRow>[];
    }

    PublishPrepareCheckResponse? prepare;
    var prepareLoaded = false;
    if (draftsLoaded && drafts.isEmpty) {
      prepareLoaded = true;
    }
    if (draftsLoaded && drafts.isNotEmpty) {
      String? prepareDraftId;
      if (drafts.length == 1) {
        prepareDraftId = drafts.first.id;
      } else {
        final pref = preferredDraftId;
        if (pref != null &&
            pref.trim().isNotEmpty &&
            drafts.any((d) => d.id == pref)) {
          prepareDraftId = pref;
        }
      }
      if (prepareDraftId == null) {
        prepareLoaded = true;
      } else {
        try {
          prepare = await fetchPublishPrepareCheck(
            token,
            project.id,
            prepareDraftId,
          );
          prepareLoaded = true;
        } catch (_) {
          unavailable = true;
        }
      }
    }

    return (
      matrix: matrix,
      matrixLoaded: matrixLoaded,
      unavailable: unavailable,
      drafts: drafts,
      draftsLoaded: draftsLoaded,
      prepare: prepare,
      prepareLoaded: prepareLoaded,
      jobs: jobs,
      jobsLoaded: jobsLoaded,
      perfAlerts: perfAlerts,
      perfAlertsLoaded: perfAlertsLoaded,
      audits: audits,
      auditsLoaded: auditsLoaded,
    );
  }

  List<Map<String, dynamic>> _publishTargetMaps() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _targetPlatforms.length; i++) {
      final p = _targetPlatforms[i];
      final mode = _publishAutomationModesByPlatform[p]?.trim();
      out.add(<String, dynamic>{
        'platform_id': p,
        'automation_mode': mode == null || mode.isEmpty ? 'semi_auto' : mode,
        'serial_order': i,
        'extra': <String, dynamic>{},
      });
    }
    return out;
  }

  void _syncPublishAutomationModesFromMatrix() {
    final matrix = _publishMatrix;
    final next = <String, String>{};
    for (final pid in _targetPlatforms) {
      final existing = _publishAutomationModesByPlatform[pid];
      if (existing != null && existing.trim().isNotEmpty) {
        next[pid] = existing.trim();
        continue;
      }
      String fallback = 'semi_auto';
      if (matrix != null) {
        for (final row in matrix.platforms) {
          if (row.platformId == pid && row.automationMode.trim().isNotEmpty) {
            fallback = row.automationMode.trim();
            break;
          }
        }
      }
      next[pid] = fallback;
    }
    _publishAutomationModesByPlatform = next;
  }

  Future<void> _refreshPublishSlice(ProjectRow project, String token) async {
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    final requestId = _beginPublishRefreshRequest();
    ProjectShortVideoExportCheck? exportCheckSnapshot = _shortVideoExportCheck;
    try {
      exportCheckSnapshot = await fetchProjectShortVideoExportCheckByProjectId(
        token,
        project.id,
      );
    } catch (_) {}

    final snapshot = await _capturePublishSlice(
      project,
      token,
      _selectedPublishDraftId,
    );
    if (!mounted ||
        _selectedProjectId != project.id ||
        !_isLatestPublishRefreshRequest(requestId)) {
      return;
    }
    setState(() {
      _shortVideoExportCheck = exportCheckSnapshot;
      if (snapshot.matrixLoaded) {
        _publishMatrix = snapshot.matrix;
      }
      _publishUnavailable = snapshot.unavailable;
      if (snapshot.draftsLoaded) {
        _publishDrafts = snapshot.drafts;
        _syncSelectedPublishDraftWith(snapshot.drafts);
        _syncSelectedDraftIdsWith(snapshot.drafts);
      }
      if (snapshot.prepareLoaded) {
        _publishPrepare = snapshot.prepare;
      }
      if (snapshot.jobsLoaded) {
        _publishJobs = snapshot.jobs;
      }
      if (snapshot.perfAlertsLoaded) {
        _publishPerfAlerts = snapshot.perfAlerts;
      }
      if (snapshot.auditsLoaded) {
        _publishAuditRows = snapshot.audits;
      }
      _syncPublishAutomationModesFromMatrix();
    });
  }

  Future<void> _bootstrapPublishDraft() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final title = (project.name ?? '').trim();
      final created =
          await createPublishDraft(token, project.id, <String, dynamic>{
            'title': title.isEmpty
                ? l10n.shortVideoPublishOpsDefaultDraftTitle
                : title,
            'draft_status': 'editing',
            'tags': <String>[],
            'platform_copy': <String, dynamic>{},
          });
      final draftId = created.id;
      final targets = _publishTargetMaps();
      if (targets.isNotEmpty) {
        await upsertPublishTargets(token, project.id, draftId, targets);
      }
      _selectedPublishDraftId = draftId;
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishOpsDraftCreated)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.shortVideoPublishOpsCreateDraftFailed(
                describeUserVisibleApiErrorResolved(context, e),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _enqueuePublishJob() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      var drafts = await fetchPublishDrafts(token, project.id);
      if (drafts.isEmpty) {
        final title = (project.name ?? '').trim();
        final created =
            await createPublishDraft(token, project.id, <String, dynamic>{
              'title': title.isEmpty
                  ? l10n.shortVideoPublishOpsDefaultDraftTitle
                  : title,
              'draft_status': 'editing',
              'tags': <String>[],
              'platform_copy': <String, dynamic>{},
            });
        drafts = [created];
        if (mounted) {
          setState(() {
            _selectedPublishDraftId = created.id;
          });
        } else {
          _selectedPublishDraftId = created.id;
        }
      }
      if (drafts.isEmpty) {
        return;
      }
      final draftId = _resolvePublishDraftIdFromList(drafts);
      if (draftId == null) {
        if (mounted && drafts.length > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.shortVideoPublishOpsSelectActiveDraftWhenMany(
                  l10n.shortVideoPublishPanelCurrentDraftLabel,
                ),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final targets = _publishTargetMaps();
      if (targets.isNotEmpty) {
        await upsertPublishTargets(token, project.id, draftId, targets);
      }
      await createPublishJob(token, project.id, draftId);
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishOpsJobSubmitted)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.shortVideoPublishOpsEnqueueFailed(
                describeUserVisibleApiErrorResolved(context, e),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _enqueueAllDraftJobs() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_publishDrafts.isEmpty) {
      return;
    }
    setState(() {
      _publishBusy = true;
      _publishBatchResultLines = const <String>[];
    });
    try {
      final summary = <String>[];
      final targets = _publishTargetMaps();
      var ok = 0;
      for (final draft in _publishDrafts) {
        try {
          if (targets.isNotEmpty) {
            await upsertPublishTargets(token, project.id, draft.id, targets);
          }
          await createPublishJob(token, project.id, draft.id);
          ok++;
          final title = draft.title.trim().isEmpty
              ? draft.id
              : draft.title.trim();
          summary.add(l10n.shortVideoPublishOpsBatchLineOk(title));
        } catch (e) {
          if (!mounted) return;
          summary.add(
            l10n.shortVideoPublishOpsBatchLineFail(
              draft.id,
              describeUserVisibleApiErrorResolved(context, e),
            ),
          );
        }
      }
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      setState(() {
        _publishBatchResultLines = summary;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoPublishOpsBatchEnqueueResult(
              ok,
              _publishDrafts.length,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _retryFailedPublishJobs() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final failed = _publishJobs
        .where((j) => j.status == 'failed' || j.status == 'partial_failed')
        .toList(growable: false);
    if (failed.isEmpty) {
      return;
    }
    setState(() {
      _publishBusy = true;
      _publishBatchResultLines = const <String>[];
    });
    try {
      final summary = <String>[];
      var ok = 0;
      for (final job in failed) {
        try {
          await retryPublishJob(token, project.id, job.id);
          ok++;
          summary.add(
            l10n.shortVideoPublishOpsBatchLineRetryOk(job.id.substring(0, 8)),
          );
        } catch (e) {
          if (!mounted) return;
          summary.add(
            l10n.shortVideoPublishOpsBatchLineFail(
              job.id.substring(0, 8),
              describeUserVisibleApiErrorResolved(context, e),
            ),
          );
        }
      }
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      setState(() {
        _publishBatchResultLines = summary;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoPublishOpsBatchRetryResult(ok, failed.length),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _confirmSemiAutoPublish() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    String? jobId;
    for (final j in _publishJobs) {
      if (j.status == 'awaiting_confirmation') {
        jobId = j.id;
        break;
      }
    }
    if (jobId == null) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      await confirmSemiAutoPublishJob(token, project.id, jobId);
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shortVideoPublishOpsSemiAutoConfirmed)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.shortVideoPublishOpsConfirmFailed(
                describeUserVisibleApiErrorResolved(context, e),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }
}
