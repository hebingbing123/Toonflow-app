// ignore_for_file: invalid_use_of_protected_member, library_private_types_in_public_api

part of 'section.dart';

/// Extension containing core publish operations for ShortVideoSpaceSection.
/// Includes draft management, job enqueueing, and publish slice operations.
extension ShortVideoPublishOperations on _ShortVideoSpaceSectionState {
  Future<
      ({
        PublishPlatformMatrixResponse? matrix,
        bool unavailable,
        List<PublishDraftRow> drafts,
        PublishPrepareCheckResponse? prepare,
        List<PublishJobRow> jobs,
        List<PublishPerformanceAlertRow> perfAlerts,
        List<PublishAttemptAuditRow> audits,
      })> _capturePublishSlice(
    ProjectRow project,
    String token,
    String? preferredDraftId,
  ) async {
    try {
      final matrix = await fetchPublishPlatformMatrix(token, project.id);
      final drafts = await fetchPublishDrafts(token, project.id);
      final jobs = await fetchPublishJobs(token, project.id);
      final perfAlerts = await fetchPublishPerformanceAlerts(token, project.id);
      final audits = await fetchPublishAudit(token, project.id, limit: 30);
      PublishPrepareCheckResponse? prepare;
      if (drafts.isNotEmpty) {
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
        if (prepareDraftId != null) {
          prepare = await fetchPublishPrepareCheck(
            token,
            project.id,
            prepareDraftId,
          );
        }
      }
      return (
        matrix: matrix,
        unavailable: false,
        drafts: drafts,
        prepare: prepare,
        jobs: jobs,
        perfAlerts: perfAlerts,
        audits: audits,
      );
    } catch (_) {
      return (
        matrix: null,
        unavailable: true,
        drafts: <PublishDraftRow>[],
        prepare: null,
        jobs: <PublishJobRow>[],
        perfAlerts: <PublishPerformanceAlertRow>[],
        audits: <PublishAttemptAuditRow>[],
      );
    }
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
    final snapshot = await _capturePublishSlice(
      project,
      token,
      _selectedPublishDraftId,
    );
    if (!mounted || _selectedProjectId != project.id) {
      return;
    }
    setState(() {
      _publishMatrix = snapshot.matrix;
      _publishUnavailable = snapshot.unavailable;
      _publishDrafts = snapshot.drafts;
      _syncSelectedPublishDraftWith(snapshot.drafts);
      _publishPrepare = snapshot.prepare;
      _publishJobs = snapshot.jobs;
      _publishPerfAlerts = snapshot.perfAlerts;
      _publishAuditRows = snapshot.audits;
      _syncPublishAutomationModesFromMatrix();
    });
  }

  Future<void> _bootstrapPublishDraft() async {
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
      final created = await createPublishDraft(token, project.id, <String, dynamic>{
        'title': title.isEmpty ? '发布草稿' : title,
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
        const SnackBar(content: Text('已创建发布草稿并写入平台目标。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布草稿失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布草稿失败：$e')),
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
        final created = await createPublishDraft(token, project.id, <String, dynamic>{
          'title': title.isEmpty ? '发布草稿' : title,
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
            const SnackBar(
              content: Text('有多张发布草稿时，请先在「当前操作草稿」中选择一张。'),
              duration: Duration(seconds: 4),
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
        const SnackBar(content: Text('已投递发布作业（服务端 worker 将处理队列）。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投递失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('投递失败：$e')),
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
          final title = draft.title.trim().isEmpty ? draft.id : draft.title.trim();
          summary.add('OK · $title');
        } on RustApiException catch (e) {
          summary.add('FAIL · ${draft.id} · ${e.statusCode ?? '-'}');
        } catch (e) {
          summary.add('FAIL · ${draft.id} · $e');
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
        SnackBar(content: Text('批量投递完成：$ok/${_publishDrafts.length} 成功。')),
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
          summary.add('OK · 重试作业 ${job.id.substring(0, 8)}');
        } on RustApiException catch (e) {
          summary
              .add('FAIL · ${job.id.substring(0, 8)} · ${e.statusCode ?? '-'}');
        } catch (e) {
          summary.add('FAIL · ${job.id.substring(0, 8)} · $e');
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
        SnackBar(content: Text('批量重试完成：$ok/${failed.length} 成功。')),
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
        const SnackBar(content: Text('已确认半自动闸门，worker 将继续投递。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('确认失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('确认失败：$e')),
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
