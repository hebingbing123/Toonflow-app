import 'package:flutter/material.dart';

import '../demo/product_demo_mode.dart';
import '../demo/product_demo_tour_anchors.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_getting_started_steps.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../projects/controller.dart';
import '../rust_api.dart';
import '../studio/recent_projects_prefs.dart';
import '../team_workspaces/strings.dart';
import 'studio_readiness.dart';
import 'create_project_wizard.dart';
import 'projects_grid_view.dart';
import 'projects_studio_home_layout.dart';
import 'studio_step_progress_ring.dart';

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
    this.onExploreDemo,
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
  final VoidCallback? onExploreDemo;

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
    _autoLoadProjects();
  }

  Future<void> _loadRecent() async {
    final ids = await StudioRecentProjectsPrefs.load();
    if (!mounted) return;
    setState(() => _recentIds = ids);
  }

  void _autoLoadProjects() {
    if (widget.controller.skipDemoApi ||
        ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    if (widget.controller.projects == null &&
        !widget.controller.loadingProjects) {
      widget.controller.loadProjects().then((_) => _loadReadinessForProjects());
    } else if (widget.controller.projects != null) {
      _loadReadinessForProjects();
    }
  }

  Future<void> _loadReadinessForProjects() async {
    if (widget.controller.skipDemoApi ||
        ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
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
    ProjectsStudioHomeLayout layout, {
    required bool includeCreateAction,
  }) {
    final stacked = layout.stackedHeader;
    final tokens = StudioTokens.of(context);
    final creating = widget.controller.creatingProject;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.studioProjectsHomeTitle,
          style: stacked
              ? studioPageTitleStyle(context)
              : studioPaneTitleStyle(context),
        ),
        SizedBox(
          height: stacked
              ? StudioLayoutSpacing.titleSubtitle
              : StudioSpacing.xs,
        ),
        Text(
          l10n.studioProjectsHomeSubtitle,
          maxLines: stacked ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: stacked
              ? studioSectionIntroStyle(context)
              : studioHintStyle(context),
        ),
      ],
    );
    final createAction = StudioPrimaryButton(
      label: creating ? l10n.projectsCreating : l10n.studioCreateProject,
      icon: Icons.add,
      loading: creating,
      onPressed: creating ? null : _createProject,
    );

    if (!includeCreateAction) {
      return Padding(
        padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.stackMedium),
        child: titleBlock,
      );
    }

    if (!stacked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.stackMedium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: titleBlock),
            const SizedBox(width: StudioSpacing.sm),
            createAction,
          ],
        ),
      );
    }

    if (layout.phoneStackedHeader) {
      return Padding(
        padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.stackMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            titleBlock,
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            SizedBox(width: double.infinity, child: createAction),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: studioShadowColor(context, alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetDense + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            titleBlock,
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            createAction,
          ],
        ),
      ),
    );
  }

  Widget _buildGettingStartedBlock(
    BuildContext context,
    AppLocalizations l10n,
    double width, {
    bool isPhone = false,
  }) {
    return StudioGettingStartedSteps(
      title: l10n.studioGettingStartedTitle,
      steps: <String>[
        l10n.studioProjectsEmptyStep1,
        l10n.studioProjectsEmptyStep2,
        l10n.studioProjectsEmptyStep3,
      ],
      maxWidth: isPhone
          ? double.infinity
          : width >= kProjectsHomeEmptySplitMinWidth
          ? 420
          : 560,
    );
  }

  Widget _buildEmptyProjectsOverview(
    BuildContext context,
    AppLocalizations l10n,
    double width, {
    bool isPhone = false,
    bool enterpriseGuided = false,
  }) {
    final gettingStarted = _buildGettingStartedBlock(
      context,
      l10n,
      width,
      isPhone: isPhone,
    );
    if (enterpriseGuided) {
      return gettingStarted;
    }
    final showSecondaryAction = widget.onOpenModelVendorSettings != null;
    final emptyState = StudioEmptyState.firstUse(
      title: l10n.studioProjectsEmptyTitle,
      subtitle: l10n.studioProjectsEmptySubtitle,
      icon: Icons.folder_open_outlined,
      actionLabel: l10n.studioCreateProject,
      onAction: _createProject,
      secondaryActionLabel: showSecondaryAction
          ? l10n.studioModelRoutingOpenVendorSettings
          : null,
      onSecondaryAction: showSecondaryAction
          ? widget.onOpenModelVendorSettings
          : null,
    );

    if (!isPhone && width >= kProjectsHomeEmptySplitMinWidth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                emptyState,
                if (widget.onExploreDemo != null) ...<Widget>[
                  const SizedBox(height: StudioSpacing.sm),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      key: const Key('projects-home-explore-demo-wide'),
                      onPressed: widget.onExploreDemo,
                      child: Text(l10n.productDemoModeExploreLoggedIn),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: StudioSpacing.md),
          Expanded(flex: 5, child: gettingStarted),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        emptyState,
        if (widget.onExploreDemo != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.sm),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              key: const Key('projects-home-explore-demo'),
              onPressed: widget.onExploreDemo,
              child: Text(l10n.productDemoModeExploreLoggedIn),
            ),
          ),
        ],
        const SizedBox(height: StudioLayoutSpacing.section + 4),
        gettingStarted,
      ],
    );
  }

  Widget _buildRecentRail(
    BuildContext context,
    AppLocalizations l10n,
    List<ProjectRow> recent, {
    required bool vertical,
    required double recentCardWidth,
    bool compact = false,
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
              height: compact ? 112 : 132,
              child: _RecentProjectChip(
                project: recent[i],
                completedSteps: _progressByProjectId[recent[i].id] ?? 0,
                compact: compact,
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
          height: compact ? 120 : 152,
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
                  completedSteps: _progressByProjectId[project.id] ?? 0,
                  compact: compact,
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final layout = ProjectsStudioHomeLayout.resolve(
              context: context,
              contentWidth: constraints.maxWidth,
            );
            final contentWidth = layout.contentWidth;
            final projectsLoaded = widget.controller.projectsLoaded;
            final projects = widget.controller.projects ?? const <ProjectRow>[];
            final showProjectsLoading =
                !projectsLoaded ||
                (widget.controller.loadingProjects && projects.isEmpty);
            final recent = _resolveRecent(projects);
            final showRecentRail = recent.isNotEmpty && projects.length > 2;
            final projectsEmpty =
                projectsLoaded && !showProjectsLoading && projects.isEmpty;
            final useSplitOverview =
                layout.useSplitOverview && showRecentRail && projects.isNotEmpty;
            final contentMaxWidth = projectsHomeContentMaxWidth(
              contentWidth,
              isPhone: layout.isPhone,
            );
            final recentCardWidth = projectsHomeRecentCardWidth(
              contentWidth,
              isPhone: layout.isPhone,
            );
            final scrollPadding = EdgeInsets.fromLTRB(
              layout.isPhone ? StudioSpacing.sm : 0,
              0,
              layout.isPhone ? StudioSpacing.sm : 0,
              StudioSpacing.md,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: scrollPadding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeader(
                        context,
                        l10n,
                        layout,
                        includeCreateAction:
                            !projectsEmpty || _enterpriseEmpty,
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
                          child: ProductDemoTourAnchor(
                            anchorId: ProductDemoTourAnchorIds.projectsGrid,
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
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    if (showRecentRail) ...<Widget>[
                      const SizedBox(height: StudioLayoutSpacing.section + 4),
                      _buildRecentRail(
                        context,
                        l10n,
                        recent,
                        vertical: false,
                        recentCardWidth: recentCardWidth,
                        compact: layout.isPhone,
                      ),
                    ],
                    const SizedBox(height: StudioLayoutSpacing.stackMedium),
                    if (showProjectsLoading)
                      ProjectsGridView(
                        projects: const <ProjectRow>[],
                        loading: true,
                        currentProjectNumericId: widget.currentProjectNumericId,
                        onSelectProject: widget.onSelectProjectScope,
                        onOpenProject: widget.onOpenProjectStudio,
                      )
                    else if (projects.isEmpty)
                      _buildEmptyProjectsOverview(
                        context,
                        l10n,
                        contentWidth,
                        isPhone: layout.isPhone,
                        enterpriseGuided: _enterpriseEmpty,
                      )
                    else
                      ProductDemoTourAnchor(
                        anchorId: ProductDemoTourAnchorIds.projectsGrid,
                        child: ProjectsGridView(
                          projects: projects,
                          loading: widget.controller.loadingProjects,
                          currentProjectNumericId: widget.currentProjectNumericId,
                          progressForProject: (p) =>
                              _progressByProjectId[p.id] ?? 0,
                          onSelectProject: widget.onSelectProjectScope,
                          onOpenProject: widget.onOpenProjectStudio,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }
}

class _RecentProjectChip extends StatelessWidget {
  const _RecentProjectChip({
    required this.project,
    required this.onTap,
    this.completedSteps = 0,
    this.selected = false,
    this.compact = false,
  });

  final ProjectRow project;
  final VoidCallback onTap;
  final int completedSteps;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? tokens.primarySoft.withValues(alpha: 0.42)
                : tokens.bgInset.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
            border: Border.all(
              color: selected ? tokens.primary : tokens.borderSubtle,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(
              compact
                  ? StudioLayoutSpacing.insetDense
                  : StudioLayoutSpacing.insetComfortable,
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '#${project.numericId}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.check_circle,
                        size: compact ? 16 : 18,
                        color: tokens.primary,
                      ),
                    ),
                  StudioStepProgressRing(
                    completedSteps: completedSteps,
                    size: compact ? 28 : 32,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: studioCardTitleStyle(context),
              ),
            ],
            ),
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
        color: tokens.primarySoft.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton + 2),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.24)),
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
        color: tokens.primarySoft.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioLayoutSpacing.cardInner,
          vertical: StudioSpacing.sm - 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.touch_app_outlined, size: 18, color: tokens.primary),
            const SizedBox(width: StudioSpacing.sm - 6),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
