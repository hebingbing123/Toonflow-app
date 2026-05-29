import 'dart:async';

import 'package:flutter/material.dart';

import '../demo/product_demo_mode.dart';
import '../demo/product_demo_tour_anchors.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_getting_started_steps.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../platform/studio_optimistic_mutation.dart';
import '../projects/controller.dart';
import '../rust_api.dart';
import '../studio/pinned_projects_prefs.dart';
import '../studio/recent_projects_prefs.dart';
import '../design_system/components/studio_icon_button.dart';
import '../team_workspaces/strings.dart';
import 'studio_readiness.dart';
import 'create_project_wizard.dart';
import 'projects_grid_view.dart';
import 'projects_studio_home_layout.dart';
import 'studio_step_prefs.dart';
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
  Set<String> _pinnedIds = <String>{};
  final Map<String, int> _progressByProjectId = <String, int>{};
  var _loadingProjectProgress = false;
  String? _loadedProgressProjectsKey;
  Timer? _progressReloadDebounce;
  int _progressLoadGeneration = 0;

  bool get _enterpriseEmpty =>
      widget.currentWorkspaceType == 'enterprise' &&
      widget.controller.projects != null &&
      widget.controller.projects!.isEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onProjectsControllerChanged);
    StudioStepPrefs.changes.addListener(_onStudioStepPrefsChanged);
    _loadRecent();
    _loadPinned();
    _autoLoadProjects();
  }

  @override
  void dispose() {
    _progressReloadDebounce?.cancel();
    widget.controller.removeListener(_onProjectsControllerChanged);
    StudioStepPrefs.changes.removeListener(_onStudioStepPrefsChanged);
    super.dispose();
  }

  void _scheduleProgressReload({bool force = false}) {
    _progressReloadDebounce?.cancel();
    _progressReloadDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      unawaited(_loadReadinessForProjects(force: force));
    });
  }

  void _onProjectsControllerChanged() {
    final projects = widget.controller.projects;
    if (projects == null || projects.isEmpty) {
      return;
    }
    final key = projects.map((project) => project.id).join('|');
    if (key == _loadedProgressProjectsKey) {
      return;
    }
    _scheduleProgressReload();
  }

  void _onStudioStepPrefsChanged() {
    _scheduleProgressReload(force: true);
  }

  Future<void> _loadRecent() async {
    final ids = await StudioRecentProjectsPrefs.load();
    if (!mounted) return;
    setState(() => _recentIds = ids);
  }

  Future<void> _loadPinned() async {
    final ids = await StudioPinnedProjectsPrefs.load(
      accessToken: widget.accessToken,
    );
    if (!mounted) return;
    setState(() => _pinnedIds = ids);
  }

  Future<void> _togglePinned(String projectId) async {
    final previous = _pinnedIds;
    Set<String>? optimistic;
    try {
      await studioRunOptimisticMutation(
        apply: () {
          final next = Set<String>.from(_pinnedIds);
          if (next.contains(projectId)) {
            next.remove(projectId);
          } else {
            next.add(projectId);
          }
          optimistic = next;
          setState(() => _pinnedIds = next);
        },
        rollback: () {
          setState(() => _pinnedIds = previous);
        },
        commit: () async {
          final persisted = await StudioPinnedProjectsPrefs.toggle(
            projectId,
            accessToken: widget.accessToken,
            current: optimistic ?? previous,
          );
          if (!mounted) return;
          setState(() => _pinnedIds = persisted);
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _pinnedIds = previous);
    }
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

  Future<void> _loadReadinessForProjects({bool force = false}) async {
    if (widget.controller.skipDemoApi ||
        ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    if (_loadingProjectProgress && !force) {
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
    final projectsKey = projects.map((project) => project.id).join('|');
    if (!force && projectsKey == _loadedProgressProjectsKey) {
      return;
    }

    _loadingProjectProgress = true;
    final generation = ++_progressLoadGeneration;
    final targets = projects.take(24).toList(growable: false);
    try {
      final lastSteps = await StudioStepPrefs.loadLastSteps(
        targets.map((project) => project.numericId),
      );
      final next = <String, int>{};

      Future<int> loadProgressFor(ProjectRow project) async {
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
        return computeProjectListProgressSteps(
          readiness: readiness,
          production: production,
          lastVisitedStep: lastSteps[project.numericId],
        );
      }

      const batchSize = 4;
      for (var start = 0; start < targets.length; start += batchSize) {
        if (!mounted || generation != _progressLoadGeneration) {
          return;
        }
        final batch = targets
            .skip(start)
            .take(batchSize)
            .toList(growable: false);
        final entries = await Future.wait(
          batch.map((project) async {
            return MapEntry(project.id, await loadProgressFor(project));
          }),
        );
        for (final entry in entries) {
          next[entry.key] = entry.value;
        }
      }
      if (!mounted || generation != _progressLoadGeneration) {
        return;
      }
      setState(() {
        _progressByProjectId
          ..clear()
          ..addAll(next);
        _loadedProgressProjectsKey = projectsKey;
      });
    } finally {
      if (generation == _progressLoadGeneration) {
        _loadingProjectProgress = false;
      }
    }
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
    if (_recentIds.isEmpty && _pinnedIds.isEmpty) {
      return const <ProjectRow>[];
    }
    final byId = {for (final p in all) p.id: p};
    final orderedIds = <String>[
      ..._pinnedIds,
      ..._recentIds.where((id) => !_pinnedIds.contains(id)),
    ];
    return orderedIds
        .map((id) => byId[id])
        .whereType<ProjectRow>()
        .take(8)
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
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetDense + StudioSpacing.radiusHairline),
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
              child: StudioStaggeredEntrance(
                index: i > 8 ? 0 : i,
                child: _RecentProjectChip(
                  project: recent[i],
                  completedSteps: _progressByProjectId[recent[i].id] ?? 0,
                  compact: compact,
                  selected: widget.currentProjectNumericId == recent[i].numericId,
                  isPinned: _pinnedIds.contains(recent[i].id),
                  onTogglePin: () => _togglePinned(recent[i].id),
                  onTap: widget.onSelectProjectScope == null
                      ? () => widget.onOpenProjectStudio(recent[i])
                      : () => widget.onSelectProjectScope!(recent[i]),
                ),
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
                child: _wrapRecentEntrance(
                  index,
                  _RecentProjectChip(
                    project: project,
                    completedSteps: _progressByProjectId[project.id] ?? 0,
                    compact: compact,
                    selected: widget.currentProjectNumericId == project.numericId,
                    isPinned: _pinnedIds.contains(project.id),
                    onTogglePin: () => _togglePinned(project.id),
                    onTap: widget.onSelectProjectScope == null
                        ? () => widget.onOpenProjectStudio(project)
                        : () => widget.onSelectProjectScope!(project),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _wrapRecentEntrance(int index, Widget child) {
    if (index > 8) {
      return child;
    }
    return StudioStaggeredEntrance(index: index, child: child);
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
            final gridEntranceKey = projects.isEmpty
                ? null
                : '${projects.length}:${projects.first.id}';
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

            final splitGridMaxHeight = MediaQuery.sizeOf(context).height * 0.72;
            final overviewArgs = (
              context: context,
              l10n: l10n,
              layout: layout,
              projects: projects,
              projectsEmpty: projectsEmpty,
              showRecentRail: showRecentRail,
              recent: recent,
              recentCardWidth: recentCardWidth,
              gridEntranceKey: gridEntranceKey,
              showProjectsLoading: showProjectsLoading,
              contentWidth: contentWidth,
              useSplitOverview: useSplitOverview,
            );

            if (!constraints.hasBoundedHeight) {
              // Product shell wraps panes in an outer ListView; avoid nested
              // viewports and SliverConstrainedCrossAxis under shrink-wrap.
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: scrollPadding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ..._buildOverviewColumnChildren(
                          context: overviewArgs.context,
                          l10n: overviewArgs.l10n,
                          layout: overviewArgs.layout,
                          projects: overviewArgs.projects,
                          projectsEmpty: overviewArgs.projectsEmpty,
                          showRecentRail: overviewArgs.showRecentRail,
                          recent: overviewArgs.recent,
                          recentCardWidth: overviewArgs.recentCardWidth,
                          gridEntranceKey: overviewArgs.gridEntranceKey,
                          showProjectsLoading: overviewArgs.showProjectsLoading,
                          contentWidth: overviewArgs.contentWidth,
                          useSplitOverview: overviewArgs.useSplitOverview,
                          includeGrid: !useSplitOverview,
                        ),
                        if (useSplitOverview)
                          _buildSplitOverviewGridRow(
                            context: context,
                            l10n: l10n,
                            projects: projects,
                            recent: recent,
                            recentCardWidth: recentCardWidth,
                            gridEntranceKey: gridEntranceKey,
                            showProjectsLoading: showProjectsLoading,
                            splitGridMaxHeight: splitGridMaxHeight,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: scrollPadding,
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverConstrainedCrossAxis(
                      maxExtent: contentMaxWidth,
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _buildOverviewColumnChildren(
                            context: overviewArgs.context,
                            l10n: overviewArgs.l10n,
                            layout: overviewArgs.layout,
                            projects: overviewArgs.projects,
                            projectsEmpty: overviewArgs.projectsEmpty,
                            showRecentRail: overviewArgs.showRecentRail,
                            recent: overviewArgs.recent,
                            recentCardWidth: overviewArgs.recentCardWidth,
                            gridEntranceKey: overviewArgs.gridEntranceKey,
                            showProjectsLoading: overviewArgs.showProjectsLoading,
                            contentWidth: overviewArgs.contentWidth,
                            useSplitOverview: overviewArgs.useSplitOverview,
                            includeGrid: false,
                          ),
                        ),
                      ),
                    ),
                    if (useSplitOverview &&
                        (showProjectsLoading || projects.isNotEmpty))
                      SliverConstrainedCrossAxis(
                        maxExtent: contentMaxWidth,
                        sliver: SliverToBoxAdapter(
                          child: _buildSplitOverviewGridRow(
                            context: context,
                            l10n: l10n,
                            projects: projects,
                            recent: recent,
                            recentCardWidth: recentCardWidth,
                            gridEntranceKey: gridEntranceKey,
                            showProjectsLoading: showProjectsLoading,
                            splitGridMaxHeight: splitGridMaxHeight,
                          ),
                        ),
                      )
                    else if (showProjectsLoading)
                      SliverConstrainedCrossAxis(
                        maxExtent: contentMaxWidth,
                        sliver: SliverToBoxAdapter(
                          child: ProjectsGridView(
                            projects: const <ProjectRow>[],
                            loading: true,
                            contentWidth: contentMaxWidth,
                            currentProjectNumericId:
                                widget.currentProjectNumericId,
                            onSelectProject: widget.onSelectProjectScope,
                            onOpenProject: widget.onOpenProjectStudio,
                          ),
                        ),
                      )
                    else if (projects.isEmpty)
                      SliverConstrainedCrossAxis(
                        maxExtent: contentMaxWidth,
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyProjectsOverview(
                            context,
                            l10n,
                            contentWidth,
                            isPhone: layout.isPhone,
                            enterpriseGuided: _enterpriseEmpty,
                          ),
                        ),
                      )
                    else
                      SliverConstrainedCrossAxis(
                        maxExtent: contentMaxWidth,
                        sliver: ProjectsGridView(
                          projects: projects,
                          loading: widget.controller.loadingProjects,
                          listEntranceKey: gridEntranceKey,
                          demoTourAnchorId: ProductDemoTourAnchorIds.projectsGrid,
                          currentProjectNumericId:
                              widget.currentProjectNumericId,
                          progressForProject: (p) =>
                              _progressByProjectId[p.id] ?? 0,
                          onSelectProject: widget.onSelectProjectScope,
                          onOpenProject: widget.onOpenProjectStudio,
                          pinnedProjectIds: _pinnedIds,
                          onTogglePin: _togglePinned,
                          asSliver: true,
                          contentWidth: contentMaxWidth,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildOverviewColumnChildren({
    required BuildContext context,
    required AppLocalizations l10n,
    required ProjectsStudioHomeLayout layout,
    required List<ProjectRow> projects,
    required bool projectsEmpty,
    required bool showRecentRail,
    required List<ProjectRow> recent,
    required double recentCardWidth,
    required Object? gridEntranceKey,
    required bool showProjectsLoading,
    required double contentWidth,
    required bool useSplitOverview,
    bool includeGrid = true,
  }) {
    final children = <Widget>[
      _buildHeader(
        context,
        l10n,
        layout,
        includeCreateAction: !projectsEmpty || _enterpriseEmpty,
      ),
    ];
    if (_enterpriseEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: StudioLayoutSpacing.section - 4),
        _EnterpriseEmptyBanner(
          workspaceName: widget.currentWorkspaceName,
          creating: widget.controller.creatingProject,
          onCreate: _createProject,
          onOpenTeamWorkspaces: widget.onOpenTeamWorkspaces,
        ),
      ]);
    }
    if (widget.currentProjectNumericId == null && projects.isNotEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: StudioLayoutSpacing.section - 4),
        _SelectProjectHintBanner(
          message: l10n.studioPipelineSelectProjectFirst,
        ),
      ]);
    }
    if (!useSplitOverview) {
      if (showRecentRail) {
        children.addAll(<Widget>[
          const SizedBox(height: StudioLayoutSpacing.section + 4),
          _buildRecentRail(
            context,
            l10n,
            recent,
            vertical: false,
            recentCardWidth: recentCardWidth,
            compact: layout.isPhone,
          ),
        ]);
      }
      if (includeGrid) {
        children.add(const SizedBox(height: StudioLayoutSpacing.stackMedium));
        if (showProjectsLoading) {
          children.add(
            ProjectsGridView(
              projects: const <ProjectRow>[],
              loading: true,
              currentProjectNumericId: widget.currentProjectNumericId,
              onSelectProject: widget.onSelectProjectScope,
              onOpenProject: widget.onOpenProjectStudio,
            ),
          );
        } else if (projects.isEmpty) {
          children.add(
            _buildEmptyProjectsOverview(
              context,
              l10n,
              contentWidth,
              isPhone: layout.isPhone,
              enterpriseGuided: _enterpriseEmpty,
            ),
          );
        } else {
          children.add(
            ProjectsGridView(
              projects: projects,
              loading: widget.controller.loadingProjects,
              listEntranceKey: gridEntranceKey,
              demoTourAnchorId: ProductDemoTourAnchorIds.projectsGrid,
              currentProjectNumericId: widget.currentProjectNumericId,
              progressForProject: (p) => _progressByProjectId[p.id] ?? 0,
              onSelectProject: widget.onSelectProjectScope,
              onOpenProject: widget.onOpenProjectStudio,
              pinnedProjectIds: _pinnedIds,
              onTogglePin: _togglePinned,
            ),
          );
        }
      }
    }
    return children;
  }

  Widget _buildSplitOverviewGridRow({
    required BuildContext context,
    required AppLocalizations l10n,
    required List<ProjectRow> projects,
    required List<ProjectRow> recent,
    required double recentCardWidth,
    required Object? gridEntranceKey,
    required bool showProjectsLoading,
    required double splitGridMaxHeight,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: StudioLayoutSpacing.section + 4),
      child: Row(
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
          const SizedBox(width: StudioSpacing.md),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ProjectsGridView(
                  projects: projects,
                  loading: widget.controller.loadingProjects,
                  listEntranceKey: gridEntranceKey,
                  demoTourAnchorId: ProductDemoTourAnchorIds.projectsGrid,
                  currentProjectNumericId: widget.currentProjectNumericId,
                  progressForProject: (p) => _progressByProjectId[p.id] ?? 0,
                  onSelectProject: widget.onSelectProjectScope,
                  onOpenProject: widget.onOpenProjectStudio,
                  pinnedProjectIds: _pinnedIds,
                  onTogglePin: _togglePinned,
                  contentWidth: constraints.maxWidth,
                  boundedMaxHeight: splitGridMaxHeight,
                );
              },
            ),
          ),
        ],
      ),
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
    this.isPinned = false,
    this.onTogglePin,
  });

  final ProjectRow project;
  final VoidCallback onTap;
  final int completedSteps;
  final bool selected;
  final bool compact;
  final bool isPinned;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);

    return Material(
      color: StudioPrimitives.transparent,
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
                  if (onTogglePin != null)
                    StudioIconButton(
                      label: isPinned
                          ? l10n.globalSearchUnpin
                          : l10n.globalSearchPinToSearchBar,
                      tooltip: isPinned
                          ? l10n.globalSearchUnpin
                          : l10n.globalSearchPinToSearchBar,
                      icon: isPinned ? Icons.star : Icons.star_border,
                      onPressed: onTogglePin,
                      size: compact ? 18 : 20,
                    ),
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: StudioSpacing.chromeActionGap,
                      ),
                      child: StudioIconSwap(
                        icon: Icons.check_circle,
                        size: compact ? 16 : 18,
                        color: tokens.primary,
                      ),
                    ),
                  StudioStepProgressRing(
                    completedSteps: completedSteps,
                    size: compact ? 28 : 32,
                    heroTag: studioHeroTagProjectProgress(project.numericId),
                  ),
                ],
              ),
              const Spacer(),
              StudioHero(
                tag: studioHeroTagProjectTitle(project.numericId),
                child: Text(
                  title,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: studioCardTitleStyle(context),
                ),
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
            Icon(Icons.touch_app_outlined, size: StudioIconSize.sm, color: tokens.primary),
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
