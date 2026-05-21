import 'package:flutter/material.dart';

import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_getting_started_steps.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../projects/controller.dart';
import '../rust_api.dart';
import '../studio/recent_projects_prefs.dart';
import '../team_workspaces/strings.dart';
import 'studio_readiness.dart';
import '../settings/model_vendors/vendor_setup_projects_nudge.dart';
import 'create_project_wizard.dart';
import 'projects_grid_view.dart';

/// Product-shell projects home (Wave 2): grid, recent row, wizard create.
class ProjectsStudioHome extends StatefulWidget {
  const ProjectsStudioHome({
    super.key,
    required this.controller,
    required this.onOpenProjectStudio,
    required this.onCreateProject,
    this.currentProjectNumericId,
    this.onSelectProjectScope,
    this.accessToken,
    this.currentWorkspaceName,
    this.currentWorkspaceType,
    this.onOpenTeamWorkspaces,
    this.onOpenModelVendorSettings,
  });

  final ProjectsController controller;
  final String? accessToken;
  final int? currentProjectNumericId;
  final Future<void> Function(ProjectRow row)? onSelectProjectScope;
  final ValueChanged<ProjectRow> onOpenProjectStudio;
  final Future<bool> Function(Map<String, dynamic> fields) onCreateProject;
  final String? currentWorkspaceName;
  final String? currentWorkspaceType;
  final VoidCallback? onOpenTeamWorkspaces;
  final VoidCallback? onOpenModelVendorSettings;

  @override
  State<ProjectsStudioHome> createState() => _ProjectsStudioHomeState();
}

class _ProjectsStudioHomeState extends State<ProjectsStudioHome> {
  List<String> _recentIds = const <String>[];
  final Map<String, int> _progressByProjectId = <String, int>{};

  bool get _enterpriseEmpty =>
      widget.currentWorkspaceType == 'enterprise' &&
      widget.controller.projects != null &&
      widget.controller.projects!.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoadProjects());
  }

  Future<void> _loadRecent() async {
    final ids = await StudioRecentProjectsPrefs.load();
    if (!mounted) return;
    setState(() => _recentIds = ids);
  }

  void _autoLoadProjects() {
    if (widget.controller.projects == null &&
        !widget.controller.loadingProjects) {
      widget.controller.loadProjects().then((_) => _loadReadinessForProjects());
    } else if (widget.controller.projects != null) {
      _loadReadinessForProjects();
    }
  }

  Future<void> _loadReadinessForProjects() async {
    final token = widget.accessToken;
    final projects = widget.controller.projects;
    if (token == null ||
        token.isEmpty ||
        projects == null ||
        projects.isEmpty) {
      return;
    }
    final next = <String, int>{};
    for (final project in projects.take(12)) {
      try {
        ProjectShortVideoReadiness? readiness;
        ProjectProductionOverview? production;
        try {
          readiness = await fetchProjectShortVideoReadinessByProjectId(
            token,
            project.id,
          );
        } catch (_) {}
        try {
          production = await fetchProjectProductionOverviewByProjectId(
            token,
            project.id,
          );
        } catch (_) {}
        next[project.id] = computeStudioCompletedSteps(
          readiness: readiness,
          production: production,
        );
      } catch (_) {
        next[project.id] = 1;
      }
    }
    if (!mounted) return;
    setState(() {
      _progressByProjectId
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _createProject() async {
    final fields = await showCreateProjectWizard(context);
    if (!mounted || fields == null) return;
    final ok = await widget.onCreateProject(fields);
    if (!mounted || !ok) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.projectsSnackProjectCreated)));
  }

  List<ProjectRow> _resolveRecent(List<ProjectRow> all) {
    if (_recentIds.isEmpty) return const <ProjectRow>[];
    final byId = {for (final p in all) p.id: p};
    return _recentIds
        .map((id) => byId[id])
        .whereType<ProjectRow>()
        .toList(growable: false);
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    bool stacked,
  ) {
    final action = StudioPrimaryButton(
      label: widget.controller.creatingProject
          ? l10n.projectsCreating
          : l10n.studioCreateProject,
      icon: Icons.add,
      loading: widget.controller.creatingProject,
      onPressed: widget.controller.creatingProject ? null : _createProject,
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioProjectsHomeTitle,
            style: studioPageTitleStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
          Text(
            l10n.studioProjectsHomeSubtitle,
            style: studioSectionIntroStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.section - 6),
          action,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.studioProjectsHomeTitle,
                style: studioPageTitleStyle(context),
              ),
              const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
              Text(
                l10n.studioProjectsHomeSubtitle,
                style: studioSectionIntroStyle(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: StudioSpacing.sm),
        action,
      ],
    );
  }

  Widget _buildRecentRail(
    BuildContext context,
    AppLocalizations l10n,
    List<ProjectRow> recent, {
    required bool vertical,
    required double recentCardWidth,
  }) {
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.studioContinueCreating,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleSubtitle + 6),
          for (var i = 0; i < recent.length; i++) ...<Widget>[
            SizedBox(
              width: recentCardWidth,
              height: 132,
              child: _RecentProjectChip(
                project: recent[i],
                selected: widget.currentProjectNumericId == recent[i].numericId,
                onTap: widget.onSelectProjectScope == null
                    ? () => widget.onOpenProjectStudio(recent[i])
                    : () => widget.onSelectProjectScope!(recent[i]),
              ),
            ),
            if (i != recent.length - 1)
              const SizedBox(height: StudioSpacing.sm),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.studioContinueCreating, style: studioPaneTitleStyle(context)),
        const SizedBox(height: StudioSpacing.sm),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: StudioSpacing.sm),
            itemBuilder: (context, index) {
              final project = recent[index];
              return SizedBox(
                width: recentCardWidth,
                child: _RecentProjectChip(
                  project: project,
                  selected: widget.currentProjectNumericId == project.numericId,
                  onTap: widget.onSelectProjectScope == null
                      ? () => widget.onOpenProjectStudio(project)
                      : () => widget.onSelectProjectScope!(project),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final projects = widget.controller.projects ?? const <ProjectRow>[];
        final recent = _resolveRecent(projects);
        final width = MediaQuery.sizeOf(context).width;
        final stackedHeader = width < 760;
        final useSplitOverview =
            width >= 1360 && recent.isNotEmpty && projects.isNotEmpty;
        final contentMaxWidth = width >= 2200
            ? 1980.0
            : width >= 1800
            ? 1720.0
            : width >= 1440
            ? 1480.0
            : width >= 1280
            ? 1320.0
            : double.infinity;
        final recentCardWidth = width >= 1800
            ? 320.0
            : width >= 1440
            ? 288.0
            : width >= 1080
            ? 272.0
            : 260.0;

        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(context, l10n, stackedHeader),
                  if (widget.onOpenModelVendorSettings != null)
                    VendorSetupProjectsNudge(
                      accessToken: widget.accessToken,
                      onOpenModelVendorSettings:
                          widget.onOpenModelVendorSettings!,
                    ),
                  if (_enterpriseEmpty) ...<Widget>[
                    const SizedBox(height: StudioLayoutSpacing.section - 4),
                    _EnterpriseEmptyBanner(
                      workspaceName: widget.currentWorkspaceName,
                      creating: widget.controller.creatingProject,
                      onCreate: _createProject,
                      onOpenTeamWorkspaces: widget.onOpenTeamWorkspaces,
                    ),
                  ],
                  if (widget.currentProjectNumericId == null &&
                      projects.isNotEmpty) ...<Widget>[
                    const SizedBox(height: StudioLayoutSpacing.section - 4),
                    _SelectProjectHintBanner(
                      message: l10n.studioPipelineSelectProjectFirst,
                    ),
                  ],
                  if (useSplitOverview) ...<Widget>[
                    const SizedBox(height: StudioLayoutSpacing.section + 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: recentCardWidth + 24,
                          child: _buildRecentRail(
                            context,
                            l10n,
                            recent,
                            vertical: true,
                            recentCardWidth: recentCardWidth + 24,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: ProjectsGridView(
                            projects: projects,
                            loading: widget.controller.loadingProjects,
                            currentProjectNumericId:
                                widget.currentProjectNumericId,
                            progressForProject: (p) =>
                                _progressByProjectId[p.id] ?? 0,
                            onSelectProject: widget.onSelectProjectScope,
                            onOpenProject: widget.onOpenProjectStudio,
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    if (recent.isNotEmpty) ...<Widget>[
                      const SizedBox(height: StudioLayoutSpacing.section + 4),
                      _buildRecentRail(
                        context,
                        l10n,
                        recent,
                        vertical: false,
                        recentCardWidth: recentCardWidth,
                      ),
                    ],
                    const SizedBox(height: StudioLayoutSpacing.section + 4),
                    if (projects.isEmpty && !widget.controller.loadingProjects)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          StudioEmptyState.firstUse(
                            title: l10n.studioProjectsEmptyTitle,
                            subtitle: l10n.studioProjectsEmptySubtitle,
                            icon: Icons.folder_open_outlined,
                            actionLabel: l10n.studioCreateProject,
                            onAction: _createProject,
                          ),
                          const SizedBox(height: StudioLayoutSpacing.section + 4),
                          StudioGettingStartedSteps(
                            steps: <String>[
                              l10n.studioProjectsEmptyStep1,
                              l10n.studioProjectsEmptyStep2,
                              l10n.studioProjectsEmptyStep3,
                            ],
                          ),
                        ],
                      )
                    else
                      ProjectsGridView(
                        projects: projects,
                        loading: widget.controller.loadingProjects,
                        currentProjectNumericId: widget.currentProjectNumericId,
                        progressForProject: (p) =>
                            _progressByProjectId[p.id] ?? 0,
                        onSelectProject: widget.onSelectProjectScope,
                        onOpenProject: widget.onOpenProjectStudio,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentProjectChip extends StatelessWidget {
  const _RecentProjectChip({
    required this.project,
    required this.onTap,
    this.selected = false,
  });

  final ProjectRow project;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);

    return Material(
      color: selected ? tokens.bgElevated : tokens.bgInset,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tokens.primary : tokens.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.studioContinueCreating,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, size: 18, color: tokens.primary),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: studioCardTitleStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnterpriseEmptyBanner extends StatelessWidget {
  const _EnterpriseEmptyBanner({
    required this.workspaceName,
    required this.creating,
    required this.onCreate,
    this.onOpenTeamWorkspaces,
  });

  final String? workspaceName;
  final bool creating;
  final VoidCallback onCreate;
  final VoidCallback? onOpenTeamWorkspaces;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton + 2),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.projectsEnterpriseEmptyTitle,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
          Text(
            buildEnterpriseProjectsEmptyStateBody(l10n, workspaceName),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: StudioSpacing.sm),
          Wrap(
            spacing: StudioSpacing.xs,
            children: <Widget>[
              StudioPrimaryButton(
                label: creating
                    ? l10n.projectsCreating
                    : l10n.projectsCreateFirstEmpty,
                onPressed: creating ? null : onCreate,
              ),
              if (onOpenTeamWorkspaces != null)
                OutlinedButton(
                  onPressed: onOpenTeamWorkspaces,
                  child: Text(l10n.projectsOpenTeamWorkspaces),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectProjectHintBanner extends StatelessWidget {
  const _SelectProjectHintBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioLayoutSpacing.cardInner,
          vertical: StudioSpacing.sm - 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.touch_app_outlined, size: 18, color: tokens.textMuted),
            const SizedBox(width: StudioSpacing.sm - 6),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
