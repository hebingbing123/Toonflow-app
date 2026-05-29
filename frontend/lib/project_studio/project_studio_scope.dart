import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/components/studio_async_data_view.dart';
import '../demo/product_demo_mode.dart';
import '../demo/studio_demo_data.dart';
import '../rust_api.dart';
import 'project_studio_host.dart';
import 'project_studio_page.dart';
import 'creator_journey_telemetry.dart';
import 'studio_readiness.dart';
import 'studio_snapshot_bus.dart';
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
  Future<void>? _loadInFlight;
  var _jobPollBackoffSeconds = 4;

  @override
  void initState() {
    super.initState();
    CreatorJourneyTelemetry.bindProject(
      accessToken: widget.accessToken,
      projectUuid: widget.projectUuid,
      projectNumericId: widget.projectNumericId,
    );
    kStudioSnapshotBus.addListener(_onSnapshotBusChanged);
    _load();
  }

  @override
  void dispose() {
    kStudioSnapshotBus.removeListener(_onSnapshotBusChanged);
    _jobPollTimer?.cancel();
    CreatorJourneyTelemetry.clearProject();
    super.dispose();
  }

  void _onSnapshotBusChanged() {
    final pending = kStudioSnapshotBus.pendingKeys;
    if (!pending.contains(StudioSnapshotKey.readiness)) {
      return;
    }
    kStudioSnapshotBus.clearPending(const <StudioSnapshotKey>[
      StudioSnapshotKey.readiness,
    ]);
    unawaited(_load(showLoadingIndicator: false));
  }

  void _scheduleJobPollIfNeeded(StudioReadinessSnapshot snap) {
    _jobPollTimer?.cancel();
    if (snap.runningJobCount <= 0) {
      _jobPollBackoffSeconds = 4;
      return;
    }
    _jobPollTimer = Timer.periodic(
      Duration(seconds: _jobPollBackoffSeconds),
      (_) {
        unawaited(_pollJobCountsOnly());
      },
    );
  }

  Future<void> _pollJobCountsOnly() async {
    if (_readiness == null) {
      return;
    }
    try {
      final counts = await fetchProjectJobCounts(
        widget.accessToken,
        widget.projectUuid,
      );
      if (!mounted) {
        return;
      }
      _jobPollBackoffSeconds = 4;
      final current = _readiness!;
      if (current.runningJobCount == counts.runningJobCount &&
          current.failedJobCount == counts.failedJobCount) {
        if (counts.runningJobCount <= 0) {
          _jobPollTimer?.cancel();
        }
        return;
      }
      final next = StudioReadinessSnapshot(
        completedSteps: current.completedSteps,
        readiness: current.readiness,
        production: current.production,
        home: current.home,
        assetsOverview: current.assetsOverview,
        runningJobCount: counts.runningJobCount,
        failedJobCount: counts.failedJobCount,
      );
      setState(() => _readiness = next);
      _scheduleJobPollIfNeeded(next);
    } catch (e) {
      if (_isRateLimitedError(e)) {
        _jobPollBackoffSeconds = (_jobPollBackoffSeconds * 2).clamp(4, 60);
        _jobPollTimer?.cancel();
        _scheduleJobPollIfNeeded(_readiness!);
      }
    }
  }

  bool _isRateLimitedError(Object error) {
    if (error is RustApiException) {
      return error.statusCode == 429 || error.statusCode == 503;
    }
    return false;
  }

  bool _snapshotsEqualForUi(
    StudioReadinessSnapshot? a,
    StudioReadinessSnapshot b,
  ) {
    if (a == null) {
      return false;
    }
    return a.completedSteps == b.completedSteps &&
        a.runningJobCount == b.runningJobCount &&
        a.failedJobCount == b.failedJobCount &&
        identical(a.readiness, b.readiness) &&
        identical(a.production, b.production) &&
        identical(a.home, b.home) &&
        identical(a.assetsOverview, b.assetsOverview);
  }

  Future<void> _load({bool showLoadingIndicator = true}) {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _loadImpl(showLoadingIndicator: showLoadingIndicator);
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
  }

  Future<void> _loadImpl({required bool showLoadingIndicator}) async {
    if (showLoadingIndicator) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await (widget.loadSnapshot ?? _defaultLoadSnapshot)(
        widget.accessToken,
        widget.projectUuid,
      );
      if (!mounted) return;
      if (_snapshotsEqualForUi(_readiness, snapshot)) {
        if (showLoadingIndicator) {
          setState(() => _loading = false);
        }
        _scheduleJobPollIfNeeded(snapshot);
        return;
      }
      setState(() {
        _readiness = snapshot;
        if (showLoadingIndicator) {
          _loading = false;
        }
      });
      _jobPollBackoffSeconds = 4;
      _scheduleJobPollIfNeeded(snapshot);
    } catch (e) {
      if (!mounted) return;
      if (_isRateLimitedError(e) && !showLoadingIndicator) {
        _jobPollBackoffSeconds = (_jobPollBackoffSeconds * 2).clamp(4, 60);
        _jobPollTimer?.cancel();
        if (_readiness != null) {
          _scheduleJobPollIfNeeded(_readiness!);
        }
        return;
      }
      setState(() {
        if (showLoadingIndicator) {
          _error = e;
          _loading = false;
          _readiness = const StudioReadinessSnapshot(completedSteps: 1);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _readiness ?? const StudioReadinessSnapshot(completedSteps: 1);
    return StudioAsyncDataView(
      loading: _loading,
      error: _error,
      onRetry: _load,
      scrollableLoading: true,
      child: ProjectStudioPage(host: widget.hostFactory(snap, _load)),
    );
  }
}

typedef ProjectJobCounts = ({int runningJobCount, int failedJobCount});

Future<ProjectJobCounts> fetchProjectJobCounts(
  String accessToken,
  String projectUuid,
) async {
  if (ProductDemoMode.instance.shouldSkipLiveApi) {
    return (runningJobCount: 0, failedJobCount: 0);
  }
  var runningJobCount = 0;
  var failedJobCount = 0;
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
  return (
    runningJobCount: runningJobCount,
    failedJobCount: failedJobCount,
  );
}

Future<StudioReadinessSnapshot> _defaultLoadSnapshot(
  String accessToken,
  String projectUuid,
) async {
  if (ProductDemoMode.instance.shouldSkipLiveApi) {
    return buildDemoStudioReadinessSnapshot(accessToken, projectUuid);
  }
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
    final counts = await fetchProjectJobCounts(accessToken, projectUuid);
    runningJobCount = counts.runningJobCount;
    failedJobCount = counts.failedJobCount;
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
