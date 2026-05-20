import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/ix/studio_api_error_callout.dart';
import '../rust_api.dart';
import 'project_studio_host.dart';
import 'project_studio_page.dart';
import 'creator_journey_telemetry.dart';
import 'studio_readiness.dart';
import 'studio_step.dart';

typedef ProjectStudioReadinessLoader =
    Future<StudioReadinessSnapshot> Function(
      String accessToken,
      String projectUuid,
    );

typedef ProjectStudioHostFactory =
    ProjectStudioHost Function(
      StudioReadinessSnapshot readiness,
      Future<void> Function() refreshSnapshot,
    );

/// Loads readiness and builds [ProjectStudioPage].
class ProjectStudioScope extends StatefulWidget {
  const ProjectStudioScope({
    super.key,
    required this.accessToken,
    required this.projectNumericId,
    required this.projectUuid,
    required this.projectName,
    required this.initialStep,
    required this.hostFactory,
    this.loadSnapshot,
  });

  final String accessToken;
  final int projectNumericId;
  final String projectUuid;
  final String? projectName;
  final StudioStep initialStep;
  final ProjectStudioHostFactory hostFactory;
  final ProjectStudioReadinessLoader? loadSnapshot;

  @override
  State<ProjectStudioScope> createState() => _ProjectStudioScopeState();
}

class _ProjectStudioScopeState extends State<ProjectStudioScope> {
  StudioReadinessSnapshot? _readiness;
  var _loading = true;
  Object? _error;
  Timer? _jobPollTimer;

  @override
  void initState() {
    super.initState();
    CreatorJourneyTelemetry.bindProject(
      accessToken: widget.accessToken,
      projectUuid: widget.projectUuid,
      projectNumericId: widget.projectNumericId,
    );
    _load();
  }

  @override
  void dispose() {
    _jobPollTimer?.cancel();
    CreatorJourneyTelemetry.clearProject();
    super.dispose();
  }

  void _scheduleJobPollIfNeeded(StudioReadinessSnapshot snap) {
    _jobPollTimer?.cancel();
    if (snap.runningJobCount <= 0) {
      return;
    }
    _jobPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await (widget.loadSnapshot ?? _defaultLoadSnapshot)(
        widget.accessToken,
        widget.projectUuid,
      );
      if (!mounted) return;
      setState(() {
        _readiness = snapshot;
        _loading = false;
      });
      _scheduleJobPollIfNeeded(snapshot);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _readiness = const StudioReadinessSnapshot(completedSteps: 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final snap = _readiness ?? const StudioReadinessSnapshot(completedSteps: 1);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StudioApiErrorCallout(
            error: _error!,
            onRetry: _load,
            showDiagnostic: false,
          ),
        ),
      );
    }
    return ProjectStudioPage(host: widget.hostFactory(snap, _load));
  }
}

Future<StudioReadinessSnapshot> _defaultLoadSnapshot(
  String accessToken,
  String projectUuid,
) async {
  ProjectShortVideoReadiness? readiness;
  ProjectProductionOverview? production;
  ProjectHome? home;
  ProjectAssetsOverview? assetsOverview;
  try {
    readiness = await fetchProjectShortVideoReadinessByProjectId(
      accessToken,
      projectUuid,
    );
  } catch (_) {}
  try {
    production = await fetchProjectProductionOverviewByProjectId(
      accessToken,
      projectUuid,
    );
  } catch (_) {}
  try {
    home = await fetchProjectHomeByProjectId(accessToken, projectUuid);
  } catch (_) {}
  try {
    assetsOverview = await fetchProjectAssetsOverviewByProjectId(
      accessToken,
      projectUuid,
    );
  } catch (_) {}
  var runningJobCount = 0;
  var failedJobCount = 0;
  try {
    final active = await Future.wait([
      fetchJobs(accessToken, status: 'running', limit: 50),
      fetchJobs(accessToken, status: 'queued', limit: 50),
      fetchJobs(accessToken, status: 'failed', limit: 20),
    ]);
    final running = [...active[0], ...active[1]];
    final failed = active[2];
    bool matchesProject(JobRow row) =>
        row.payload['project_uuid']?.toString() == projectUuid;
    runningJobCount = running.where(matchesProject).length;
    failedJobCount = failed.where(matchesProject).length;
  } catch (_) {}

  return StudioReadinessSnapshot(
    completedSteps: computeStudioCompletedSteps(
      readiness: readiness,
      production: production,
    ),
    readiness: readiness,
    production: production,
    home: home,
    assetsOverview: assetsOverview,
    runningJobCount: runningJobCount,
    failedJobCount: failedJobCount,
  );
}
