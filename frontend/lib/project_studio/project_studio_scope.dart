import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'project_studio_host.dart';
import 'project_studio_page.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
      return Center(child: Text('$_error'));
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
  return StudioReadinessSnapshot(
    completedSteps: computeStudioCompletedSteps(
      readiness: readiness,
      production: production,
    ),
    readiness: readiness,
    production: production,
    home: home,
    assetsOverview: assetsOverview,
  );
}
