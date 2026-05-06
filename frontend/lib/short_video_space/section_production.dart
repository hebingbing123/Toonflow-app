part of 'section.dart';

/// Production workflow methods for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionExtension on _ShortVideoSpaceSectionState {
  Future<void> _runBatchCandidateClips() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final stats = _projectStats;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if ((stats?.storyboardCount ?? 0) <= 0) {
      setState(() {
        _projectConfigLine = '还没有分镜，无法批量生成候选成片。';
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
          _projectConfigLine = '项目下没有剧本行，请先在项目区创建剧本后再试。';
        });
        return;
      }
      final scriptNumericId = detail.scripts.first.numericId;
      final res = await postProductionWorkbenchBatchGenerateCandidateClipsV1(
        token,
        projectId: project.numericId,
        scriptId: scriptNumericId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _batchCandidateBusy = false;
        _projectConfigLine =
            '已排队 ${res.generation.total} 条候选视频任务（轨道 #${res.appliedDefaults.trackId}，${res.appliedDefaults.resolution}，${res.appliedDefaults.duration}s）；跳过 ${res.skipped.length} 镜。';
      });
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batchCandidateBusy = false;
        _projectConfigLine = '批量候选成片失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batchCandidateBusy = false;
        _projectConfigLine = '批量候选成片失败：$e';
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
        fetchProjectAssetsByProjectId(
          token,
          project.id,
          assetType: 'scene',
          page: 1,
          limit: 1,
        ),
        fetchProjectAssetsByProjectId(
          token,
          project.id,
          assetType: 'clip',
          page: 1,
          limit: 1,
        ),
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
            assemblySlice =
                await fetchProjectShortVideoAssemblyByProjectId(token, project.id);
          } catch (_) {
            assemblySlice = null;
          }
        }),
        Future(() async {
          try {
            exportCheckSlice = await fetchProjectShortVideoExportCheckByProjectId(
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
                projectId: project.numericId,
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
      setState(() {
        _projectStats = results[0] as ProjectStats;
        _recentProjectTasks = results[1] as TaskCenterGetTaskApiResult;
        final scopeRows = results[2] as List<QualityScopeInsightRow>;
        _qualityScopeInsight = scopeRows.isEmpty ? null : scopeRows.first;
        _badCaseStats = results[3] as List<BadCaseStatItem>;
        _sceneAssetCount = (results[4] as ListAssetsResponse).total;
        _clipAssetCount = (results[5] as ListAssetsResponse).total;
        _productionOverview = results[6] as ProjectProductionOverview?;
        _projectAssetsOverview = results[7] as ProjectAssetsOverview?;
        _shortVideoAssembly = assemblySlice;
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
    } on RustApiException catch (_) {
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
      });
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
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjectOverview = false;
        });
      }
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
      _projectConfigLine = '正在确认分镜 #${row.id} 的当前视频版本…';
    });
    try {
      await postWorkbenchStoryboardMediaOpV1(
        token,
        <String, dynamic>{
          'op': 'selectVideo',
          'projectId': project.numericId,
          'scriptId': row.scriptId,
          'storyboardId': row.id,
          'videoUrl': videoUrl,
        },
      );
      if (!mounted) return;
      setState(() {
        _projectConfigLine = '已确认分镜 #${row.id} 的当前视频版本。';
      });
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _projectConfigLine = '设当前失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectConfigLine = '设当前失败：$e';
      });
    }
  }
}
