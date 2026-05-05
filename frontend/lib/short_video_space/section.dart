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
  bool _publishBusy = false;
  int _publishCopyEditorRevision = 0;
  String? _selectedProjectId;
  String? _projectConfigLine;

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
      })> _capturePublishSlice(
    ProjectRow project,
    String token,
  ) async {
    try {
      final matrix = await fetchPublishPlatformMatrix(token, project.id);
      final drafts = await fetchPublishDrafts(token, project.id);
      final jobs = await fetchPublishJobs(token, project.id);
      PublishPrepareCheckResponse? prepare;
      if (drafts.isNotEmpty) {
        prepare = await fetchPublishPrepareCheck(token, project.id, drafts.first.id);
      }
      return (
        matrix: matrix,
        unavailable: false,
        drafts: drafts,
        prepare: prepare,
        jobs: jobs,
      );
    } catch (_) {
      return (
        matrix: null,
        unavailable: true,
        drafts: <PublishDraftRow>[],
        prepare: null,
        jobs: <PublishJobRow>[],
      );
    }
  }

  List<Map<String, dynamic>> _publishTargetMaps() {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < _targetPlatforms.length; i++) {
      final p = _targetPlatforms[i];
      out.add(<String, dynamic>{
        'platform_id': p,
        'automation_mode': 'semi_auto',
        'serial_order': i,
        'extra': <String, dynamic>{},
      });
    }
    return out;
  }

  Future<void> _refreshPublishSlice(ProjectRow project, String token) async {
    final snapshot = await _capturePublishSlice(project, token);
    if (!mounted || _selectedProjectId != project.id) {
      return;
    }
    setState(() {
      _publishMatrix = snapshot.matrix;
      _publishUnavailable = snapshot.unavailable;
      _publishDrafts = snapshot.drafts;
      _publishPrepare = snapshot.prepare;
      _publishJobs = snapshot.jobs;
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
      final draftId = drafts.first.id;
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
      final draftId = _publishDrafts.first.id;
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
    final dt = await _pickScheduleDateTime(context);
    if (dt == null || !context.mounted) {
      return;
    }
    setState(() {
      _publishBusy = true;
    });
    try {
      final iso = dt.toUtc().toIso8601String();
      await patchPublishDraft(token, project.id, _publishDrafts.first.id, <String, dynamic>{
        'scheduled_at': iso,
      });
      await _refreshPublishSlice(project, token);
      messenger?.showSnackBar(
        SnackBar(content: Text('首张草稿已设为定时：$iso（UTC）')),
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
    setState(() {
      _publishBusy = true;
    });
    try {
      final draftId = _publishDrafts.first.id;
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
          final snapshot = await _capturePublishSlice(project, token);
          publishMatrixSnap = snapshot.matrix;
          publishUnavailableSnap = snapshot.unavailable;
          publishDraftsSnap = snapshot.drafts;
          publishPrepareSnap = snapshot.prepare;
          publishJobsSnap = snapshot.jobs;
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
        _publishPrepare = publishPrepareSnap;
        _publishJobs = publishJobsSnap;
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
