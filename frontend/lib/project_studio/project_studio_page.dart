import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_icon_button.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/studio_responsive_layout.dart';
import '../design_system/components/studio_ellipsis_tooltip_text.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/ix/studio_conflict_banner.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'creator_journey_menu.dart';
import 'creator_journey_compact_bar.dart';
import 'creator_journey_strip.dart';
import 'creator_journey_telemetry.dart';
import 'project_studio_focus_scope.dart';
import 'project_studio_generic_step_setup.dart';
import 'project_studio_script_step_setup.dart';
import 'project_studio_host.dart';
import 'project_studio_model_routing_scope.dart';
import 'studio_step_model_routing_bar.dart';
import 'studio_agent_quick_bar.dart';
import 'studio_step.dart';
import 'project_studio_navigation.dart';
import 'studio_step_prefs.dart';
import 'studio_step_progress_ring.dart';

/// In-project six-step SOP with lazy [IndexedStack] step bodies.
class ProjectStudioPage extends StatefulWidget {
  const ProjectStudioPage({super.key, required this.host});

  final ProjectStudioHost host;

  @override
  State<ProjectStudioPage> createState() => _ProjectStudioPageState();
}

class _ProjectStudioPageState extends State<ProjectStudioPage> {
  late StudioStep _step = widget.host.initialStep;
  final Set<StudioStep> _visited = <StudioStep>{};
  final ProjectStudioFocusState _focusState = ProjectStudioFocusState();
  ProjectModelRoutingResponse? _modelRouting;
  StudioStep? _lastDispatchedHostStep;

  bool get _studioFocusMode => widget.host.studioFocusMode;

  /// Avoid duplicate [ProjectStudioHost.onStepChanged] when routes rebuild Studio
  /// (e.g. prefs restore fires again after `go` swaps the nested route widget).
  void _dispatchHostStepChanged(StudioStep step) {
    if (_lastDispatchedHostStep == step) return;
    _lastDispatchedHostStep = step;
    widget.host.onStepChanged(step);
  }

  void _markStepVisited(StudioStep step) {
    _visited.add(step);
    if (step == StudioStep.quality) {
      _visited.add(StudioStep.deliver);
    }
  }

  @override
  void initState() {
    super.initState();
    _markStepVisited(_step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _normalizeLegacyQualityRoute();
      _syncStepFromRouteIfNeeded();
      _restoreLastStep();
    });
    _loadModelRouting();
  }

  @override
  void didUpdateWidget(covariant ProjectStudioPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final routeStep = _routeRequestedStepOrNull();
    final incoming = routeStep ?? widget.host.initialStep;
    if (incoming == _step) {
      return;
    }
    setState(() {
      _step = incoming;
      _markStepVisited(incoming);
    });
    _dispatchHostStepChanged(incoming);
  }

  /// Keeps [_step] aligned with the browser URL when the nested studio route changes.
  void _syncStepFromRouteIfNeeded() {
    final routeStep = _routeRequestedStepOrNull();
    if (routeStep == null || routeStep == _step || !mounted) {
      return;
    }
    setState(() {
      _step = routeStep;
      _markStepVisited(routeStep);
    });
    _dispatchHostStepChanged(routeStep);
  }

  /// Canonical URL is `/deliver?tab=quality`; keep [StudioStep.quality] for body routing.
  void _normalizeLegacyQualityRoute() {
    if (GoRouter.maybeOf(context) == null) {
      return;
    }
    final state = GoRouterState.of(context);
    if (state.pathParameters['stepSlug'] != StudioStep.quality.slug) {
      return;
    }
    final canonical = _uriForStudioStep(StudioStep.quality);
    if (state.uri.path != canonical.path ||
        state.uri.queryParameters['tab'] != 'quality') {
      context.replace(canonical.toString());
    }
  }

  Future<void> _loadModelRouting() async {
    final token = widget.host.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final routing = await fetchProjectModelRoutingV1(
        token,
        widget.host.projectUuid,
      );
      if (!mounted) return;
      setState(() => _modelRouting = routing);
    } catch (_) {
      // Studio works without routing cache.
    }
  }

  Future<void> _restoreLastStep() async {
    final routeStep = _routeRequestedStepOrNull();
    if (routeStep != null) {
      // URL is source of truth when [stepSlug] is present (already synced in init).
      return;
    }
    final last = await StudioStepPrefs.loadLastStep(
      widget.host.projectNumericId,
    );
    if (!mounted || last == _step) return;
    setState(() {
      _step = last;
      _markStepVisited(last);
    });
    _dispatchHostStepChanged(last);
    _syncRouteToStep(last);
  }

  StudioStep? _routeRequestedStepOrNull() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return null;
    }
    final state = GoRouterState.of(context);
    final raw = state.pathParameters['stepSlug'];
    final slug = raw?.trim();
    if (slug == null || slug.isEmpty) {
      return null;
    }
    if (slug == 'deliver') {
      final tab = state.uri.queryParameters['tab']?.trim();
      if (tab == 'quality') {
        return StudioStep.quality;
      }
      return StudioStep.deliver;
    }
    for (final step in StudioStep.values) {
      if (step.slug == slug) {
        return step;
      }
    }
    return null;
  }

  Uri _uriForStudioStep(StudioStep step) {
    return projectStudioStepUri(widget.host.projectNumericId, step);
  }

  void _syncRouteToStep(StudioStep step) {
    if (GoRouter.maybeOf(context) == null) {
      return;
    }
    final expected = _uriForStudioStep(step);
    final current = GoRouterState.of(context).uri;
    if (!projectStudioStepUrisEquivalent(current, expected)) {
      context.go(expected.toString());
    }
  }

  void _selectStep(StudioStep step, {String? telemetrySource}) {
    CreatorJourneyTelemetry.record(
      CreatorJourneyEvent(
        'step_selected',
        <String, Object?>{
          'step': step.slug,
          'source': ?telemetrySource,
          'project_id': widget.host.projectNumericId,
        },
      ),
    );
    setState(() {
      _step = step;
      _markStepVisited(step);
    });
    StudioStepPrefs.saveLastStep(widget.host.projectNumericId, step);
    _dispatchHostStepChanged(step);
    if (GoRouter.maybeOf(context) != null) {
      context.go(_uriForStudioStep(step).toString());
    }
  }

  void _openReviewPack({required String source}) {
    CreatorJourneyTelemetry.record(
      CreatorJourneyEvent(
        'review_pack_open',
        <String, Object?>{
          'source': source,
          'project_id': widget.host.projectNumericId,
        },
      ),
    );
    context.go('/projects/${widget.host.projectNumericId}/review-pack');
  }

  void _handleWorkspaceMenuSelection(CreatorWorkspaceMenuTarget target) {
    if (target.isReviewPack) {
      _openReviewPack(source: 'workspace_menu');
      return;
    }
    _selectStep(target.step!, telemetrySource: 'workspace_menu');
  }

  void _handleProjectHomeAction(ProjectHomeAction action) {
    _executeLaunchIntent(_launchIntentForAction(action));
  }

  void _handleStarterTemplate(ProjectHomeStarterTemplate starter) {
    CreatorJourneyTelemetry.record(
      CreatorJourneyEvent(
        'starter_apply',
        <String, Object?>{
          'key': starter.key,
          'target_step': starter.targetStep,
          'project_id': widget.host.projectNumericId,
        },
      ),
    );
    _executeLaunchIntent(_starterLaunchIntent(starter));
  }

  void _executeLaunchIntent(_CockpitLaunchIntent intent) {
    if (intent.opensTasks && widget.host.onOpenTasks != null) {
      widget.host.onOpenTasks!();
      return;
    }
    final targetStep = intent.targetStep;
    if (targetStep != null && targetStep != _step) {
      _selectStep(targetStep, telemetrySource: 'deep_link');
    }
    final assetKind = intent.assetEditorKind;
    final onOpenAssetEditor = widget.host.onOpenAssetEditor;
    if (assetKind != null && onOpenAssetEditor != null) {
      if (_step != StudioStep.assets) {
        _selectStep(StudioStep.assets, telemetrySource: 'deep_link');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onOpenAssetEditor(
          ProjectStudioAssetEditorTarget(
            kind: assetKind,
            notice: intent.notice?.trim().isEmpty == true ? null : intent.notice,
          ),
        );
      });
      if (intent.agentKind == null) {
        final notice = intent.notice?.trim();
        if (notice != null && notice.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(notice)));
        }
        return;
      }
    }
    if (intent.agentKind != null) {
      widget.host.onRunHarnessAgent(intent.agentKind!);
    }
    final notice = intent.notice?.trim();
    if (notice != null && notice.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    }
  }

  ProjectHomeAction? _actionForMetric(
    ProjectHomeMetric metric,
    AppLocalizations l10n,
  ) {
    final key = metric.key.trim().toLowerCase();
    final combined = '${metric.label} ${metric.detail}'.toLowerCase();
    if (key.isEmpty && combined.trim().isEmpty) {
      return null;
    }
    final launch = _launchIntentForMetric(metric);
    if (launch == null) {
      return null;
    }
    final ctaLabel = launch.opensTasks
        ? l10n.projectStudioOpenTasks
        : launch.assetEditorKind != null
        ? l10n.projectStudioOpenAssetHub
        : launch.targetStep != null
        ? l10n.projectStudioOpenStep(
            projectStudioStepShortLabel(l10n, launch.targetStep!),
          )
        : null;
    if (ctaLabel == null) {
      return null;
    }
    return ProjectHomeAction(
      key: _metricActionKey(metric, launch),
      title: metric.label,
      detail: metric.detail,
      targetStep: launch.targetStep?.slug ?? 'tasks',
      ctaLabel: ctaLabel,
      launchIntent: metric.launchIntent,
    );
  }

  _CockpitLaunchIntent _launchIntentForAction(ProjectHomeAction action) {
    return _launchIntentFromModel(
          action.launchIntent,
          fallbackTargetStep: action.targetStep,
          fallbackNotice: action.detail,
        ) ??
        _launchIntentFromTargetStep(action.targetStep, notice: action.detail);
  }

  _CockpitLaunchIntent? _launchIntentForMetric(ProjectHomeMetric metric) {
    return _launchIntentFromModel(
      metric.launchIntent,
      fallbackNotice: metric.detail,
    );
  }

  String _metricActionKey(
    ProjectHomeMetric metric,
    _CockpitLaunchIntent launch,
  ) {
    final key = metric.key.trim().toLowerCase();
    if (key.isNotEmpty &&
        launch.assetEditorKind == null &&
        !launch.opensTasks) {
      return key;
    }
    return key.isEmpty ? 'open_${launch.targetStep?.slug ?? 'tasks'}' : key;
  }

  _CockpitLaunchIntent _starterLaunchIntent(
    ProjectHomeStarterTemplate starter,
  ) {
    return _launchIntentFromModel(
          starter.launchIntent,
          fallbackTargetStep: starter.targetStep,
          fallbackNotice: starter.detail,
        ) ??
        _launchIntentFromTargetStep(starter.targetStep, notice: starter.detail);
  }

  _CockpitLaunchIntent _launchIntentFromTargetStep(
    String? targetStep, {
    required String? notice,
  }) {
    return _CockpitLaunchIntent(
      targetStep: targetStep == null || targetStep == 'tasks'
          ? null
          : StudioStep.fromSlug(targetStep),
      opensTasks: targetStep == 'tasks',
      notice: notice,
    );
  }

  _CockpitLaunchIntent? _launchIntentFromModel(
    ProjectHomeLaunchIntent? intent, {
    String? fallbackTargetStep,
    String? fallbackNotice,
  }) {
    if (intent == null) {
      return null;
    }
    final action = (intent.action ?? '').trim().toLowerCase();
    final assetEditorKind = _assetEditorKindForIntentAsset(intent.assetTarget);
    final hasExplicitTaskAction =
        action == 'open_tasks' ||
        action == 'tasks' ||
        action == 'task_center' ||
        action == 'open_task_center';
    final targetStepSlug = (intent.targetStep ?? '').trim();
    final fallbackStepSlug =
        (targetStepSlug.isEmpty &&
            !hasExplicitTaskAction &&
            assetEditorKind == null)
        ? (fallbackTargetStep ?? '').trim()
        : '';
    final resolvedStepSlug = targetStepSlug.isNotEmpty
        ? targetStepSlug
        : fallbackStepSlug;
    final targetStep = resolvedStepSlug.isEmpty || resolvedStepSlug == 'tasks'
        ? null
        : StudioStep.fromSlug(resolvedStepSlug);
    final notice = (intent.notice ?? fallbackNotice)?.trim();
    return _CockpitLaunchIntent(
      targetStep: targetStep,
      agentKind: (intent.agentKind ?? '').trim().isEmpty
          ? null
          : intent.agentKind!.trim(),
      assetEditorKind: assetEditorKind,
      opensTasks: hasExplicitTaskAction || targetStepSlug == 'tasks',
      notice: notice?.isEmpty == true ? null : notice,
    );
  }

  ProjectStudioAssetEditorTargetKind? _assetEditorKindForIntentAsset(
    String? assetTarget,
  ) {
    final key = (assetTarget ?? '').trim().toLowerCase();
    return switch (key) {
      'overview' => ProjectStudioAssetEditorTargetKind.overview,
      'build_role_library' ||
      'build-role-library' ||
      'role_library' => ProjectStudioAssetEditorTargetKind.buildRoleLibrary,
      'define_project_characters' ||
      'define-project-characters' ||
      'project_characters' =>
        ProjectStudioAssetEditorTargetKind.defineProjectCharacters,
      'anchor_characters' || 'anchor-characters' =>
        ProjectStudioAssetEditorTargetKind.anchorCharacters,
      'confirm_candidates' ||
      'confirm-candidates' ||
      'candidates' => ProjectStudioAssetEditorTargetKind.confirmCandidates,
      'review_role_reuse' ||
      'review-role-reuse' ||
      'link_roles_to_scripts' ||
      'carry_roles_into_storyboard' =>
        ProjectStudioAssetEditorTargetKind.reviewRoleReuse,
      _ => null,
    };
  }

  ProjectStudioScriptStepSetupPanel? _buildScriptStepSetupPanel({
    required Set<StudioAgentAction> visibleAgentActions,
    bool sheetPresentation = false,
    bool includeModelRouting = false,
  }) {
    final token = widget.host.accessToken;
    final home = widget.host.home;
    if (token == null || token.isEmpty || home == null) {
      return null;
    }
    return ProjectStudioScriptStepSetupPanel(
      accessToken: token,
      projectUuid: widget.host.projectUuid,
      home: home,
      visibleAgentActions: visibleAgentActions,
      sheetPresentation: sheetPresentation,
      includeModelRouting: includeModelRouting,
      onOpenModelRoutingSettings: _openScriptModelRoutingSettings,
      onRoutingUpdated: (routing) {
        setState(() => _modelRouting = routing);
      },
      onOpenProjectSettings: widget.host.onOpenProjectSettings,
      onOpenGlobalModelVendorSettings: widget.host.onOpenGlobalModelVendorSettings,
      onRunHarnessAgent: widget.host.onRunHarnessAgent,
      onExecuteHomeAction: _handleProjectHomeAction,
      metricActionBuilder: (metric) =>
          _actionForMetric(metric, AppLocalizations.of(context)!),
      onExecuteStarter: _handleStarterTemplate,
    );
  }

  void _openScriptModelRoutingSettings() {
    final openVendors = widget.host.onOpenGlobalModelVendorSettings;
    if (openVendors != null) {
      openVendors();
      return;
    }
    widget.host.onOpenProjectSettings?.call();
  }

  Future<void> _openStepSetupSheet(
    Set<StudioAgentAction> visibleAgentActions,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (_step == StudioStep.script) {
      final panel = _buildScriptStepSetupPanel(
        visibleAgentActions: visibleAgentActions,
        sheetPresentation: true,
        includeModelRouting: false,
      );
      if (panel != null) {
        await showProjectStudioScriptStepSetupSheet(context, panel: panel);
        return;
      }
      _openScriptModelRoutingSettings();
      return;
    }

    final home = widget.host.home;
    if (home == null) {
      _openScriptModelRoutingSettings();
      return;
    }

    await showProjectStudioStepSetupSheet(
      context,
      title: l10n.studioStepPrepSheetTitle(_stepFocusLabel(l10n)),
      subtitle: l10n.studioStepPrepSheetSubtitle,
      body: ProjectStudioGenericStepSetupPanel(
        step: _step,
        home: home,
        visibleAgentActions: visibleAgentActions,
        onRunHarnessAgent: widget.host.onRunHarnessAgent,
        onExecuteHomeAction: _handleProjectHomeAction,
        metricActionBuilder: (metric) => _actionForMetric(metric, l10n),
        onExecuteStarter: _handleStarterTemplate,
        onOpenModelRoutingSettings: _openScriptModelRoutingSettings,
      ),
    );
  }

  String _stepFocusLabel(AppLocalizations l10n, {StudioStep? step}) {
    return projectStudioStepShortLabel(l10n, step ?? _step);
  }

  String _studioFocusSubtitle(AppLocalizations l10n) {
    switch (_step) {
      case StudioStep.script:
        final novels = _focusState.scriptNovelCount;
        final scripts = _focusState.scriptScriptCount;
        if (novels != null && scripts != null) {
          return l10n.studioScriptFocusModeSubtitleWithCounts(novels, scripts);
        }
        return l10n.studioScriptFocusModeSubtitle;
      case StudioStep.art:
        return l10n.studioArtFocusModeSubtitle;
      case StudioStep.assets:
        return l10n.studioAssetsFocusModeSubtitle;
      case StudioStep.storyboard:
        return l10n.studioStoryboardFocusModeSubtitle;
      case StudioStep.video:
        return l10n.studioVideoFocusModeSubtitle;
      case StudioStep.deliver:
      case StudioStep.quality:
        return l10n.studioDeliverFocusModeSubtitle;
    }
  }

  void _handleCreatorJourneyNext({required String telemetrySource}) {
    if (creatorJourneyCompactBarNextOpensReviewPack(_step)) {
      _openReviewPack(source: telemetrySource);
      return;
    }
    final nextStep = creatorJourneyCompactBarNextStep(_step);
    if (nextStep != null) {
      _selectStep(nextStep, telemetrySource: telemetrySource);
    }
  }

  Widget _buildCreatorNextFooter(AppLocalizations l10n) {
    final hasNext =
        creatorJourneyCompactBarNextStep(_step) != null ||
        creatorJourneyCompactBarNextOpensReviewPack(_step);
    final tokens = StudioTokens.of(context);
    final onNext = hasNext
        ? () => _handleCreatorJourneyNext(telemetrySource: 'next_cta')
        : null;
    // Deliver step: merge bar owns the emphasized CTA; footer stays compact.
    final Widget button = _step == StudioStep.deliver
        ? SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              style: studioToolbarTonalButtonStyle(context),
              onPressed: onNext,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.arrow_forward_rounded, size: StudioIconSize.xs),
                  SizedBox(width: StudioLayoutSpacing.microGap),
                  Text(l10n.studioCreatorJourneyNext),
                ],
              ),
            ),
          )
        : StudioPrimaryButton(
            icon: Icons.arrow_forward_rounded,
            label: l10n.studioCreatorJourneyNext,
            onPressed: onNext,
          );
    return Material(
      elevation: 4,
      shadowColor: studioShadowColor(context, alpha: 0.2),
      color: tokens.bgSurface.withValues(alpha: 0.96),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.radiusComfort, StudioSpacing.sm, StudioSpacing.radiusComfort),
          child: hasNext
              ? button
              : Tooltip(
                  message: l10n.studioCreatorJourneyNextDoneHint,
                  child: button,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final visibleAgentActions = agentActionsForStep(_step);
    final title =
        widget.host.projectName ??
        l10n.projectsUnnamedProject(widget.host.projectNumericId);
    final storyboardReadiness = widget.host.readiness;
    final topChrome = <Widget>[
      ListenableBuilder(
        listenable: _focusState,
        builder: (context, _) {
          return StudioPaneHeader(
            title: title,
            titleHeroTag: studioHeroTagProjectTitle(widget.host.projectNumericId),
            subtitle: _studioFocusMode
                ? _studioFocusSubtitle(l10n)
                : l10n.studioProjectStudioSubtitle,
            onBack: widget.host.onExit,
            titleStyle: studioProjectTitleStyle(context),
            trailing: _ProjectStudioHeaderTrailing(
              l10n: l10n,
              host: widget.host,
            ),
          );
        },
      ),
      if (widget.host.conflictMessage != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.xs, StudioSpacing.sm, 0),
          child: StudioConflictBanner(
            message: widget.host.conflictMessage!,
            onRefresh: widget.host.onRefreshAfterConflict ?? () {},
          ),
        ),
      if (widget.host.failedJobCount > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.xs, StudioSpacing.sm, 0),
          child: Semantics(
            button: true,
            label: '${l10n.studioFailedJobsHint} ${l10n.studioFailedJobsOpenTasks}',
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
              child: InkWell(
                borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
                onTap: () {
                  CreatorJourneyTelemetry.record(
                    CreatorJourneyEvent(
                      'failed_jobs_open_tasks',
                      <String, Object?>{
                        'failed_count': widget.host.failedJobCount,
                        'step': _step.slug,
                        'project_id': widget.host.projectNumericId,
                      },
                    ),
                  );
                  widget.host.onOpenTasks?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: StudioLayoutSpacing.inlineGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              l10n.studioFailedJobsHint,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: StudioSpacing.chromeActionGap),
                            Text(
                              l10n.studioFailedJobsOpenTasks,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: tokens.primary,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.radiusComfort, StudioSpacing.sm, 0),
        child: _studioFocusMode
            ? CreatorJourneyCompactBar(
                currentStep: _step,
                failedJobCount: widget.host.failedJobCount,
                onSelectStep: (StudioStep step) =>
                    _selectStep(step, telemetrySource: 'compact_bar'),
                onBackToProjects: widget.host.onExit,
                onWorkspaceMenuSelected: _handleWorkspaceMenuSelection,
                onOpenReviewPackMilestone: () =>
                    _openReviewPack(source: 'milestone'),
                onOpenStepSetup: widget.host.accessToken != null &&
                        widget.host.accessToken!.isNotEmpty
                    ? () => _openStepSetupSheet(visibleAgentActions)
                    : null,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CreatorJourneyStrip(
                    currentStep: _step,
                    failedJobCount: widget.host.failedJobCount,
                    onSelectMilestone: (StudioStep step) =>
                        _selectStep(step, telemetrySource: 'milestone'),
                    onBackToProjects: widget.host.onExit,
                    onOpenReviewPackMilestone: () =>
                        _openReviewPack(source: 'milestone'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<CreatorWorkspaceMenuTarget>(
                      tooltip: l10n.studioCreatorJourneyMoreStepsTooltip,
                      itemBuilder: (BuildContext context) =>
                          buildCreatorWorkspaceMenuEntries(context, l10n),
                      onSelected: _handleWorkspaceMenuSelection,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: StudioSpacing.chromeActionGap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.tune_rounded,
                              size: StudioIconSize.sm,
                              color: tokens.textSecondary.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: StudioSpacing.chromeActionGap),
                            Text(
                              l10n.studioCreatorJourneyMoreSteps,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      if (_step == StudioStep.assets && widget.host.assetsOverview != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.xs, StudioSpacing.sm, 0),
          child: _ProjectAssetHubCard(
            overview: widget.host.assetsOverview!,
            onSelectStep: _selectStep,
            onOpenTasks: widget.host.onOpenTasks,
            runningJobCount: widget.host.runningJobCount,
            onOpenAssetEditor: widget.host.onOpenAssetEditor,
            onRunHarnessAgent: widget.host.onRunHarnessAgent,
          ),
        ),
      if (_step == StudioStep.storyboard &&
          storyboardReadiness != null &&
          widget.host.onOpenAssetEditor != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.xs, StudioSpacing.sm, 0),
          child: _StoryboardAssetBridgeCard(
            readiness: storyboardReadiness,
            assetsOverview: widget.host.assetsOverview,
            onOpenAssetEditor: widget.host.onOpenAssetEditor!,
          ),
        ),
    ];

    return ProjectStudioFocusScope(
      state: _focusState,
      child: ProjectStudioModelRoutingScope(
        routing: _modelRouting,
        child: LayoutBuilder(
        builder: (context, constraints) {
          final topChromeMaxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight * 0.50
              : double.infinity;
          final topChromeWidget = _studioFocusMode
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: topChrome,
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: topChromeMaxHeight),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: topChrome,
                    ),
                  ),
                );
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  topChromeWidget,
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: _studioFocusMode ? 12 : 72,
                      ),
                      child: StudioIndexedPaneFade(
                        index: _step.sopStackIndex,
                        child: IndexedStack(
                        index: _step.sopStackIndex,
                        children: StudioStep.sopSteps
                            .map((step) {
                              if (!_visited.contains(step)) {
                                return const SizedBox.shrink();
                              }
                              final bodyStep =
                                  step == StudioStep.deliver &&
                                      _step == StudioStep.quality
                                  ? StudioStep.quality
                                  : step;
                              return KeyedSubtree(
                                key: ValueKey<String>(bodyStep.slug),
                                child: widget.host.buildStepBody(bodyStep),
                              );
                            })
                            .toList(growable: false),
                      ),
                        ),
                    ),
                  ),
                ],
              ),
              if (!_studioFocusMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildCreatorNextFooter(l10n),
                ),
            ],
          );
        },
      ),
      ),
    );
  }
}

class _ProjectAssetHubCard extends StatelessWidget {
  const _ProjectAssetHubCard({
    required this.overview,
    required this.onSelectStep,
    required this.onRunHarnessAgent,
    this.onOpenAssetEditor,
    this.onOpenTasks,
    this.runningJobCount = 0,
  });

  final ProjectAssetsOverview overview;
  final ValueChanged<StudioStep> onSelectStep;
  final Future<void> Function(String agentKind) onRunHarnessAgent;
  final ValueChanged<ProjectStudioAssetEditorTarget>? onOpenAssetEditor;
  final VoidCallback? onOpenTasks;
  final int runningJobCount;

  ProjectStudioAssetEditorTarget _buildEditorTargetForAssetTarget(
    AppLocalizations l10n,
    String assetTarget, {
    String? notice,
    int? preferredScriptNumericId,
    int? preferredAssetNumericId,
    int? preferredStoryboardNumericId,
  }) {
    return buildProjectStudioAssetEditorTarget(
      l10n: l10n,
      overview: overview,
      assetTarget: assetTarget,
      notice: notice,
      preferredScriptNumericId: preferredScriptNumericId,
      preferredAssetNumericId: preferredAssetNumericId,
      preferredStoryboardNumericId: preferredStoryboardNumericId,
    );
  }

  void _executeAssetHubIntent(
    AppLocalizations l10n, {
    ProjectHomeLaunchIntent? intent,
    String? fallbackTargetStep,
    String? fallbackNotice,
  }) {
    final action = (intent?.action ?? '').trim().toLowerCase();
    final assetTarget = (intent?.assetTarget ?? '').trim();
    final targetStepSlug = (intent?.targetStep ?? fallbackTargetStep ?? '')
        .trim();
    final notice = (intent?.notice ?? fallbackNotice)?.trim();

    final opensTasks =
        action == 'open_tasks' ||
        action == 'tasks' ||
        action == 'task_center' ||
        action == 'open_task_center' ||
        targetStepSlug == 'tasks';
    if (opensTasks && onOpenTasks != null) {
      onOpenTasks!();
      return;
    }
    if (targetStepSlug.isNotEmpty && targetStepSlug != 'tasks') {
      onSelectStep(StudioStep.fromSlug(targetStepSlug));
    } else if (assetTarget.isNotEmpty) {
      onSelectStep(StudioStep.assets);
    }
    final agentKind = (intent?.agentKind ?? '').trim();
    if (assetTarget.isNotEmpty && onOpenAssetEditor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onOpenAssetEditor!(
          _buildEditorTargetForAssetTarget(l10n, assetTarget, notice: notice),
        );
      });
    }
    if (agentKind.isNotEmpty) {
      onRunHarnessAgent(agentKind);
    }
  }

  void _executePrimaryAction(AppLocalizations l10n) {
    final action = overview.hub.primaryAction;
    _executeAssetHubIntent(
      l10n,
      intent: action.launchIntent,
      fallbackTargetStep: action.targetStep,
      fallbackNotice: action.detail,
    );
  }

  void _executeMetric(AppLocalizations l10n, AssetsOverviewHubMetric metric) {
    _executeAssetHubIntent(
      l10n,
      intent: metric.launchIntent,
      fallbackNotice: metric.detail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);
    final hub = overview.hub;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hub.headline,
            style: theme.textTheme.titleLarge?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            hub.subheadline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          StudioDenseActionRow(
            spacing: StudioSpacing.xs,
            children: <Widget>[
              FilledButton(
                style: studioFormPrimaryButtonStyle(context),
                onPressed: () => _executePrimaryAction(l10n),
                child: Text(hub.primaryAction.ctaLabel),
              ),
              if (onOpenAssetEditor != null)
                OutlinedButton(
                  style: studioFormSecondaryButtonStyle(context),
                  onPressed: () => onOpenAssetEditor!(
                    const ProjectStudioAssetEditorTarget(
                      kind: ProjectStudioAssetEditorTargetKind.overview,
                    ),
                  ),
                  child: Text(l10n.projectStudioOpenAssetEditor),
                ),
              if (onOpenTasks != null)
                OutlinedButton.icon(
                  style: studioFormOutlinedIconLabeledButtonStyle(context),
                  onPressed: onOpenTasks,
                  icon: Badge(
                    isLabelVisible: runningJobCount > 0,
                    label: Text('$runningJobCount'),
                    child: const Icon(Icons.pending_actions_outlined),
                  ),
                  label: Text(
                    runningJobCount > 0
                        ? l10n.projectStudioTasksRunning(runningJobCount)
                        : l10n.projectStudioTasks,
                  ),
                ),
              Text(
                hub.primaryAction.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
          if (hub.metrics.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudioSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: hub.metrics
                    .map(
                      (metric) => Padding(
                        padding: const EdgeInsets.only(
                          right: StudioSpacing.radiusComfort,
                        ),
                        child: _AssetsHubMetricCard(
                          metric: metric,
                          onTap: metric.launchIntent == null
                              ? null
                              : () => _executeMetric(l10n, metric),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (hub.characterSummaries.isNotEmpty ||
              hub.reusableRoleAssets.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudioSpacing.sm),
            LayoutBuilder(
              builder: (context, hubConstraints) {
                final hubCardWidth = studioClampedPaneWidth(
                  hubConstraints.maxWidth,
                  fraction: 0.46,
                  min: StudioLayoutSize.fieldStandard,
                  max: 420,
                );
                return Wrap(
              spacing: StudioSpacing.radiusComfort,
              runSpacing: StudioSpacing.radiusComfort,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: <Widget>[
                if (hub.characterSummaries.isNotEmpty)
                  _AssetHubListCard(
                    title: l10n.projectStudioAssetHubCharactersTitle,
                    width: hubCardWidth,
                    children: hub.characterSummaries
                        .map(
                          (character) => _AssetHubLine(
                            title: character.name,
                            subtitle:
                                character.assetName ??
                                (character.missingAssetAnchor
                                    ? l10n.projectStudioAssetHubMissingAnchor
                                    : l10n.projectStudioAssetHubAssetLinked),
                            meta: character.hasVoiceConfig
                                ? l10n.projectStudioAssetHubVoiceReady
                                : l10n.projectStudioAssetHubVoiceNotSet,
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (hub.reusableRoleAssets.isNotEmpty)
                  _AssetHubListCard(
                    title: l10n.projectStudioAssetHubReusableRolesTitle,
                    width: studioConstrainedDialogWidth(context, maxWidth: 420),
                    children: hub.reusableRoleAssets
                        .map(
                          (asset) => _AssetHubLine(
                            title: '#${asset.numericId} ${asset.name}',
                            subtitle: asset.linkedCharacterNames.isEmpty
                                ? l10n.projectStudioAssetHubNoCharacterLinked
                                : asset.linkedCharacterNames.join(', '),
                            meta: asset.linkedScriptNumericIds.isEmpty
                                ? l10n.projectStudioAssetHubNoScriptsLinked
                                : l10n.projectStudioAssetHubScriptsLinked(
                                    asset.linkedScriptNumericIds.join(', '),
                                  ),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            );
              },
            ),
          ],
        ],
      ),
    );
  }
}

ProjectStudioAssetEditorTarget buildProjectStudioAssetEditorTarget({
  required AppLocalizations l10n,
  required ProjectAssetsOverview overview,
  required String assetTarget,
  String? notice,
  int? preferredScriptNumericId,
  int? preferredAssetNumericId,
  int? preferredStoryboardNumericId,
}) {
  int? firstScriptNumericId(List<int> ids) {
    if (ids.isEmpty) {
      return null;
    }
    return ids.first;
  }

  final hub = overview.hub;
  final firstCharacter = hub.characterSummaries.isEmpty
      ? null
      : hub.characterSummaries.first;
  final firstRole = hub.reusableRoleAssets.isEmpty
      ? null
      : hub.reusableRoleAssets.first;
  AssetsOverviewItem? firstCandidateAssetItem(String status) {
    for (final group in overview.byAssetType) {
      for (final item in group.items) {
        if (item.candidateStatus == status) {
          return item;
        }
      }
    }
    return null;
  }

  final firstPendingCandidate = firstCandidateAssetItem('pending');
  switch (assetTarget.trim().toLowerCase()) {
    case 'build_role_library':
      return ProjectStudioAssetEditorTarget(
        kind: ProjectStudioAssetEditorTargetKind.buildRoleLibrary,
        preferredScriptNumericId: preferredScriptNumericId,
        preferredAssetNumericId: preferredAssetNumericId,
        preferredStoryboardNumericId: preferredStoryboardNumericId,
        notice: notice ?? l10n.projectStudioNoticeBuildRoleLibrary,
      );
    case 'define_project_characters':
      return ProjectStudioAssetEditorTarget(
        kind: ProjectStudioAssetEditorTargetKind.defineProjectCharacters,
        preferredScriptNumericId:
            preferredScriptNumericId ??
            (firstCharacter == null
                ? null
                : firstScriptNumericId(firstCharacter.linkedScriptNumericIds)),
        preferredAssetNumericId: preferredAssetNumericId,
        preferredStoryboardNumericId: preferredStoryboardNumericId,
        notice: notice ?? l10n.projectStudioNoticeDefineCharacters,
      );
    case 'anchor_characters':
      return ProjectStudioAssetEditorTarget(
        kind: ProjectStudioAssetEditorTargetKind.anchorCharacters,
        preferredScriptNumericId:
            preferredScriptNumericId ??
            (firstCharacter == null
                ? null
                : firstScriptNumericId(firstCharacter.linkedScriptNumericIds)),
        preferredAssetNumericId: preferredAssetNumericId,
        preferredStoryboardNumericId: preferredStoryboardNumericId,
        notice: notice ?? l10n.projectStudioNoticeAnchorCharacters,
      );
    case 'confirm_candidates':
      return ProjectStudioAssetEditorTarget(
        kind: ProjectStudioAssetEditorTargetKind.confirmCandidates,
        preferredAssetNumericId:
            preferredAssetNumericId ?? firstPendingCandidate?.numericId,
        preferredScriptNumericId:
            preferredScriptNumericId ??
            (firstCharacter != null
                ? firstScriptNumericId(firstCharacter.linkedScriptNumericIds)
                : firstScriptNumericId(
                    firstPendingCandidate?.linkedScriptNumericIds ??
                        const <int>[],
                  )),
        preferredStoryboardNumericId: preferredStoryboardNumericId,
        notice: notice ?? l10n.projectStudioNoticeConfirmCandidates,
      );
    case 'link_roles_to_scripts':
    case 'carry_roles_into_storyboard':
      return ProjectStudioAssetEditorTarget(
        kind: ProjectStudioAssetEditorTargetKind.reviewRoleReuse,
        preferredAssetNumericId:
            preferredAssetNumericId ?? firstRole?.numericId,
        preferredScriptNumericId:
            preferredScriptNumericId ??
            (firstRole == null
                ? null
                : firstScriptNumericId(firstRole.linkedScriptNumericIds)),
        preferredStoryboardNumericId: preferredStoryboardNumericId,
        notice: notice ?? l10n.projectStudioNoticeReviewRoleReuse,
      );
    default:
      return ProjectStudioAssetEditorTarget(
        kind: ProjectStudioAssetEditorTargetKind.overview,
        preferredScriptNumericId: preferredScriptNumericId,
        preferredAssetNumericId: preferredAssetNumericId,
        preferredStoryboardNumericId: preferredStoryboardNumericId,
        notice: notice,
      );
  }
}

class _StoryboardAssetBridgeCard extends StatelessWidget {
  const _StoryboardAssetBridgeCard({
    required this.readiness,
    required this.onOpenAssetEditor,
    this.assetsOverview,
  });

  final ProjectShortVideoReadiness readiness;
  final ProjectAssetsOverview? assetsOverview;
  final ValueChanged<ProjectStudioAssetEditorTarget> onOpenAssetEditor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pendingCandidates = readiness.storyboards
        .where((row) => row.blockingReasons.contains('candidate_pending'))
        .toList(growable: false);
    final missingAnchors =
        assetsOverview?.hub.characterSummaries
            .where((row) => row.missingAssetAnchor)
            .toList(growable: false) ??
        const <AssetsOverviewCharacterSummary>[];
    if (pendingCandidates.isEmpty && missingAnchors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.projectStudioStoryboardBlockersTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.projectStudioStoryboardBlockersSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          if (pendingCandidates.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            Text(
              l10n.projectStudioPendingCandidateReviewTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            ...pendingCandidates
                .take(4)
                .map(
                  (row) => _StoryboardAssetBridgeLine(
                    title: l10n.projectStudioStoryboardRowTitle(
                      row.storyboardNumericId,
                      row.sbIndex == null
                          ? ''
                          : l10n.projectStudioStoryboardShotSuffix(
                              row.sbIndex!,
                            ),
                    ),
                    detail: row.scriptNumericId == null
                        ? l10n.projectStudioStoryboardPendingBlocks
                        : l10n.projectStudioScriptPendingCandidates(
                            row.scriptNumericId!,
                          ),
                    ctaLabel: l10n.projectStudioReviewCandidatesCta,
                    onTap: assetsOverview == null
                        ? null
                        : () => onOpenAssetEditor(
                            buildProjectStudioAssetEditorTarget(
                              l10n: l10n,
                              overview: assetsOverview!,
                              assetTarget: 'confirm_candidates',
                              preferredScriptNumericId: row.scriptNumericId,
                              preferredStoryboardNumericId:
                                  row.storyboardNumericId,
                              notice: l10n.projectStudioStoryboardBlockedNotice(
                                row.storyboardNumericId,
                              ),
                            ),
                          ),
                  ),
                ),
          ],
          if (missingAnchors.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            Text(
              l10n.projectStudioMissingAnchorsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            ...missingAnchors
                .take(3)
                .map(
                  (character) => _StoryboardAssetBridgeLine(
                    title: character.name,
                    detail: character.linkedScriptNumericIds.isEmpty
                        ? l10n.projectStudioCharacterNeedsAnchor
                        : l10n.projectStudioScriptsDependOnAnchor(
                            character.linkedScriptNumericIds.join(', '),
                          ),
                    ctaLabel: l10n.projectStudioFixAnchorsCta,
                    onTap: assetsOverview == null
                        ? null
                        : () => onOpenAssetEditor(
                            buildProjectStudioAssetEditorTarget(
                              l10n: l10n,
                              overview: assetsOverview!,
                              assetTarget: 'anchor_characters',
                              preferredScriptNumericId:
                                  character.linkedScriptNumericIds.isEmpty
                                  ? null
                                  : character.linkedScriptNumericIds.first,
                              notice: l10n.projectStudioCharacterAnchorNotice(
                                character.name,
                              ),
                            ),
                          ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _StoryboardAssetBridgeLine extends StatelessWidget {
  const _StoryboardAssetBridgeLine({
    required this.title,
    required this.detail,
    required this.ctaLabel,
    this.onTap,
  });

  final String title;
  final String detail;
  final String ctaLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: StudioSpacing.chromeActionGap),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: StudioSpacing.radiusComfort),
          TextButton(onPressed: onTap, child: Text(ctaLabel)),
        ],
      ),
    );
  }
}

class _AssetHubListCard extends StatelessWidget {
  const _AssetHubListCard({
    required this.title,
    required this.children,
    required this.width,
  });

  final String title;
  final List<Widget> children;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AssetHubLine extends StatelessWidget {
  const _AssetHubLine({
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final String title;
  final String subtitle;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: StudioSpacing.radiusHairline),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: StudioSpacing.radiusHairline),
          Text(
            meta,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetsHubMetricCard extends StatelessWidget {
  const _AssetsHubMetricCard({
    required this.metric,
    this.onTap,
  });

  static const double _cardWidth = 320;

  final AssetsOverviewHubMetric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: tokens.textSecondary,
    );
    final valueStyle = theme.textTheme.titleLarge?.copyWith(
      color: tokens.textPrimary,
      fontWeight: FontWeight.w700,
    );
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: tokens.textSecondary,
    );
    final card = Container(
      width: _cardWidth,
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioEllipsisTooltipText(text: metric.label, style: labelStyle),
          const SizedBox(height: StudioSpacing.xs),
          StudioEllipsisTooltipText(text: metric.value, style: valueStyle),
          const SizedBox(height: StudioSpacing.xs),
          StudioEllipsisTooltipText(text: metric.detail, style: detailStyle),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return Semantics(
      button: true,
      label: metric.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Header actions; shrinks to icons when the pane header row is narrow.
class _ProjectStudioHeaderTrailing extends StatelessWidget {
  const _ProjectStudioHeaderTrailing({
    required this.l10n,
    required this.host,
  });

  final AppLocalizations l10n;
  final ProjectStudioHost host;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            !constraints.maxWidth.isFinite ||
            constraints.maxWidth < kStudioCompactHeaderMinWidth;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StudioStepProgressRing(
              completedSteps: host.completedSteps,
              heroTag: studioHeroTagProjectProgress(host.projectNumericId),
            ),
            if (host.runningJobCount > 0)
              compact
                  ? Badge(
                      label: Text('${host.runningJobCount}'),
                      child: StudioIconButton(
                        icon: Icons.pending_actions_outlined,
                        label:
                            '${l10n.projectStudioOpenTasks} (${host.runningJobCount})',
                        onPressed: host.onOpenTasks,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(
                        left: StudioSpacing.chromeActionGap,
                      ),
                      child: TextButton.icon(
                        onPressed: host.onOpenTasks,
                        icon: const Icon(Icons.pending_actions_outlined, size: StudioIconSize.sm),
                        label: Text('${host.runningJobCount}'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.standard,
                        ),
                      ),
                    ),
            StudioIconButton(
              icon: Icons.smart_toy_outlined,
              label: l10n.studioAgentDrawerTitle,
              onPressed: host.onOpenAgentDrawer,
            ),
            compact
                ? StudioIconButton(
                    icon: Icons.terminal_outlined,
                    label: l10n.studioOpenEpisodeConsole,
                    onPressed: () => context.push(
                      '/projects/${host.projectNumericId}/console/1',
                    ),
                  )
                : TextButton(
                    onPressed: () => context.push(
                      '/projects/${host.projectNumericId}/console/1',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.standard,
                    ),
                    child: Text(
                      l10n.studioOpenEpisodeConsole,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _CockpitLaunchIntent {
  const _CockpitLaunchIntent({
    this.targetStep,
    this.agentKind,
    this.assetEditorKind,
    this.opensTasks = false,
    this.notice,
  });

  final StudioStep? targetStep;
  final String? agentKind;
  final ProjectStudioAssetEditorTargetKind? assetEditorKind;
  final bool opensTasks;
  final String? notice;
}
