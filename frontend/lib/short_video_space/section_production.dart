// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

/// Production workflow methods for ShortVideoSpaceSection
String _localizedBatchOutcomeLabel(AppLocalizations l10n, String outcome) {
  switch (outcome.trim()) {
    case 'skipped_duplicate':
      return l10n.shortVideoBatchOutcomeSkippedDuplicate;
    case 'queued':
      return l10n.shortVideoBatchOutcomeQueued;
    default:
      return outcome.trim();
  }
}

String _formatBatchOutcomeSummary(
  AppLocalizations l10n,
  List<BatchStoryboardOutcomeV1> outcomes,
) {
  if (outcomes.isEmpty) {
    return '';
  }
  final counts = <String, int>{};
  for (final row in outcomes) {
    final key = row.outcome.trim();
    if (key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  if (counts.isEmpty) {
    return '';
  }
  final parts = counts.entries
      .map(
        (e) => l10n.shortVideoBatchOutcomeCount(
          _localizedBatchOutcomeLabel(l10n, e.key),
          e.value,
        ),
      )
      .toList(growable: false);
  return l10n.shortVideoBatchOutcomeSummary(parts.join(', '));
}

String _formatSkippedDuplicateVideoSummary(
  AppLocalizations l10n,
  WorkbenchGenerateVideoResponse generation,
) {
  final count = generation.skippedDuplicateCount;
  if (count <= 0) {
    return '';
  }
  final ids = generation.skippedDuplicateStoryboardIds;
  final preview = ids.take(8).join(', ');
  final suffix = ids.length > 8 ? '…' : '';
  return l10n.shortVideoBatchSkippedDuplicates(count, '$preview$suffix');
}

int _shortVideoSceneAssetCount(ProjectAssetsOverview? overview) {
  if (overview == null) {
    return 0;
  }
  for (final group in overview.byAssetType) {
    if (group.assetType == 'scene') {
      return group.items.length;
    }
  }
  return 0;
}

extension _ShortVideoSpaceSectionProductionExtension
    on _ShortVideoSpaceSectionState {
  int _candidatePendingStoryboardCount() {
    final readiness = _shotReadiness;
    if (readiness == null) {
      return 0;
    }
    return readiness.storyboards
        .where((s) => s.blockingReasons.contains('candidate_pending'))
        .length;
  }

  Future<void> _confirmStoryboardCandidates() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final readiness = _shotReadiness;
    if (token == null ||
        token.isEmpty ||
        project == null ||
        readiness == null) {
      return;
    }
    final pending = readiness.storyboards
        .where((s) => s.blockingReasons.contains('candidate_pending'))
        .toList(growable: false);
    if (pending.isEmpty) {
      return;
    }
    setState(() {
      _confirmCandidatesBusy = true;
      _projectConfigLine = null;
    });
    try {
      final byScript = <int, List<int>>{};
      for (final shot in pending) {
        final scriptId = shot.scriptNumericId;
        if (scriptId == null) {
          continue;
        }
        byScript.putIfAbsent(scriptId, () => <int>[]).add(shot.storyboardNumericId);
      }
      var updated = 0;
      for (final entry in byScript.entries) {
        final status = await postProductionWorkbenchConfirmStoryboardCandidatesV1(
          token,
          projectUuid: project.id,
          scriptId: entry.key,
          storyboardNumericIds: entry.value,
        );
        if (status >= 200 && status < 300) {
          updated += entry.value.length;
        }
      }
      if (!mounted) {
        return;
      }
      final l10nDone = resolveAppLocalizationsForErrors(context);
      setState(() {
        _confirmCandidatesBusy = false;
        _projectConfigLine = l10nDone.shortVideoProductionConfirmCandidatesDone(
          updated,
        );
      });
      await _loadProjectOverview();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10nErr = resolveAppLocalizationsForErrors(context);
      setState(() {
        _confirmCandidatesBusy = false;
        _projectConfigLine = l10nErr.shortVideoProductionBatchFailed(
          describeUserVisibleApiError(l10nErr, e),
        );
      });
    }
  }

  Future<void> _runBatchCandidateClips() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final stats = _projectStats;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final readiness = _shotReadiness;
    if (readiness != null && readiness.rollup.readyCount <= 0) {
      final l10n = resolveAppLocalizationsForErrors(context);
      final ui = buildShotReadinessUi(
        l10n: l10n,
        loadingProjectOverview: false,
        readiness: readiness,
        readinessUnavailable: false,
      );
      setState(() {
        _projectConfigLine = [
          if (ui.headline != null) ui.headline!,
          ...ui.shotDetailLines.take(2),
        ].join(' · ');
      });
      return;
    }
    if ((stats?.storyboardCount ?? 0) <= 0) {
      setState(() {
        _projectConfigLine =
            resolveAppLocalizationsForErrors(context).shortVideoProductionBatchNoStoryboards;
      });
      return;
    }
    setState(() {
      _batchCandidateBusy = true;
      _projectConfigLine = null;
    });
    try {
      final detail = await fetchProjectByProjectId(token, project.id);
      if (!mounted) {
        return;
      }
      if (detail.scripts.isEmpty) {
        setState(() {
          _batchCandidateBusy = false;
          _projectConfigLine =
              resolveAppLocalizationsForErrors(context).shortVideoProductionBatchNoScripts;
        });
        return;
      }
      final scriptNumericId = detail.scripts.first.numericId;
      final res = await postProductionWorkbenchBatchGenerateCandidateClipsV1(
        token,
        projectUuid: project.id,
        scriptId: scriptNumericId,
      );
      if (!mounted) {
        return;
      }
      final l10nQueued = resolveAppLocalizationsForErrors(context);
      setState(() {
        _batchCandidateBusy = false;
        final outcomeSummary = _formatBatchOutcomeSummary(l10nQueued, res.outcomes);
        final duplicateSummary =
            _formatSkippedDuplicateVideoSummary(l10nQueued, res.generation);
        _projectConfigLine = [
          l10nQueued.shortVideoProductionBatchQueued(
            res.generation.total,
            res.appliedDefaults.trackId,
            res.appliedDefaults.resolution,
            res.appliedDefaults.duration,
            res.skipped.length,
          ),
          if (outcomeSummary.isNotEmpty) outcomeSummary,
          if (duplicateSummary.isNotEmpty) duplicateSummary,
        ].join(' · ');
      });
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      final l10nErr = resolveAppLocalizationsForErrors(context);
      final blocked = formatGenerationBlockedFromRustApiException(l10nErr, e);
      setState(() {
        _batchCandidateBusy = false;
        _projectConfigLine = blocked != null && blocked.isNotEmpty
            ? blocked
            : l10nErr.shortVideoProductionBatchFailed(
                describeUserVisibleApiError(l10nErr, e),
              );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10nErr = resolveAppLocalizationsForErrors(context);
      setState(() {
        _batchCandidateBusy = false;
        _projectConfigLine = l10nErr.shortVideoProductionBatchFailed(
          describeUserVisibleApiError(l10nErr, e),
        );
      });
    }
  }

  Future<void> _loadProjectOverview() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      if (mounted) {
        setState(() {
          _projectStats = null;
          _recentProjectTasks = null;
          _qualityScopeInsight = null;
          _badCaseStats = const <BadCaseStatItem>[];
          _sceneAssetCount = 0;
          _clipAssetCount = 0;
          _shotReadiness = null;
          _shotReadinessUnavailable = false;
          _productionOverview = null;
          _projectAssetsOverview = null;
          _shortVideoAssembly = null;
          _shortVideoExportCheck = null;
          _candidateCompareRows = const <ProductionStoryboardItemV1>[];
          _candidateCompareReviews = const <QualityReview>[];
          _publishMatrix = null;
          _publishUnavailable = false;
          _publishDrafts = const <PublishDraftRow>[];
          _publishPrepare = null;
          _publishJobs = const <PublishJobRow>[];
          _publishPerfAlerts = const <PublishPerformanceAlertRow>[];
          _publishAuditRows = const <PublishAttemptAuditRow>[];
          _publishAutomationModesByPlatform = <String, String>{};
          _publishBusy = false;
          _publishCopyEditorRevision = 0;
        });
      }
      return;
    }
    setState(() {
      _loadingProjectOverview = true;
      _projectStats = null;
      _recentProjectTasks = null;
      _qualityScopeInsight = null;
      _badCaseStats = const <BadCaseStatItem>[];
      _sceneAssetCount = 0;
      _clipAssetCount = 0;
      _shotReadiness = null;
      _shotReadinessUnavailable = false;
      _productionOverview = null;
      _projectAssetsOverview = null;
      _shortVideoAssembly = null;
      _shortVideoExportCheck = null;
      _candidateCompareRows = const <ProductionStoryboardItemV1>[];
      _candidateCompareReviews = const <QualityReview>[];
      _publishMatrix = null;
      _publishUnavailable = false;
      _publishDrafts = const <PublishDraftRow>[];
      _publishPrepare = null;
      _publishJobs = const <PublishJobRow>[];
      _publishPerfAlerts = const <PublishPerformanceAlertRow>[];
      _publishAuditRows = const <PublishAttemptAuditRow>[];
      _publishAutomationModesByPlatform = <String, String>{};
      _publishBusy = false;
      _publishCopyEditorRevision = 0;
    });
    try {
      Future<ProjectProductionOverview?> loadProductionOverview() async {
        try {
          return await fetchProjectProductionOverviewByProjectId(
            token,
            project.id,
          );
        } catch (_) {
          return null;
        }
      }

      Future<ProjectAssetsOverview?> loadProjectAssetsOverview() async {
        try {
          return await fetchProjectAssetsOverviewByProjectId(token, project.id);
        } catch (_) {
          return null;
        }
      }

      final results = await Future.wait<Object?>([
        fetchProjectStatsByProjectId(token, project.id),
        postTasksGetTaskApi(
          token,
          page: 1,
          limit: 6,
          projectId: project.numericId,
        ),
        fetchQualityScopeInsights(
          token,
          projectId: project.numericId,
          limit: 1,
        ),
        fetchBadCaseStats(token, projectId: project.numericId, limit: 3),
        loadProductionOverview(),
        loadProjectAssetsOverview(),
      ]);
      if (!mounted) {
        return;
      }
      if (_selectedProjectId != project.id) {
        return;
      }
      ProjectShortVideoAssembly? assemblySlice;
      ProjectShortVideoExportCheck? exportCheckSlice;
      ProjectShortVideoReadiness? shotReadiness;
      var candidateCompareRows = <ProductionStoryboardItemV1>[];
      var candidateCompareReviews = <QualityReview>[];
      var shotUnavailable = false;
      PublishPlatformMatrixResponse? publishMatrixSnap;
      var publishUnavailableSnap = false;
      var publishDraftsSnap = <PublishDraftRow>[];
      PublishPrepareCheckResponse? publishPrepareSnap;
      var publishJobsSnap = <PublishJobRow>[];
      var publishPerfAlertsSnap = <PublishPerformanceAlertRow>[];
      var publishAuditsSnap = <PublishAttemptAuditRow>[];
      await Future.wait([
        Future(() async {
          try {
            assemblySlice = await fetchProjectShortVideoAssemblyByProjectId(
              token,
              project.id,
            );
          } catch (_) {
            assemblySlice = null;
          }
        }),
        Future(() async {
          try {
            exportCheckSlice =
                await fetchProjectShortVideoExportCheckByProjectId(
                  token,
                  project.id,
                );
          } catch (_) {
            exportCheckSlice = null;
          }
        }),
        Future(() async {
          try {
            shotReadiness = await fetchProjectShortVideoReadinessByProjectId(
              token,
              project.id,
            );
          } catch (_) {
            shotReadiness = null;
            shotUnavailable = true;
          }
        }),
        Future(() async {
          final snapshot = await _capturePublishSlice(
            project,
            token,
            _selectedPublishDraftId,
          );
          publishMatrixSnap = snapshot.matrix;
          publishUnavailableSnap = snapshot.unavailable;
          publishDraftsSnap = snapshot.drafts;
          publishPrepareSnap = snapshot.prepare;
          publishJobsSnap = snapshot.jobs;
          publishPerfAlertsSnap = snapshot.perfAlerts;
          publishAuditsSnap = snapshot.audits;
        }),
        Future(() async {
          try {
            final detail = await fetchProjectByProjectId(token, project.id);
            final storyboardRows = <ProductionStoryboardItemV1>[];
            for (final script in detail.scripts.take(6)) {
              final resp = await postProductionGetStoryboardDataV1(
                token,
                projectUuid: project.id,
                scriptId: script.numericId,
              );
              storyboardRows.addAll(resp.data);
            }
            candidateCompareRows = storyboardRows;
            candidateCompareReviews = await fetchQualityReviews(
              token,
              projectId: project.numericId,
              targetType: 'storyboard',
              limit: 60,
            );
          } catch (_) {
            candidateCompareRows = <ProductionStoryboardItemV1>[];
            candidateCompareReviews = <QualityReview>[];
          }
        }),
      ]);
      if (!mounted || _selectedProjectId != project.id) {
        return;
      }
      final stats = results[0] as ProjectStats;
      final assetsOverview = results[5] as ProjectAssetsOverview?;
      setState(() {
        _projectStats = stats;
        _recentProjectTasks = results[1] as TaskCenterGetTaskApiResult;
        final scopeRows = results[2] as List<QualityScopeInsightRow>;
        _qualityScopeInsight = scopeRows.isEmpty ? null : scopeRows.first;
        _badCaseStats = results[3] as List<BadCaseStatItem>;
        _sceneAssetCount = _shortVideoSceneAssetCount(assetsOverview);
        _clipAssetCount = stats.storyboardCount;
        _productionOverview = results[4] as ProjectProductionOverview?;
        _projectAssetsOverview = assetsOverview;
        _shortVideoAssembly = assemblySlice;
        _shortVideoTimeline = null;
        _shortVideoExportCheck = exportCheckSlice;
        _candidateCompareRows = candidateCompareRows;
        _candidateCompareReviews = candidateCompareReviews;
        _shotReadiness = shotReadiness;
        _shotReadinessUnavailable = shotUnavailable;
        _publishMatrix = publishMatrixSnap;
        _publishUnavailable = publishUnavailableSnap;
        _publishDrafts = publishDraftsSnap;
        _syncSelectedPublishDraftWith(publishDraftsSnap);
        _publishPrepare = publishPrepareSnap;
        _publishJobs = publishJobsSnap;
        _publishPerfAlerts = publishPerfAlertsSnap;
        _publishAuditRows = publishAuditsSnap;
        _syncPublishAutomationModesFromMatrix();
      });
      _panelVersionManager.updateVersion(
        'export',
        exportCheckSlice?.dataVersion,
      );
      _panelVersionManager.updateVersion(
        'assembly',
        exportCheckSlice?.dataVersion ?? assemblySlice?.schemaVersion.toString(),
      );
      if (_activeAssemblyJob != null) {
        unawaited(_refreshActiveAssemblyJob());
      }
      await _loadDraftsAndVersions();
      await _loadProjectCharacters();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectStats = null;
        _recentProjectTasks = null;
        _qualityScopeInsight = null;
        _badCaseStats = const <BadCaseStatItem>[];
        _sceneAssetCount = 0;
        _clipAssetCount = 0;
        _shotReadiness = null;
        _shotReadinessUnavailable = false;
        _productionOverview = null;
        _projectAssetsOverview = null;
        _shortVideoAssembly = null;
        _shortVideoExportCheck = null;
        _candidateCompareRows = const <ProductionStoryboardItemV1>[];
        _candidateCompareReviews = const <QualityReview>[];
        _publishMatrix = null;
        _publishUnavailable = false;
        _publishDrafts = const <PublishDraftRow>[];
        _publishPrepare = null;
        _publishJobs = const <PublishJobRow>[];
        _publishPerfAlerts = const <PublishPerformanceAlertRow>[];
        _publishAuditRows = const <PublishAttemptAuditRow>[];
        _publishAutomationModesByPlatform = <String, String>{};
        _publishBusy = false;
        _publishCopyEditorRevision = 0;
        _assemblyDrafts = const <AssemblyDraft>[];
        _assemblyVersions = const <AssemblyVersion>[];
        _currentAssemblyVersionId = 'default';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjectOverview = false;
        });
      }
    }
  }

  Future<void> _selectComparedStoryboardVideo(
    ProductionStoryboardItemV1 row,
    String videoUrl,
  ) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final trimmed = videoUrl.trim();
    if (token == null ||
        token.isEmpty ||
        project == null ||
        row.scriptId == null ||
        trimmed.isEmpty) {
      return;
    }
    setState(() {
      _projectConfigLine = resolveAppLocalizationsForErrors(context)
          .shortVideoProductionSetCurrentConfirming(row.id);
    });
    try {
      await postWorkbenchStoryboardMediaOpV1(
        token,
        buildStoryboardMediaOpBodyV1(
          base: <String, dynamic>{
            'op': 'selectVideo',
            'scriptId': row.scriptId,
            'storyboardId': row.id,
            'videoUrl': trimmed,
          },
          projectUuid: project.id,
          projectId: project.numericId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _projectConfigLine = resolveAppLocalizationsForErrors(context)
            .shortVideoProductionSetCurrentDone(row.id);
      });
      await _loadProjectOverview();
    } catch (e) {
      if (!mounted) return;
      final l10nErr = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = l10nErr.shortVideoProductionSetCurrentFailed(
          describeUserVisibleApiError(l10nErr, e),
        );
      });
    }
  }

  Future<void> _setComparedStoryboardCurrent(
    ProductionStoryboardItemV1 row,
  ) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final videoUrl = row.mediaSlots?.currentVideoUrl?.trim() ?? '';
    if (token == null ||
        token.isEmpty ||
        project == null ||
        row.scriptId == null ||
        videoUrl.isEmpty) {
      return;
    }
    setState(() {
      _projectConfigLine =
          resolveAppLocalizationsForErrors(context).shortVideoProductionSetCurrentConfirming(
            row.id,
          );
    });
    try {
      await postWorkbenchStoryboardMediaOpV1(
        token,
        buildStoryboardMediaOpBodyV1(
          base: <String, dynamic>{
            'op': 'selectVideo',
            'scriptId': row.scriptId,
            'storyboardId': row.id,
            'videoUrl': videoUrl,
          },
          projectUuid: project.id,
          projectId: project.numericId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _projectConfigLine =
            resolveAppLocalizationsForErrors(context).shortVideoProductionSetCurrentDone(
              row.id,
            );
      });
      await _loadProjectOverview();
    } catch (e) {
      if (!mounted) return;
      final l10nErr = resolveAppLocalizationsForErrors(context);
      setState(() {
        _projectConfigLine = l10nErr.shortVideoProductionSetCurrentFailed(
          describeUserVisibleApiError(l10nErr, e),
        );
      });
    }
  }
}
