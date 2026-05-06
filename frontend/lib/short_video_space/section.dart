import 'dart:async';

import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'support.dart';
import 'view.dart';

class ShortVideoSpaceSection extends StatefulWidget {
  const ShortVideoSpaceSection({
    super.key,
    required this.accessToken,
    required this.onOpenProjects,
    required this.onSyncProjectContext,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
  });

  final String? accessToken;
  final VoidCallback onOpenProjects;
  final ValueChanged<int?> onSyncProjectContext;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;

  @override
  State<ShortVideoSpaceSection> createState() => _ShortVideoSpaceSectionState();
}

class _ShortVideoSpaceSectionState extends State<ShortVideoSpaceSection> {
  ShortVideoMode _mode = ShortVideoMode.animated;
  String _videoRatio = '9:16';
  String _targetMarket = 'domestic';
  List<String> _targetPlatforms = <String>['douyin'];
  String _durationStrategy = 'short';
  String _voiceProfile = '';
  String _subtitleStyle = '';
  String _bgmStrategy = '';
  bool _loadingProjects = false;
  bool _loadingProjectOverview = false;
  bool _batchCandidateBusy = false;
  bool _creatingProject = false;
  bool _savingProjectConfig = false;
  List<ProjectRow> _projects = const <ProjectRow>[];
  ProjectStats? _projectStats;
  TaskCenterGetTaskApiResult? _recentProjectTasks;
  QualityScopeInsightRow? _qualityScopeInsight;
  List<BadCaseStatItem> _badCaseStats = const <BadCaseStatItem>[];
  int _sceneAssetCount = 0;
  int _clipAssetCount = 0;
  ProjectShortVideoReadiness? _shotReadiness;
  bool _shotReadinessUnavailable = false;
  ProjectProductionOverview? _productionOverview;
  ProjectAssetsOverview? _projectAssetsOverview;
  ProjectShortVideoAssembly? _shortVideoAssembly;
  ProjectShortVideoExportCheck? _shortVideoExportCheck;
  List<ProductionStoryboardItemV1> _candidateCompareRows =
      const <ProductionStoryboardItemV1>[];
  List<QualityReview> _candidateCompareReviews = const <QualityReview>[];
  PublishPlatformMatrixResponse? _publishMatrix;
  bool _publishUnavailable = false;
  List<PublishDraftRow> _publishDrafts = const <PublishDraftRow>[];
  PublishPrepareCheckResponse? _publishPrepare;
  List<PublishJobRow> _publishJobs = const <PublishJobRow>[];
  List<PublishPerformanceAlertRow> _publishPerfAlerts =
      const <PublishPerformanceAlertRow>[];
  List<PublishAttemptAuditRow> _publishAuditRows =
      const <PublishAttemptAuditRow>[];
  String? _selectedPublishDraftId;
  Map<String, String> _publishAutomationModesByPlatform =
      <String, String>{};
  List<String> _publishBatchResultLines = const <String>[];
  bool _publishBusy = false;
  int _publishCopyEditorRevision = 0;
  String? _selectedProjectId;
  String? _projectConfigLine;
  
  // P8: Multi-select state
  bool _multiSelectMode = false;
  Set<String> _selectedDraftIds = <String>{};
  PublishBatchValidationResponse? _batchValidation;
  
  // P11: Delivery mode state
  String? _deliveryModeFilter;

  bool get _isAnimated => _mode == ShortVideoMode.animated;

  ProjectRow? get _selectedProject {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      return null;
    }
    for (final project in _projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  PublishDraftRow? get _activePublishDraft {
    if (_publishDrafts.isEmpty) {
      return null;
    }
    final selected = _selectedPublishDraftId;
    if (selected != null) {
      for (final d in _publishDrafts) {
        if (d.id == selected) {
          return d;
        }
      }
    }
    // No automatic fallback to first draft - require explicit selection
    return null;
  }

  void _syncSelectedPublishDraftWith(List<PublishDraftRow> drafts) {
    if (drafts.isEmpty) {
      _selectedPublishDraftId = null;
      return;
    }
    final current = _selectedPublishDraftId;
    if (current != null && drafts.any((d) => d.id == current)) {
      return;
    }
    // Clear selection if current draft no longer exists - require explicit re-selection
    _selectedPublishDraftId = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
    });
  }

  Future<void> _loadProjects() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _projects = const <ProjectRow>[];
        _selectedProjectId = null;
        _projectConfigLine = '当前未登录，暂时无法把短视频模式写回项目。';
      });
      return;
    }
    setState(() {
      _loadingProjects = true;
      _projectConfigLine = null;
    });
    try {
      final projects = await fetchProjects(token);
      if (!mounted) {
        return;
      }
      final selectedId = _resolveProjectIdAfterReload(projects);
      setState(() {
        _projects = projects;
        _selectedProjectId = selectedId;
      });
      _applyProjectPreset(_selectedProject);
      _syncSelectedProjectContext();
      _loadProjectOverview();
      if (projects.isEmpty) {
        setState(() {
          _projectConfigLine = '还没有项目，可先去项目区创建一个短剧项目。';
        });
      }
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '读取项目失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '读取项目失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjects = false;
        });
      }
    }
  }

  String? _resolveProjectIdAfterReload(List<ProjectRow> projects) {
    if (projects.isEmpty) {
      return null;
    }
    final currentId = _selectedProjectId;
    if (currentId != null &&
        projects.any((project) => project.id == currentId)) {
      return currentId;
    }
    return projects.first.id;
  }

  void _applyProjectPreset(ProjectRow? project) {
    if (project == null) {
      return;
    }
    setState(() {
      _mode = _modeFromProject(project);
      _videoRatio = _normalizeVideoRatio(project.videoRatio);
      _targetMarket = project.targetMarket ?? 'domestic';
      final tp = project.targetPlatforms;
      _targetPlatforms = (tp != null && tp.isNotEmpty)
          ? List<String>.from(tp)
          : <String>['douyin'];
      _durationStrategy = project.durationStrategy ?? 'short';
      _voiceProfile = project.voiceProfile ?? '';
      _subtitleStyle = project.subtitleStyle ?? '';
      _bgmStrategy = project.bgmStrategy ?? '';
    });
  }

  void _onPublishPlatformTapped(String platformId) {
    setState(() {
      final next = List<String>.from(_targetPlatforms);
      if (next.contains(platformId)) {
        if (next.length <= 1) {
          return;
        }
        next.remove(platformId);
      } else {
        next.add(platformId);
      }
      _targetPlatforms = next;
    });
  }

  void _syncSelectedProjectContext() {
    final project = _selectedProject;
    widget.onSyncProjectContext(project?.numericId);
  }

  ShortVideoMode _modeFromProject(ProjectRow project) {
    final value = (project.mode ?? '').trim().toLowerCase();
    if (value.contains('live') ||
        value.contains('real') ||
        value.contains('真人')) {
      return ShortVideoMode.liveAction;
    }
    return ShortVideoMode.animated;
  }

  String _normalizeVideoRatio(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed == '16:9' || trimmed == '1:1') {
      return trimmed;
    }
    return '9:16';
  }

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
      // Only fetch prepare check if a draft is explicitly selected
      if (drafts.isNotEmpty && preferredDraftId != null && preferredDraftId.trim().isNotEmpty) {
        if (drafts.any((d) => d.id == preferredDraftId)) {
          prepare = await fetchPublishPrepareCheck(token, project.id, preferredDraftId);
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
      await createPublishDraft(token, project.id, <String, dynamic>{
        'title': title.isEmpty ? '发布草稿' : title,
        'draft_status': 'editing',
        'tags': <String>[],
        'platform_copy': <String, dynamic>{},
      });
      final drafts = await fetchPublishDrafts(token, project.id);
      if (drafts.isEmpty) {
        return;
      }
      final draftId = drafts.first.id;
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
        await createPublishDraft(token, project.id, <String, dynamic>{
          'title': title.isEmpty ? '发布草稿' : title,
          'draft_status': 'editing',
          'tags': <String>[],
          'platform_copy': <String, dynamic>{},
        });
        drafts = await fetchPublishDrafts(token, project.id);
      }
      if (drafts.isEmpty) {
        return;
      }
      final active = _activePublishDraft;
      if (active == null) {
        // No draft explicitly selected - require user to select one
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先明确选择要发布的草稿（不再自动使用第一条草稿）。'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final draftId = active.id;
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

  Future<void> _suggestPublishCopy() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_publishDrafts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先创建发布草稿。')),
        );
      }
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final draftId = _activePublishDraft?.id;
      if (draftId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先明确选择要生成文案的草稿。'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final res = await suggestPublishPlatformCopy(
        token,
        project.id,
        draftId,
        apply: true,
      );
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      setState(() {
        _publishCopyEditorRevision++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('差异化文案已写入（来源：${res.source}）。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文案建议失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文案建议失败：$e')),
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

  Future<void> _clearPublishSchedule() async {
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
    });
    try {
      final ids = _publishDrafts.map((d) => d.id).toList(growable: false);
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: ids,
        scheduledAtIso: null,
      );
      await _refreshPublishSlice(project, token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新 ${res.updated} 张草稿的定时字段（可为 worker 放行）。')),
      );
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除定时失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除定时失败：$e')),
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

  Future<DateTime?> _pickScheduleDateTime(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (!context.mounted) {
      return null;
    }
    if (pickedDate == null) {
      return null;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!context.mounted || pickedTime == null) {
      return null;
    }
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _scheduleFirstDraft(
    BuildContext context,
    ProjectRow project,
    String token,
  ) async {
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final draftId = _activePublishDraft?.id;
    if (draftId == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('请先明确选择要定时的草稿。'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    final dt = await _pickScheduleDateTime(context);
    if (dt == null || !context.mounted) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      await patchPublishDraft(token, project.id, draftId, <String, dynamic>{
        'scheduled_at': iso,
      });
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('已设为定时：$iso（UTC）')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('定时失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('定时失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _scheduleAllDraftsSameTime(
    BuildContext context,
    ProjectRow project,
    String token,
  ) async {
    if (_publishDrafts.length < 2) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final dt = await _pickScheduleDateTime(context);
    if (dt == null || !context.mounted) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      final ids = _publishDrafts.map((d) => d.id).toList(growable: false);
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: ids,
        scheduledAtIso: iso,
      );
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('已批量定时 ${res.updated} 张草稿：$iso（UTC）')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('批量定时失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('批量定时失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<DateTime?> _pickScheduleTimeForDay(
    BuildContext context,
    DateTime dayLocal,
  ) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (!context.mounted || pickedTime == null) {
      return null;
    }
    return DateTime(
      dayLocal.year,
      dayLocal.month,
      dayLocal.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _bulkScheduleDraftsForCalendarDay(
    BuildContext context,
    ProjectRow project,
    String token,
    DateTime dayLocal,
  ) async {
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    var overrideExisting = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final dayLabel =
                '${dayLocal.year}-${dayLocal.month.toString().padLeft(2, '0')}-${dayLocal.day.toString().padLeft(2, '0')}';
            return AlertDialog(
              title: Text('批量定时 · $dayLabel'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: overrideExisting,
                    onChanged: (v) {
                      setLocal(() {
                        overrideExisting = v ?? false;
                      });
                    },
                    title: const Text('包含已定时草稿并重写为该时刻'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    overrideExisting
                        ? '将对当前列表中的全部草稿写入同一发布时间。'
                        : '仅对尚未填写定时的草稿写入发布时间。',
                    style: Theme.of(dialogCtx).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  child: const Text('选择时间'),
                ),
              ],
            );
          },
        );
      },
    );
    if (proceed != true || !context.mounted) {
      return;
    }
    final dt = await _pickScheduleTimeForDay(context, dayLocal);
    if (dt == null || !context.mounted) {
      return;
    }
    final ids = _publishDrafts
        .where(
          (d) =>
              overrideExisting || (d.scheduledAt ?? '').trim().isEmpty,
        )
        .map((d) => d.id)
        .toList(growable: false);
    if (ids.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('没有符合条件的草稿（试勾选「包含已定时」）。')),
      );
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: ids,
        scheduledAtIso: iso,
      );
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('已更新 ${res.updated} 张草稿定时：$iso（UTC）')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('日历批量定时失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('日历批量定时失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishBusy = false;
        });
      }
    }
  }

  Future<void> _commitPublishPlatformCopy(
    ProjectRow project,
    String token,
    String platformId,
    String title,
    String description,
    String tagsComma,
  ) async {
    if (_publishDrafts.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final draftId = _activePublishDraft?.id;
    if (draftId == null) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('请先明确选择要编辑文案的草稿。'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final draft = await fetchPublishDraft(token, project.id, draftId);
      final copy = Map<String, dynamic>.from(draft.platformCopy ?? {});
      final tags = tagsComma
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      copy[platformId] = <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'tags': tags,
      };
      await patchPublishDraft(token, project.id, draftId, <String, dynamic>{
        'platform_copy': copy,
      });
      if (!context.mounted) {
        return;
      }
      setState(() {
        _publishCopyEditorRevision++;
      });
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        const SnackBar(content: Text('已保存差异化文案。')),
      );
    } on RustApiException catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('保存文案失败：${e.statusCode}')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('保存文案失败：$e')),
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

  // P8: Multi-select handlers
  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) {
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      }
    });
  }

  void _toggleDraftSelection(String draftId) {
    setState(() {
      final next = Set<String>.from(_selectedDraftIds);
      if (next.contains(draftId)) {
        next.remove(draftId);
      } else {
        next.add(draftId);
      }
      _selectedDraftIds = next;
      _batchValidation = null;
    });
  }

  void _selectAllDrafts() {
    setState(() {
      _selectedDraftIds = _publishDrafts.map((d) => d.id).toSet();
      _batchValidation = null;
    });
  }

  void _clearDraftSelection() {
    setState(() {
      _selectedDraftIds = <String>{};
      _batchValidation = null;
    });
  }

  Future<void> _batchScheduleDrafts(BuildContext context) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要定时的草稿。')),
      );
      return;
    }
    
    // Validate first
    setState(() {
      _publishBusy = true;
    });
    try {
      final validation = await batchValidatePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );
      
      if (!context.mounted) {
        return;
      }
      
      if (validation.blockedCount > 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('批量定时验证'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('就绪：${validation.readyCount} 张草稿'),
                Text('阻塞：${validation.blockedCount} 张草稿'),
                const SizedBox(height: 12),
                const Text('阻塞原因：'),
                ...validation.blockedDrafts.take(5).map((d) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: ${d.blockingReasons.map((r) => r.message).join(", ")}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续定时就绪草稿'),
              ),
            ],
          ),
        );
        
        if (proceed != true || !context.mounted) {
          return;
        }
      }
      
      final dt = await _pickScheduleDateTime(context);
      if (dt == null || !context.mounted) {
        return;
      }
      
      final iso = dt.toUtc().toIso8601String();
      final res = await batchSchedulePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
        scheduledAtIso: iso,
      );
      
      await _refreshPublishSlice(project, token);
      
      if (!context.mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已批量定时 ${res.updated} 张草稿：$iso（UTC）')),
      );
      
      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } on RustApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量定时失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量定时失败：$e')),
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

  Future<void> _batchPublishDrafts() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要发布的草稿。')),
      );
      return;
    }
    
    setState(() {
      _publishBusy = true;
    });
    try {
      // Validate first
      final validation = await batchValidatePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );
      
      setState(() {
        _batchValidation = validation;
      });
      
      if (!mounted) {
        return;
      }
      
      if (validation.blockedCount > 0) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('批量发布验证'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('就绪：${validation.readyCount} 张草稿'),
                Text('阻塞：${validation.blockedCount} 张草稿'),
                const SizedBox(height: 12),
                const Text('阻塞原因：'),
                ...validation.blockedDrafts.take(5).map((d) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '${d.title.isEmpty ? d.draftId.substring(0, 8) : d.title}: ${d.blockingReasons.map((r) => r.message).join(", ")}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('继续发布就绪草稿'),
              ),
            ],
          ),
        );
        
        if (proceed != true || !mounted) {
          return;
        }
      }
      
      final res = await batchPublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
        immediate: true,
      );
      
      await _refreshPublishSlice(project, token);
      
      if (!mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('批量发布完成：成功 ${res.successCount}，失败 ${res.failedCount}')),
      );
      
      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量发布失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量发布失败：$e')),
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

  Future<void> _batchArchiveDrafts() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    if (_selectedDraftIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要归档的草稿。')),
      );
      return;
    }
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量归档确认'),
        content: Text('确定要归档 ${_selectedDraftIds.length} 张草稿吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认归档'),
          ),
        ],
      ),
    );
    
    if (proceed != true || !mounted) {
      return;
    }
    
    setState(() {
      _publishBusy = true;
    });
    try {
      final res = await batchArchivePublishDrafts(
        token,
        project.id,
        draftIds: _selectedDraftIds.toList(),
      );
      
      await _refreshPublishSlice(project, token);
      
      if (!mounted) {
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已归档 ${res.archivedCount} 张草稿')),
      );
      
      setState(() {
        _multiSelectMode = false;
        _selectedDraftIds = <String>{};
        _batchValidation = null;
      });
    } on RustApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量归档失败：${e.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('批量归档失败：$e')),
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

  void _compareDrafts() {
    if (_selectedDraftIds.length < 2 || _selectedDraftIds.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择 2-4 张草稿进行对比。')),
      );
      return;
    }
    
    // TODO: Implement draft comparison view
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('草稿对比功能：已选择 ${_selectedDraftIds.length} 张草稿')),
    );
  }

  // P11: Delivery mode handlers
  void _onDeliveryModeFilterChanged(String mode) {
    setState(() {
      _deliveryModeFilter = mode == _deliveryModeFilter ? null : mode;
    });
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

  Future<void> _createProjectFromSpace() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _projectConfigLine = '请先登录后再创建短剧项目。';
      });
      return;
    }
    setState(() {
      _creatingProject = true;
      _projectConfigLine = null;
    });
    final defaultName = _isAnimated ? '动漫短剧项目' : '真人短剧项目';
    final storedMode = _isAnimated
        ? 'animated.short_drama'
        : 'live_action.short_drama';
    try {
      final created = await createProject(
        token,
        fields: {
          'name': defaultName,
          'projectType': 'short_drama',
          'mode': storedMode,
          'videoRatio': _videoRatio,
          'targetMarket': _targetMarket,
          'targetPlatforms': _targetPlatforms,
          'durationStrategy': _durationStrategy,
          if (_voiceProfile.trim().isNotEmpty)
            'voiceProfile': _voiceProfile.trim(),
          if (_subtitleStyle.trim().isNotEmpty)
            'subtitleStyle': _subtitleStyle.trim(),
          if (_bgmStrategy.trim().isNotEmpty) 'bgmStrategy': _bgmStrategy.trim(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = [created, ..._projects].toList(growable: false);
        _selectedProjectId = created.id;
        _projectConfigLine =
            '已新建项目 #${created.numericId}，并写入 ${shortVideoModeLabel(_mode)} · ${shortVideoVideoRatioLabel(_videoRatio)}。';
      });
      _syncSelectedProjectContext();
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '新建项目失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '新建项目失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingProject = false;
        });
      }
    }
  }

  Future<void> _saveProjectConfig() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      setState(() {
        _projectConfigLine = '请先登录并选择项目。';
      });
      return;
    }
    setState(() {
      _savingProjectConfig = true;
      _projectConfigLine = null;
    });
    final storedMode = _mode == ShortVideoMode.animated
        ? 'animated.short_drama'
        : 'live_action.short_drama';
    try {
      final body = <String, dynamic>{
        'projectType': 'short_drama',
        'mode': storedMode,
        'videoRatio': _videoRatio,
        'targetMarket': _targetMarket,
        'targetPlatforms': _targetPlatforms,
        'durationStrategy': _durationStrategy,
        'voiceProfile': _voiceProfile.trim().isEmpty
            ? null
            : _voiceProfile.trim(),
        'subtitleStyle':
            _subtitleStyle.trim().isEmpty ? null : _subtitleStyle.trim(),
        'bgmStrategy': _bgmStrategy.trim().isEmpty ? null : _bgmStrategy.trim(),
      };
      final updated = await updateProjectByProjectId(token, project.id, body);
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = _projects
            .map((row) => row.id == updated.id ? updated : row)
            .toList(growable: false);
        _selectedProjectId = updated.id;
        _projectConfigLine =
            '已写回项目 #${updated.numericId}：${shortVideoModeLabel(_mode)} · ${shortVideoVideoRatioLabel(_videoRatio)} · 市场 $_targetMarket · 平台 ${_targetPlatforms.length} 个 · 时长 $_durationStrategy';
      });
      _syncSelectedProjectContext();
      _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '保存失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '保存失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingProjectConfig = false;
        });
      }
    }
  }

  VoidCallback _nextStepAction() {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: _isAnimated,
      project: _selectedProject,
      stats: _projectStats,
      recentProjectTasks: _recentProjectTasks,
      qualityScopeInsight: _qualityScopeInsight,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    switch (plan.target) {
      case ShortVideoNextStepTarget.projects:
        return widget.onOpenProjects;
      case ShortVideoNextStepTarget.scriptWorkspace:
        return () {
          _syncSelectedProjectContext();
          widget.onOpenScriptWorkspace();
        };
      case ShortVideoNextStepTarget.productionWorkspace:
        return () {
          _syncSelectedProjectContext();
          widget.onOpenProductionWorkspace();
        };
      case ShortVideoNextStepTarget.tasks:
        return widget.onOpenTasks;
      case ShortVideoNextStepTarget.quality:
        return widget.onOpenQuality;
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

  Future<String?> _promptReplacementVideoUrl(
    BuildContext context, {
    String initialValue = '',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('替换当前视频版本'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: '视频 URL',
              hintText: 'https://...',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('写回当前版本'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
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
            storyboardNumericId: shot.storyboardNumericId,
            sbIndex: shot.sbIndex,
            selectedMediaUrl: (shot.selectedMediaUrl ?? '').trim(),
            selectedMediaKind: shot.selectedMediaKind,
            durationText: (shot.duration ?? '').trim(),
            subtitleText: (shot.subtitleText ?? '').trim(),
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
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> runDisable(_AssemblyClipDeskOpEntry item) async {
              try {
                await postWorkbenchDeleteVideoV1(
                  token,
                  projectId: project.numericId,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                );
                pausedStoryboardIds.add(item.storyboardNumericId);
                if (mounted) {
                  setState(() {
                    _projectConfigLine =
                        '分镜 #${item.storyboardNumericId} 已暂停（清空当前视频）。';
                  });
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '暂停失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '暂停失败：$e';
                });
              }
            }

            Future<void> runEnableOrReplace(
              _AssemblyClipDeskOpEntry item, {
              String? replacementUrl,
            }) async {
              final seedUrl = (replacementUrl ?? item.selectedMediaUrl).trim();
              if (seedUrl.isEmpty) {
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  const SnackBar(content: Text('没有可用视频 URL，请先输入替换地址。')),
                );
                return;
              }
              try {
                await postWorkbenchSelectVideoV1(
                  token,
                  projectId: project.numericId,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  videoUrl: seedUrl,
                );
                pausedStoryboardIds.remove(item.storyboardNumericId);
                if (replacementUrl != null) {
                  final idx = ordered.indexWhere(
                    (entry) =>
                        entry.storyboardNumericId == item.storyboardNumericId,
                  );
                  if (idx >= 0) {
                    ordered[idx] = ordered[idx].copyWith(selectedMediaUrl: seedUrl);
                  }
                }
                if (mounted) {
                  setState(() {
                    _projectConfigLine =
                        '分镜 #${item.storyboardNumericId} 已写回当前视频版本。';
                  });
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '写回失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '写回失败：$e';
                });
              }
            }

            Future<void> persistReorder() async {
              final byScript = <int, List<int>>{};
              for (final item in ordered) {
                byScript.putIfAbsent(item.scriptNumericId, () => <int>[]).add(
                  item.storyboardNumericId,
                );
              }
              try {
                for (final entry in byScript.entries) {
                  final scriptNumericId = entry.key;
                  final orderedStoryboardIds = entry.value;
                  Map<String, dynamic> flowData;
                  try {
                    flowData = await fetchProductionFlowDataV1(
                      token,
                      projectId: project.numericId,
                      episodesId: scriptNumericId,
                    );
                  } on RustApiException {
                    flowData = <String, dynamic>{};
                  }
                  flowData['storyboard'] = orderedStoryboardIds
                      .map((id) => <String, dynamic>{'id': id})
                      .toList(growable: false);
                  final code = await postProductionSaveFlowDataV1(
                    token,
                    projectId: project.numericId,
                    episodesId: scriptNumericId,
                    data: flowData,
                  );
                  if (code != 200) {
                    throw RustApiException('save flow failed', statusCode: code);
                  }
                }
                if (mounted) {
                  setState(() {
                    _projectConfigLine =
                        '已持久化镜头重排顺序（按剧本写回时间线与分镜序号）。';
                  });
                }
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '重排持久化失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '重排持久化失败：$e';
                });
              }
            }

            Future<void> runAlignDuration(
              _AssemblyClipDeskOpEntry item,
              int durationSeconds,
            ) async {
              try {
                final status = await postStoryboardUpdateDurationV1(
                  token,
                  projectId: project.numericId,
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
                  setState(() {
                    _projectConfigLine =
                        '分镜 #${item.storyboardNumericId} 已对齐为 ${durationSeconds}s。';
                  });
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '时长对齐失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '时长对齐失败：$e';
                });
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
                return '字幕存在，但时长未显式（建议先对齐时长）。';
              }
              if (!hasSubtitle && (durationSec ?? 0) > 0) {
                return '时长已设定，但字幕为空（可能有字幕轨缺口）。';
              }
              if (hasSubtitle && (durationSec ?? 0) <= 0) {
                return '字幕存在，但时长异常（<=0）。';
              }
              return '字幕与时长未见明显错位。';
            }

            return AlertDialog(
              title: const Text('镜头基础操作'),
              content: SizedBox(
                width: 760,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '支持基础重排（本次面板视图）、启停和替换当前视频版本。',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '启停 / 替换会直接写回 J 媒体槽位；重排仅用于本次排障视图。',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => unawaited(persistReorder()),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('保存重排顺序'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ordered = List<_AssemblyClipDeskOpEntry>.from(
                                initialOrdered,
                              );
                              setLocalState(() {});
                            },
                            icon: const Icon(Icons.undo_outlined),
                            label: const Text('撤销到打开时'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: ordered.length,
                        itemBuilder: (ctx, idx) {
                          final item = ordered[idx];
                          final paused = pausedStoryboardIds.contains(
                            item.storyboardNumericId,
                          );
                          final canMoveUp = idx > 0;
                          final canMoveDown = idx < ordered.length - 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '剧本 #${item.scriptNumericId} · 分镜 #${item.storyboardNumericId} · 顺序 ${idx + 1}',
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    paused
                                        ? '状态：暂停'
                                        : '状态：启用（${item.selectedMediaKind}）',
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '时长：${item.durationText.isEmpty ? "未设定" : item.durationText} · '
                                    '字幕：${item.subtitleText.isEmpty ? "空" : "已填"}',
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '错位检查：${subtitleMismatchLine(item)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: canMoveUp
                                            ? () {
                                                final current = ordered[idx];
                                                ordered[idx] = ordered[idx - 1];
                                                ordered[idx - 1] = current;
                                                setLocalState(() {});
                                              }
                                            : null,
                                        child: const Text('上移'),
                                      ),
                                      OutlinedButton(
                                        onPressed: canMoveDown
                                            ? () {
                                                final current = ordered[idx];
                                                ordered[idx] = ordered[idx + 1];
                                                ordered[idx + 1] = current;
                                                setLocalState(() {});
                                              }
                                            : null,
                                        child: const Text('下移'),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          if (paused) {
                                            unawaited(runEnableOrReplace(item));
                                          } else {
                                            unawaited(runDisable(item));
                                          }
                                        },
                                        child: Text(paused ? '启用' : '暂停'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () async {
                                          final ctrl = TextEditingController(
                                            text: parseDurationSeconds(
                                                      item.durationText,
                                                    )?.toString() ??
                                                '',
                                          );
                                          final picked = await showDialog<int>(
                                            context: ctx,
                                            builder: (dCtx) => AlertDialog(
                                              title: const Text('单镜头时长对齐'),
                                              content: TextField(
                                                controller: ctrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: '时长（秒）',
                                                  hintText: '输入 1~300',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    dCtx,
                                                  ).pop(),
                                                  child: const Text('取消'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    final sec = int.tryParse(
                                                      ctrl.text.trim(),
                                                    );
                                                    Navigator.of(
                                                      dCtx,
                                                    ).pop(sec);
                                                  },
                                                  child: const Text('对齐并写回'),
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
                                          unawaited(
                                            runAlignDuration(item, picked),
                                          );
                                        },
                                        child: const Text('时长对齐'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () async {
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
                                        child: const Text('替换当前版本'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
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
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('成片级样式调整'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(
                      labelText: '字幕样式 subtitle_style',
                      hintText: '例如 cinematic_cn_v2（留空则回退默认）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bgmCtrl,
                    decoration: const InputDecoration(
                      labelText: 'BGM 策略 bgm_strategy',
                      hintText: '例如 pulse_light（留空则回退默认）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '保存后会写回 D7 默认配置，并刷新成片装配快照中的生效值。',
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
                onPressed: () async {
                  final nextSubtitle = subtitleCtrl.text.trim();
                  final nextBgm = bgmCtrl.text.trim();
                  Navigator.of(ctx).pop();
                  try {
                    final updated = await updateProjectByProjectId(
                      token,
                      project.id,
                      <String, dynamic>{
                        'subtitleStyle': nextSubtitle.isEmpty ? null : nextSubtitle,
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
                      _projectConfigLine =
                          '已更新成片级默认：字幕 ${_subtitleStyle.trim().isEmpty ? "默认" : _subtitleStyle.trim()} · '
                          'BGM ${_bgmStrategy.trim().isEmpty ? "默认" : _bgmStrategy.trim()}';
                    });
                    await _loadProjectOverview();
                  } on RustApiException catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _projectConfigLine = '成片样式写回失败：${e.statusCode ?? '-'}';
                    });
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _projectConfigLine = '成片样式写回失败：$e';
                    });
                  }
                },
                child: const Text('保存并刷新'),
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

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    final visualLabel = shortVideoVisualStyleLabel(project);
    final directionLabel = shortVideoDirectionLabel(project);
    final modeTitle = _isAnimated ? '动漫短剧' : '真人短剧';
    final modeSummary = _isAnimated
        ? '当前主链路更贴近动漫短剧，所以会优先强调画风、角色一致性、分镜出图和连续性。'
        : '真人短剧也应该成为同一个 Space 里的标准模式，后续重点会转向演员感、场景真实度、镜头参考和口播质感。';
    final modeAdvice = _isAnimated
        ? '建议先准备画风、视觉手册和角色资产，再进入脚本与制作流程。'
        : '建议先准备真人参考图、角色设定、镜头语气和视觉手册，再进入脚本与制作流程。';
    final projectOptions = _projects
        .map(
          (row) => ShortVideoProjectOption(
            id: row.id,
            label:
                '#${row.numericId} ${row.name?.trim().isNotEmpty == true ? row.name!.trim() : "未命名项目"}',
          ),
        )
        .toList(growable: false);
    final projectMetrics = _projectStats == null
        ? const <ShortVideoMetricData>[]
        : <ShortVideoMetricData>[
            ShortVideoMetricData(
              label: '剧本',
              value: _projectStats!.scriptCount.toString(),
            ),
            ShortVideoMetricData(
              label: '分镜',
              value: _projectStats!.storyboardCount.toString(),
            ),
            ShortVideoMetricData(
              label: '角色',
              value: _projectStats!.roleCount.toString(),
            ),
            ShortVideoMetricData(
              label: '小说',
              value: _projectStats!.novelCount.toString(),
            ),
            ShortVideoMetricData(
              label: '视频',
              value: _projectStats!.videoCount.toString(),
            ),
          ];
    final po = _productionOverview;
    final overviewMetrics = <ShortVideoMetricData>[
      ShortVideoMetricData(
        label: '最近任务',
        value: (_recentProjectTasks?.total ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: po != null ? '生成任务' : '进行中',
        value: po != null
            ? po.runningGenerationJobCount.toString()
            : shortVideoCountTasksByStatus(
                _recentProjectTasks,
                'running',
              ).toString(),
      ),
      ShortVideoMetricData(
        label: '失败',
        value: shortVideoCountTasksByStatus(
          _recentProjectTasks,
          'failed',
        ).toString(),
      ),
      ShortVideoMetricData(
        label: '坏例',
        value: po != null
            ? po.pendingReviewBadCaseCount.toString()
            : (_qualityScopeInsight?.badCaseCount ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: '通过率',
        value:
            '${(_qualityScopeInsight?.passRatePercent ?? 0).toStringAsFixed(0)}%',
      ),
      ShortVideoMetricData(label: '场景', value: _sceneAssetCount.toString()),
      ShortVideoMetricData(label: 'clip', value: _clipAssetCount.toString()),
    ];
    if (po != null && po.totalStoryboardCount > 0) {
      overviewMetrics.add(
        ShortVideoMetricData(
          label: '分镜就绪',
          value:
              '${po.readyStoryboardCount}/${po.totalStoryboardCount}',
        ),
      );
    }
    final badCaseMetrics = _badCaseStats
        .map(
          (item) => ShortVideoMetricData(
            label: shortVideoFormatBadCaseLabel(item),
            value: item.count.toString(),
          ),
        )
        .toList(growable: false);
    final recentTaskLines = (_recentProjectTasks?.data ?? const <JobRow>[])
        .take(3)
        .map(
          (task) =>
              '${shortVideoFormatTaskKind(task)} · ${shortVideoFormatTaskStatus(task)}',
        )
        .toList(growable: false);
    final readinessItems = buildShortVideoReadinessItems(
      isAnimated: _isAnimated,
      project: project,
      stats: _projectStats,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    final shotReadinessUi = project == null
        ? const ShotReadinessUi(
            headline: '选择短剧项目后，会显示服务端分镜阻塞汇总。',
          )
        : buildShotReadinessUi(
            loadingProjectOverview: _loadingProjectOverview,
            readiness: _shotReadiness,
            readinessUnavailable: _shotReadinessUnavailable,
          );
    final assetsOverviewPanelUi = buildShortVideoAssetsOverviewPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      overview: _projectAssetsOverview,
    );
    final assemblyPanelUi = buildShortVideoAssemblyPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assembly: _shortVideoAssembly,
    );
    final exportCheckPanelUi = buildShortVideoExportCheckPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      exportCheck: _shortVideoExportCheck,
    );
    final accessToken = widget.accessToken;
    final publishPanelUi = buildShortVideoPublishPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      publishUnavailable: _publishUnavailable,
      exportCheck: _shortVideoExportCheck,
      matrix: _publishMatrix,
      drafts: _publishDrafts,
      prepare: _publishPrepare,
      jobs: _publishJobs,
      performanceAlerts: _publishPerfAlerts,
      audits: _publishAuditRows,
      selectedPublishDraftId: _selectedPublishDraftId,
      onSelectPublishDraft: (draftId) {
        setState(() {
          _selectedPublishDraftId = draftId;
          _publishCopyEditorRevision++;
        });
        if (project != null && accessToken != null && accessToken.isNotEmpty) {
          unawaited(_refreshPublishSlice(project, accessToken));
        }
      },
      publishBusy: _publishBusy,
      onRefreshPublish: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_refreshPublishSlice(project, accessToken))
          : null,
      onBootstrapPublishDraft: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_bootstrapPublishDraft())
          : null,
      onEnqueuePublishJob: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_enqueuePublishJob())
          : null,
      onConfirmSemiAuto: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_confirmSemiAutoPublish())
          : null,
      onSuggestPublishCopy: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable
          ? () => unawaited(_suggestPublishCopy())
          : null,
      onClearPublishSchedule: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_clearPublishSchedule())
          : null,
      publishTargetPlatformIds: _targetPlatforms,
      onEnqueueAllDrafts:
          project != null ? () => unawaited(_enqueueAllDraftJobs()) : null,
      onRetryFailedPublishJobs:
          project != null ? () => unawaited(_retryFailedPublishJobs()) : null,
      publishBatchResultLines: _publishBatchResultLines,
      publishAutomationModesByPlatform: _publishAutomationModesByPlatform,
      onChangePublishAutomationMode: (platformId, automationMode) {
        setState(() {
          _publishAutomationModesByPlatform = <String, String>{
            ..._publishAutomationModesByPlatform,
            platformId: automationMode,
          };
        });
      },
      publishCopyEditorRevision: _publishCopyEditorRevision,
      onCommitPublishPlatformCopy: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (platformId, title, description, tagsComma) =>
                _commitPublishPlatformCopy(
                  project,
                  accessToken,
                  platformId,
                  title,
                  description,
                  tagsComma,
                )
          : null,
      onScheduleFirstDraft: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx) => unawaited(
                _scheduleFirstDraft(ctx, project, accessToken),
              )
          : null,
      onScheduleAllDraftsSameTime: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.length > 1
          ? (ctx) => unawaited(
                _scheduleAllDraftsSameTime(ctx, project, accessToken),
              )
          : null,
      onPublishCalendarDayBulkSchedule: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx, day) => unawaited(
                _bulkScheduleDraftsForCalendarDay(
                  ctx,
                  project,
                  accessToken,
                  day,
                ),
              )
          : null,
      onOpenPublishTroubleshooting: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () {
              _syncSelectedProjectContext();
              widget.onOpenTasks();
            }
          : null,
      // P8: Multi-select
      multiSelectMode: _multiSelectMode,
      selectedDraftIds: _selectedDraftIds,
      onToggleMultiSelectMode: _toggleMultiSelectMode,
      onToggleDraftSelection: _toggleDraftSelection,
      onSelectAllDrafts: _selectAllDrafts,
      onClearDraftSelection: _clearDraftSelection,
      onBatchScheduleDrafts: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx) => unawaited(_batchScheduleDrafts(ctx))
          : null,
      onBatchPublishDrafts: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_batchPublishDrafts())
          : null,
      onBatchArchiveDrafts: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_batchArchiveDrafts())
          : null,
      onCompareDrafts: _publishDrafts.isNotEmpty ? _compareDrafts : null,
      batchValidation: _batchValidation,
      // P11: Delivery mode
      deliveryModeFilter: _deliveryModeFilter,
      onDeliveryModeFilterChanged: _onDeliveryModeFilterChanged,
    );
    final candidateCardUi = buildShortVideoCandidateCardUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assetsOverview: _projectAssetsOverview,
      onBatchGenerateCandidateClips:
          project != null && (_projectStats?.storyboardCount ?? 0) > 0
              ? _runBatchCandidateClips
              : null,
      batchGenerateCandidateClipsBusy: _batchCandidateBusy,
    );
    final candidateComparePanelUi = buildShortVideoCandidateComparePanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      storyboardRows: _candidateCompareRows,
      readiness: _shotReadiness,
      reviews: _candidateCompareReviews,
      isLiveAction: !_isAnimated,
      onSetCurrent: _setComparedStoryboardCurrent,
      onOpenProductionWorkspace: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
    );
    final nextStepPlan = buildShortVideoNextStepPlan(
      isAnimated: _isAnimated,
      project: project,
      stats: _projectStats,
      recentProjectTasks: _recentProjectTasks,
      qualityScopeInsight: _qualityScopeInsight,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    final stageCards = <ShortVideoStageCardData>[
      ShortVideoStageCardData(
        title: '1. 立项',
        status: '现在可用',
        detail: _isAnimated
            ? '从项目开始收口题材、画风、创作手册和角色资产。'
            : '从项目开始收口题材、真人参考、创作手册和角色设定。',
      ),
      ShortVideoStageCardData(
        title: '2. 生成脚本',
        status: '现在可用',
        detail: _isAnimated
            ? '复用脚本工作区的上下文探测、子 Agent 和正文回写。'
            : '复用脚本工作区生成更贴近口播、表演和场景调度的脚本版本。',
      ),
      ShortVideoStageCardData(
        title: '3. 组织素材',
        status: '适合下一步补齐',
        detail: _isAnimated
            ? '把素材检索、资产出图、镜头候选和旁白草稿收成同一段流程。'
            : '把真人参考图、镜头候选、旁白草稿和素材筛选收成同一段流程。',
      ),
      ShortVideoStageCardData(
        title: '4. 出片与复核',
        status: '基础已在',
        detail: _isAnimated
            ? '挂接制作工作区、任务中心和质量评审，形成可追踪的成片闭环。'
            : '挂接制作工作区、任务中心和质量评审，重点补演员一致性与真实感复核。',
      ),
    ];
    return ShortVideoSpaceView(
      mode: _mode,
      modeTitle: modeTitle,
      modeSummary: modeSummary,
      modeAdvice: modeAdvice,
      onModeChanged: (mode) {
        setState(() {
          _mode = mode;
        });
      },
      loadingProjects: _loadingProjects,
      projectOptions: projectOptions,
      selectedProjectId: _selectedProjectId,
      onProjectChanged: (value) {
        setState(() {
          _selectedProjectId = value;
        });
        _applyProjectPreset(_selectedProject);
        _syncSelectedProjectContext();
        _loadProjectOverview();
      },
      onRefreshProjects: _loadProjects,
      videoRatio: _videoRatio,
      onVideoRatioChanged: (value) {
        setState(() {
          _videoRatio = value;
        });
      },
      targetMarket: _targetMarket,
      onTargetMarketChanged: (value) {
        setState(() {
          _targetMarket = value;
        });
      },
      targetPlatforms: _targetPlatforms,
      onPublishPlatformTapped: _onPublishPlatformTapped,
      durationStrategy: _durationStrategy,
      onDurationStrategyChanged: (value) {
        setState(() {
          _durationStrategy = value;
        });
      },
      voiceProfile: _voiceProfile,
      onVoiceProfileChanged: (value) {
        setState(() {
          _voiceProfile = value;
        });
      },
      subtitleStyle: _subtitleStyle,
      onSubtitleStyleChanged: (value) {
        setState(() {
          _subtitleStyle = value;
        });
      },
      bgmStrategy: _bgmStrategy,
      onBgmStrategyChanged: (value) {
        setState(() {
          _bgmStrategy = value;
        });
      },
      creatingProject: _creatingProject,
      onCreateProject: _createProjectFromSpace,
      savingProjectConfig: _savingProjectConfig,
      onSaveProjectConfig: _saveProjectConfig,
      onOpenProjects: widget.onOpenProjects,
      projectConfigLine: _projectConfigLine,
      loadingProjectOverview: _loadingProjectOverview,
      projectReadinessSummary: shortVideoProjectReadinessSummary(_projectStats),
      visualLabel: visualLabel,
      directionLabel: directionLabel,
      projectMetrics: projectMetrics,
      spaceOverviewSummary: shortVideoSpaceOverviewSummary(
        loadingProjectOverview: _loadingProjectOverview,
        project: project,
        projectStats: _projectStats,
        recentProjectTasks: _recentProjectTasks,
        qualityScopeInsight: _qualityScopeInsight,
      ),
      overviewMetrics: overviewMetrics,
      qualitySummaryLine: shortVideoQualitySummaryLine(
        isAnimated: _isAnimated,
        insight: _qualityScopeInsight,
      ),
      badCaseMetrics: badCaseMetrics,
      recentTaskLines: recentTaskLines,
      assetsOverviewPanelUi: assetsOverviewPanelUi,
      assemblyPanelUi: assemblyPanelUi,
      exportCheckPanelUi: exportCheckPanelUi,
      publishPanelUi: publishPanelUi,
      onOpenProductionForAssemblyExport: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
      onOpenAssemblyClipDeskOps: project == null ||
              _shortVideoAssembly == null ||
              (_shortVideoAssembly?.scripts.isEmpty ?? true)
          ? null
          : () => unawaited(_openAssemblyClipDeskOps()),
      onOpenAssemblyDefaultsEditor: project == null || _shortVideoAssembly == null
          ? null
          : () => unawaited(_openAssemblyDefaultsEditor()),
      candidateCardUi: candidateCardUi,
      candidateComparePanelUi: candidateComparePanelUi,
      onOpenProjectsForCandidateAssets:
          project == null ? null : widget.onOpenProjects,
      readinessIntro: _isAnimated
          ? '动漫短剧更看重画风、角色和分镜连续性。'
          : '真人短剧更看重角色设定、场景参考、clip 镜头素材和口播手册。',
      readinessCountLabel:
          '${readinessItems.where((item) => item.ready).length}/${readinessItems.length}',
      readinessGapSummary: shortVideoReadinessGapSummary(
        isAnimated: _isAnimated,
        readinessItems: readinessItems,
      ),
      readinessItems: readinessItems,
      shotReadinessUi: shotReadinessUi,
      onOpenProductionForShotReadiness: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
      nextStepTitle: nextStepPlan.title,
      nextStepDetail: nextStepPlan.detail,
      onNextStep: _nextStepAction(),
      nextStepButtonLabel: nextStepPlan.buttonLabel,
      stageCards: stageCards,
      migrationSummary: _isAnimated
          ? '先做单入口，再补链路。第一波只编排现有项目、脚本、制作、任务、质检能力；第二波再补自动旁白、字幕样式和一键成片。'
          : '真人模式也先走同一入口。第一波先把用户选择显式化，后面再补真人参考素材、口播语气、镜头真实度和成片验收规则。',
      onOpenScriptWorkspace: () {
        _syncSelectedProjectContext();
        widget.onOpenScriptWorkspace();
      },
      onOpenProductionWorkspace: () {
        _syncSelectedProjectContext();
        widget.onOpenProductionWorkspace();
      },
      onOpenTasks: widget.onOpenTasks,
      onOpenQuality: widget.onOpenQuality,
    );
  }
}

class _AssemblyClipDeskOpEntry {
  const _AssemblyClipDeskOpEntry({
    required this.scriptNumericId,
    required this.storyboardNumericId,
    required this.sbIndex,
    required this.selectedMediaUrl,
    required this.selectedMediaKind,
    required this.durationText,
    required this.subtitleText,
  });

  final int scriptNumericId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String selectedMediaUrl;
  final String selectedMediaKind;
  final String durationText;
  final String subtitleText;

  _AssemblyClipDeskOpEntry copyWith({
    String? selectedMediaUrl,
    String? durationText,
    String? subtitleText,
  }) {
    return _AssemblyClipDeskOpEntry(
      scriptNumericId: scriptNumericId,
      storyboardNumericId: storyboardNumericId,
      sbIndex: sbIndex,
      selectedMediaUrl: selectedMediaUrl ?? this.selectedMediaUrl,
      selectedMediaKind: selectedMediaKind,
      durationText: durationText ?? this.durationText,
      subtitleText: subtitleText ?? this.subtitleText,
    );
  }
}
