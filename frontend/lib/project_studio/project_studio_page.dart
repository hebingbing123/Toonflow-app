import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/ix/studio_conflict_banner.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'project_studio_host.dart';
import 'studio_agent_quick_bar.dart';
import 'studio_step.dart';
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

  @override
  void initState() {
    super.initState();
    _visited.add(_step);
    _restoreLastStep();
  }

  Future<void> _restoreLastStep() async {
    final last = await StudioStepPrefs.loadLastStep(
      widget.host.projectNumericId,
    );
    if (!mounted) return;
    setState(() {
      _step = last;
      _visited.add(last);
    });
    widget.host.onStepChanged(last);
  }

  void _selectStep(StudioStep step) {
    setState(() {
      _step = step;
      _visited.add(step);
    });
    StudioStepPrefs.saveLastStep(widget.host.projectNumericId, step);
    widget.host.onStepChanged(step);
    context.go('/projects/${widget.host.projectNumericId}/${step.slug}');
  }

  void _handleProjectHomeAction(ProjectHomeAction action) {
    _executeLaunchIntent(_launchIntentForAction(action));
  }

  void _handleStarterTemplate(ProjectHomeStarterTemplate starter) {
    _executeLaunchIntent(_starterLaunchIntent(starter));
  }

  void _executeLaunchIntent(_CockpitLaunchIntent intent) {
    if (intent.opensTasks && widget.host.onOpenTasks != null) {
      widget.host.onOpenTasks!();
      return;
    }
    final assetKind = intent.assetEditorKind;
    final onOpenAssetEditor = widget.host.onOpenAssetEditor;
    if (assetKind != null && onOpenAssetEditor != null) {
      onOpenAssetEditor(
        ProjectStudioAssetEditorTarget(
          kind: assetKind,
          notice: intent.notice?.trim().isEmpty == true ? null : intent.notice,
        ),
      );
      return;
    }
    final targetStep = intent.targetStep;
    if (targetStep != null && targetStep != _step) {
      _selectStep(targetStep);
    }
    if (intent.agentKind != null) {
      widget.host.onRunHarnessAgent(intent.agentKind!);
    }
  }

  ProjectHomeAction? _actionForMetric(ProjectHomeMetric metric) {
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
        ? 'Open tasks'
        : launch.assetEditorKind != null
        ? 'Open asset hub'
        : launch.targetStep != null
        ? 'Open ${launch.targetStep!.slug}'
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title =
        widget.host.projectName ??
        l10n.projectsUnnamedProject(widget.host.projectNumericId);
    final storyboardReadiness = widget.host.readiness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneHeader(
          title: title,
          subtitle: l10n.studioProjectStudioSubtitle,
          onBack: widget.host.onExit,
          titleStyle: studioProjectTitleStyle(context),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              StudioStepProgressRing(
                completedSteps: widget.host.completedSteps,
              ),
              if (widget.host.runningJobCount > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: TextButton.icon(
                    onPressed: widget.host.onOpenTasks,
                    icon: const Icon(Icons.pending_actions_outlined, size: 18),
                    label: Text('${widget.host.runningJobCount}'),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.studioAgentDrawerTitle,
                onPressed: widget.host.onOpenAgentDrawer,
                icon: const Icon(Icons.smart_toy_outlined),
              ),
              TextButton(
                onPressed: () => context.push(
                  '/projects/${widget.host.projectNumericId}/console/1',
                ),
                child: Text(l10n.studioOpenEpisodeConsole),
              ),
            ],
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (widget.host.conflictMessage != null)
                  StudioConflictBanner(
                    message: widget.host.conflictMessage!,
                    onRefresh: widget.host.onRefreshAfterConflict ?? () {},
                  ),
                if (widget.host.home != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _ProjectCockpitCard(
                    home: widget.host.home!,
                    onSelectStep: _selectStep,
                    onExecuteAction: _handleProjectHomeAction,
                    metricActionBuilder: _actionForMetric,
                    onExecuteStarter: _handleStarterTemplate,
                  ),
                ],
                if (_step == StudioStep.assets &&
                    widget.host.assetsOverview != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _ProjectAssetHubCard(
                    overview: widget.host.assetsOverview!,
                    onSelectStep: _selectStep,
                    onOpenTasks: widget.host.onOpenTasks,
                    runningJobCount: widget.host.runningJobCount,
                    onOpenAssetEditor: widget.host.onOpenAssetEditor,
                    onRunHarnessAgent: widget.host.onRunHarnessAgent,
                  ),
                ],
                if (_step == StudioStep.storyboard &&
                    storyboardReadiness != null &&
                    widget.host.onOpenAssetEditor != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _StoryboardAssetBridgeCard(
                    readiness: storyboardReadiness,
                    assetsOverview: widget.host.assetsOverview,
                    onOpenAssetEditor: widget.host.onOpenAssetEditor!,
                  ),
                ],
                const SizedBox(height: 12),
                _StudioStepBar(current: _step, onSelect: _selectStep),
                const SizedBox(height: 12),
                StudioAgentQuickBar(
                  visibleActions: agentActionsForStep(_step),
                  onRewriteScript: () =>
                      widget.host.onRunHarnessAgent('script_rewriter'),
                  onExtractEntities: () =>
                      widget.host.onRunHarnessAgent('extractor'),
                  onBreakStoryboard: () =>
                      widget.host.onRunHarnessAgent('storyboard_breaker'),
                  onAssignVoices: () =>
                      widget.host.onRunHarnessAgent('voice_assigner'),
                  onGridPrompts: () =>
                      widget.host.onRunHarnessAgent('grid_prompt_generator'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: StudioStep.sopSteps.indexOf(_step),
            children: StudioStep.sopSteps
                .map((step) {
                  if (!_visited.contains(step)) {
                    return const SizedBox.shrink();
                  }
                  return KeyedSubtree(
                    key: ValueKey<String>(step.slug),
                    child: widget.host.buildStepBody(step),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
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
    String assetTarget, {
    String? notice,
    int? preferredScriptNumericId,
    int? preferredAssetNumericId,
    int? preferredStoryboardNumericId,
  }) {
    return buildProjectStudioAssetEditorTarget(
      overview: overview,
      assetTarget: assetTarget,
      notice: notice,
      preferredScriptNumericId: preferredScriptNumericId,
      preferredAssetNumericId: preferredAssetNumericId,
      preferredStoryboardNumericId: preferredStoryboardNumericId,
    );
  }

  void _executeAssetHubIntent({
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
    if (assetTarget.isNotEmpty && onOpenAssetEditor != null) {
      onOpenAssetEditor!(
        _buildEditorTargetForAssetTarget(assetTarget, notice: notice),
      );
      return;
    }
    if (targetStepSlug.isNotEmpty && targetStepSlug != 'tasks') {
      onSelectStep(StudioStep.fromSlug(targetStepSlug));
    }
    final agentKind = (intent?.agentKind ?? '').trim();
    if (agentKind.isNotEmpty) {
      onRunHarnessAgent(agentKind);
    }
  }

  void _executePrimaryAction() {
    final action = overview.hub.primaryAction;
    _executeAssetHubIntent(
      intent: action.launchIntent,
      fallbackTargetStep: action.targetStep,
      fallbackNotice: action.detail,
    );
  }

  void _executeMetric(AssetsOverviewHubMetric metric) {
    _executeAssetHubIntent(
      intent: metric.launchIntent,
      fallbackNotice: metric.detail,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final hub = overview.hub;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hub.headline,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hub.subheadline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              FilledButton(
                onPressed: _executePrimaryAction,
                child: Text(hub.primaryAction.ctaLabel),
              ),
              if (onOpenAssetEditor != null)
                OutlinedButton(
                  onPressed: () => onOpenAssetEditor!(
                    const ProjectStudioAssetEditorTarget(
                      kind: ProjectStudioAssetEditorTargetKind.overview,
                    ),
                  ),
                  child: const Text('Open asset editor'),
                ),
              if (onOpenTasks != null)
                OutlinedButton.icon(
                  onPressed: onOpenTasks,
                  icon: Badge(
                    isLabelVisible: runningJobCount > 0,
                    label: Text('$runningJobCount'),
                    child: const Icon(Icons.pending_actions_outlined),
                  ),
                  label: Text(
                    runningJobCount > 0
                        ? 'Tasks ($runningJobCount)'
                        : 'Tasks',
                  ),
                ),
              Text(
                hub.primaryAction.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (hub.metrics.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: hub.metrics
                  .map(
                    (metric) => _AssetsHubMetricCard(
                      metric: metric,
                      onTap: metric.launchIntent == null
                          ? null
                          : () => _executeMetric(metric),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (hub.characterSummaries.isNotEmpty ||
              hub.reusableRoleAssets.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: <Widget>[
                if (hub.characterSummaries.isNotEmpty)
                  _AssetHubListCard(
                    title: 'Project characters',
                    width: 360,
                    children: hub.characterSummaries
                        .map(
                          (character) => _AssetHubLine(
                            title: character.name,
                            subtitle:
                                character.assetName ??
                                (character.missingAssetAnchor
                                    ? 'Missing asset anchor'
                                    : 'Asset linked'),
                            meta: character.hasVoiceConfig
                                ? 'Voice ready'
                                : 'Voice not set',
                          ),
                        )
                        .toList(growable: false),
                  ),
                if (hub.reusableRoleAssets.isNotEmpty)
                  _AssetHubListCard(
                    title: 'Reusable role assets',
                    width: 420,
                    children: hub.reusableRoleAssets
                        .map(
                          (asset) => _AssetHubLine(
                            title: '#${asset.numericId} ${asset.name}',
                            subtitle: asset.linkedCharacterNames.isEmpty
                                ? 'No character linked yet'
                                : asset.linkedCharacterNames.join(', '),
                            meta: asset.linkedScriptNumericIds.isEmpty
                                ? 'No scripts linked'
                                : 'Scripts ${asset.linkedScriptNumericIds.join(', ')}',
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

ProjectStudioAssetEditorTarget buildProjectStudioAssetEditorTarget({
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
        notice:
            notice ??
            'Focus on creating or importing role assets before moving deeper into storyboard work.',
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
        notice:
            notice ??
            'Role assets exist, but the project character sheet is still empty. Build the character roster from the asset library.',
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
        notice:
            notice ??
            'Start by reviewing role assets for the scripts that still have characters without asset anchors.',
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
        notice:
            notice ??
            'Candidate assets are still pending. Review the pending rows and confirm the ones that belong in the role library.',
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
        notice:
            notice ??
            'Review role reuse and script linkage so the same cast assets stay consistent across scenes.',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Storyboard asset blockers',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Close asset-binding gaps here before moving back into generation.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (pendingCandidates.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Pending candidate review',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...pendingCandidates
                .take(4)
                .map(
                  (row) => _StoryboardAssetBridgeLine(
                    title:
                        'Storyboard #${row.storyboardNumericId}${row.sbIndex == null ? '' : ' · Shot ${row.sbIndex}'}',
                    detail: row.scriptNumericId == null
                        ? 'Pending candidate assets still block this storyboard.'
                        : 'Script #${row.scriptNumericId} still has candidate assets waiting for confirmation.',
                    ctaLabel: 'Review candidates',
                    onTap: assetsOverview == null
                        ? null
                        : () => onOpenAssetEditor(
                            buildProjectStudioAssetEditorTarget(
                              overview: assetsOverview!,
                              assetTarget: 'confirm_candidates',
                              preferredScriptNumericId: row.scriptNumericId,
                              preferredStoryboardNumericId:
                                  row.storyboardNumericId,
                              notice:
                                  'Storyboard #${row.storyboardNumericId} is still blocked by pending candidate assets. Confirm the right role before generating this shot.',
                            ),
                          ),
                  ),
                ),
          ],
          if (missingAnchors.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Missing character anchors',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ...missingAnchors
                .take(3)
                .map(
                  (character) => _StoryboardAssetBridgeLine(
                    title: character.name,
                    detail: character.linkedScriptNumericIds.isEmpty
                        ? 'This project character still needs an asset anchor.'
                        : 'Scripts ${character.linkedScriptNumericIds.join(', ')} still depend on this character anchor.',
                    ctaLabel: 'Fix anchors',
                    onTap: assetsOverview == null
                        ? null
                        : () => onOpenAssetEditor(
                            buildProjectStudioAssetEditorTarget(
                              overview: assetsOverview!,
                              assetTarget: 'anchor_characters',
                              preferredScriptNumericId:
                                  character.linkedScriptNumericIds.isEmpty
                                  ? null
                                  : character.linkedScriptNumericIds.first,
                              notice:
                                  'Character "${character.name}" still needs an asset anchor before storyboard work can stay consistent.',
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(12),
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
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: onTap, child: Text(ctaLabel)),
        ],
      ),
    );
  }
}

class _ProjectCockpitCard extends StatelessWidget {
  const _ProjectCockpitCard({
    required this.home,
    required this.onSelectStep,
    required this.onExecuteAction,
    required this.metricActionBuilder,
    required this.onExecuteStarter,
  });

  final ProjectHome home;
  final ValueChanged<StudioStep> onSelectStep;
  final ValueChanged<ProjectHomeAction> onExecuteAction;
  final ProjectHomeAction? Function(ProjectHomeMetric metric)
  metricActionBuilder;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final cockpit = home.cockpit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      cockpit.headline,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cockpit.subheadline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActionButtonRow(
                      primaryAction: cockpit.primaryAction,
                      secondaryActions: cockpit.secondaryActions,
                      onExecuteAction: onExecuteAction,
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cockpit.metrics
                      .map(
                        (metric) => _MetricCard(
                          metric: metric,
                          action: metricActionBuilder(metric),
                          onExecuteAction: onExecuteAction,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
          if (cockpit.starterTemplates.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cockpit.starterTemplates
                  .map(
                    (starter) => _StarterCard(
                      starter: starter,
                      onExecuteStarter: onExecuteStarter,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meta,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtonRow extends StatelessWidget {
  const _ActionButtonRow({
    required this.primaryAction,
    required this.secondaryActions,
    required this.onExecuteAction,
  });

  final ProjectHomeAction primaryAction;
  final List<ProjectHomeAction> secondaryActions;
  final ValueChanged<ProjectHomeAction> onExecuteAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = secondaryActions.take(2).toList(growable: false);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton(
          onPressed: () => onExecuteAction(primaryAction),
          child: Text(primaryAction.ctaLabel),
        ),
        ...secondary.map(
          (action) => OutlinedButton(
            onPressed: () => onExecuteAction(action),
            child: Text(action.ctaLabel),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                primaryAction.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (primaryAction.detail.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  primaryAction.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.82,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, this.action, this.onExecuteAction});

  final ProjectHomeMetric metric;
  final ProjectHomeAction? action;
  final ValueChanged<ProjectHomeAction>? onExecuteAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metric.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              action!.ctaLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      width: 248,
      child: action == null || onExecuteAction == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onExecuteAction!(action!),
              child: card,
            ),
    );
  }
}

class _AssetsHubMetricCard extends StatelessWidget {
  const _AssetsHubMetricCard({required this.metric, this.onTap});

  final AssetsOverviewHubMetric metric;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metric.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Open',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
    return SizedBox(
      width: 248,
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: card,
            ),
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({required this.starter, required this.onExecuteStarter});

  final ProjectHomeStarterTemplate starter;
  final ValueChanged<ProjectHomeStarterTemplate> onExecuteStarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    return SizedBox(
      width: 280,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              starter.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              starter.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => onExecuteStarter(starter),
              child: Text(starter.ctaLabel),
            ),
          ],
        ),
      ),
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

class _StudioStepBar extends StatelessWidget {
  const _StudioStepBar({required this.current, required this.onSelect});

  final StudioStep current;
  final ValueChanged<StudioStep> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final labels = <String>[
      l10n.studioStepScriptShort,
      l10n.studioStepArtShort,
      l10n.studioStepAssetsShort,
      l10n.studioStepStoryboardShort,
      l10n.studioStepVideoShort,
      l10n.studioStepDeliverShort,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(StudioStep.sopSteps.length, (i) {
          final step = StudioStep.sopSteps[i];
          final selected = step == current;
          return Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
            child: FilterChip(
              label: Text('${i + 1}. ${labels[i]}'),
              selected: selected,
              onSelected: (_) => onSelect(step),
              selectedColor: tokens.primary.withValues(alpha: 0.25),
              checkmarkColor: tokens.primary,
            ),
          );
        }),
      ),
    );
  }
}
