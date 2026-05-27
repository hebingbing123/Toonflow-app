import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/components/studio_empty_state.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_workbench_section.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/novels/support.dart';
import 'novel_inline_import_section.dart';
import '../project_editor/novels/workbench_section_builder.dart';
import '../project_editor/scripts/section_builder.dart';
import '../rust_api.dart';
import '../debug/project_studio_script_debug_preview.dart';
import '../settings/model_vendors/vendor_setup_nudge.dart';
import 'project_studio_focus_scope.dart';

/// Opens the full novel workbench dialog; panel supplies mutable [novelsRef].
typedef StudioScriptOpenNovelWorkbench =
    Future<void> Function(
      List<ListNovelsResponse?> novelsRef,
      List<bool> novelsBusy,
      Future<void> Function() reloadAssetsAndStats,
    );

typedef StudioScriptOpenScriptsWorkbench =
    Future<void> Function(
      List<ScriptBrief> scriptList,
      List<bool> saving,
      List<bool> scriptTaskBusy,
      List<String?> scriptTaskLine,
      List<ProjectStats?> statsRef,
      Future<void> Function() reloadScripts,
    );

typedef StudioScriptOpenPlanWorkbench = Future<void> Function();
typedef StudioScriptOpenBatchAddScripts = Future<void> Function();
typedef StudioScriptOpenScriptEditor =
    Future<void> Function(ScriptBrief script);

/// Breakpoints for script step split layout (web / desktop / tablet).
const double _kScriptSplitBreakpoint = 1040;
const double _kScriptStackBreakpoint = 720;

/// Script studio step: embedded novel/script intake (left or tab) + agent workspace.
class ProjectStudioScriptStepPanel extends StatefulWidget {
  const ProjectStudioScriptStepPanel({
    super.key,
    required this.accessToken,
    required this.project,
    required this.agentWorkspace,
    required this.onOpenNovelWorkbench,
    required this.onOpenScriptsWorkbench,
    required this.onOpenPlanWorkbench,
    required this.onOpenBatchAddScripts,
    required this.onOpenScriptEditor,
    this.onScriptSelected,
    this.onContentChanged,
    this.openNovelWorkbenchOnMount = false,
    this.focusMode = false,
    this.debugContentLoader,
  });

  final String accessToken;
  final ProjectRow project;
  final Widget agentWorkspace;
  final StudioScriptOpenNovelWorkbench onOpenNovelWorkbench;
  final StudioScriptOpenScriptsWorkbench onOpenScriptsWorkbench;
  final StudioScriptOpenPlanWorkbench onOpenPlanWorkbench;
  final StudioScriptOpenBatchAddScripts onOpenBatchAddScripts;
  final StudioScriptOpenScriptEditor onOpenScriptEditor;
  final ValueChanged<ScriptBrief>? onScriptSelected;
  final VoidCallback? onContentChanged;
  final bool openNovelWorkbenchOnMount;

  /// Hides the duplicate «小说与剧本» rail header; counts go to shell subtitle.
  final bool focusMode;

  /// Widget-test seam: skip novel/script HTTP when set.
  final ProjectStudioScriptStepContentLoader? debugContentLoader;

  @override
  State<ProjectStudioScriptStepPanel> createState() =>
      _ProjectStudioScriptStepPanelState();
}

class _ProjectStudioScriptStepPanelState
    extends State<ProjectStudioScriptStepPanel> {
  final List<ListNovelsResponse?> _novelsRef = <ListNovelsResponse?>[];
  final List<bool> _novelsLoading = <bool>[false];
  final List<bool> _novelsBusy = <bool>[false];
  final List<bool> _assetsBusy = <bool>[false];
  final List<bool> _assetsLoading = <bool>[false];
  final List<bool> _assetsScriptFilterLoading = <bool>[false];
  final List<ScriptBrief> _scriptList = <ScriptBrief>[];
  final List<bool> _saving = <bool>[false];
  final List<bool> _scriptTaskBusy = <bool>[false];
  final List<String?> _scriptTaskLine = <String?>[null];
  final List<ProjectStats?> _statsRef = <ProjectStats?>[null];

  bool _loading = true;
  String? _loadError;
  int? _selectedScriptId;
  bool _agentPaneOpen = false;

  @override
  void initState() {
    super.initState();
    _reloadContent();
    if (widget.openNovelWorkbenchOnMount) {
      _pendingNovelWorkbenchOpen = true;
    }
  }

  int get _novelCount => _novelsRef[0]?.items.length ?? 0;

  int get _scriptCount => _scriptList.length;

  Future<void> _reloadContent() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      if (widget.debugContentLoader != null) {
        final content = await widget.debugContentLoader!(
          widget.accessToken,
          widget.project.id,
        );
        if (!mounted) return;
        final scripts = content.scripts;
        setState(() {
          _novelsRef
            ..clear()
            ..add(content.novels);
          _scriptList
            ..clear()
            ..addAll(scripts);
          _statsRef[0] = content.stats;
          _loading = false;
          if (_selectedScriptId == null && scripts.isNotEmpty) {
            _selectedScriptId = scripts.first.numericId;
            widget.onScriptSelected?.call(scripts.first);
          }
        });
        widget.onContentChanged?.call();
        if (widget.focusMode) {
          ProjectStudioFocusScope.reportScriptContentCounts(
            context,
            novelCount: _novelCount,
            scriptCount: _scriptCount,
          );
        }
        await _maybeOpenPendingNovelWorkbench();
        return;
      }
      final novels = await fetchProjectNovelsByProjectId(
        widget.accessToken,
        widget.project.id,
      );
      final scriptRows = await postScriptsGetScriptApiByProjectId(
        widget.accessToken,
        widget.project.id,
      );
      ProjectStats? stats;
      try {
        stats = await fetchProjectStatsByProjectId(
          widget.accessToken,
          widget.project.id,
        );
      } catch (_) {
        stats = null;
      }
      if (!mounted) return;
      final scripts = scriptRows
          .map(
            (row) => ScriptBrief(
              numericId: row.numericId,
              name: row.name,
              extractState: row.extractState,
            ),
          )
          .toList(growable: false);
      setState(() {
        _novelsRef
          ..clear()
          ..add(novels);
        _scriptList
          ..clear()
          ..addAll(scripts);
        _statsRef[0] = stats;
        _loading = false;
        if (_selectedScriptId == null && scripts.isNotEmpty) {
          _selectedScriptId = scripts.first.numericId;
          widget.onScriptSelected?.call(scripts.first);
        }
      });
      widget.onContentChanged?.call();
      if (widget.focusMode) {
        ProjectStudioFocusScope.reportScriptContentCounts(
          context,
          novelCount: _novelCount,
          scriptCount: _scriptCount,
        );
      }
      await _maybeOpenPendingNovelWorkbench();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  Future<void> _reloadAssetsAndStats() => _reloadContent();

  Future<void> _generateTopNovelEvents() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await DomesticVendorSetupNudge.guardBeforeAiGenerate(
      context,
      accessToken: widget.accessToken,
    )) {
      return;
    }
    setState(() => _novelsBusy[0] = true);
    try {
      final ids = pickEventGeneratableNovelIds(
        _novelsRef[0]?.items ?? const <NovelRow>[],
        maxCount: 3,
      );
      if (ids.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.projectEditorNovelsEventsGenerateEmptyAdmitted,
              ),
            ),
          );
        }
        return;
      }
      final message = await postNovelEventsGenerateEvents(
        widget.accessToken,
        projectUuid: widget.project.id,
        novelIds: ids,
      );
      if (!mounted) return;
      await _reloadContent();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.projectEditorNovelsEventsGenerateTriggered(
              ids.join(', '),
              message,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeUserVisibleApiErrorResolved(context, e)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _novelsBusy[0] = false);
      }
    }
  }

  void _setPanelState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _createEmptyScript() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving[0] = true);
    try {
      final script = await createScriptUnderProject(
        widget.accessToken,
        widget.project.id,
      );
      if (!mounted) return;
      setState(() {
        _saving[0] = false;
        _scriptList.add(
          ScriptBrief(
            numericId: script.numericId,
            name: script.name,
            extractState: script.extractState,
          ),
        );
        _selectedScriptId = script.numericId;
      });
      widget.onScriptSelected?.call(_scriptList.last);
      widget.onContentChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.projectEditorScriptsWorkbenchCreatedScriptSnackBar(
              script.numericId,
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving[0] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeUserVisibleApiErrorResolved(context, e)),
          ),
        );
      }
    }
  }

  bool _pendingNovelWorkbenchOpen = false;

  Future<void> _maybeOpenPendingNovelWorkbench() async {
    if (!_pendingNovelWorkbenchOpen || _loading || !mounted) {
      return;
    }
    _pendingNovelWorkbenchOpen = false;
    await widget.onOpenNovelWorkbench(
      _novelsRef,
      _novelsBusy,
      _reloadAssetsAndStats,
    );
  }

  Widget _buildScriptsSection(BuildContext context, AppLocalizations l10n) {
    if (_scriptList.isEmpty) {
      return StudioEmptyState.firstUse(
        icon: Icons.description_outlined,
        title: l10n.studioScriptStepEmptyTitle,
        subtitle: l10n.studioScriptStepEmptyBody,
        actionLabel: l10n.projectEditorScriptsSectionCreateEmpty,
        onAction: _saving[0] ? null : _createEmptyScript,
        secondaryActionLabel: l10n.studioScriptNovelInlineOpenFullWorkbench,
        onSecondaryAction: () => widget.onOpenNovelWorkbench(
          _novelsRef,
          _novelsBusy,
          _reloadAssetsAndStats,
        ),
      );
    }
    return buildProjectScriptsSection(
      ctx: context,
      l10n: l10n,
      setDialogState: _setPanelState,
      token: widget.accessToken,
      project: widget.project,
      saving: _saving,
      scriptTaskBusy: _scriptTaskBusy,
      scriptTaskLine: _scriptTaskLine,
      scriptList: _scriptList,
      statsRef: _statsRef,
      openWorkbench: () => widget.onOpenScriptsWorkbench(
        _scriptList,
        _saving,
        _scriptTaskBusy,
        _scriptTaskLine,
        _statsRef,
        _reloadContent,
      ),
      openPlanWorkbench: widget.onOpenPlanWorkbench,
      openBatchAddDialog: widget.onOpenBatchAddScripts,
      openScriptEditor: (script) async {
        setState(() => _selectedScriptId = script.numericId);
        widget.onScriptSelected?.call(script);
        await widget.onOpenScriptEditor(script);
        if (mounted) await _reloadContent();
      },
    );
  }

  Widget _buildNovelTab(BuildContext context, AppLocalizations l10n) {
    final novels = _novelsRef[0]?.items ?? const <NovelRow>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioScriptNovelInlineImport(
            accessToken: widget.accessToken,
            project: widget.project,
            skipLiveResumeCheckpoint: widget.debugContentLoader != null,
            onReload: _reloadContent,
            onOpenFullWorkbench: () => widget.onOpenNovelWorkbench(
              _novelsRef,
              _novelsBusy,
              _reloadAssetsAndStats,
            ),
          ),
          if (novels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: StudioLayoutSpacing.stackMedium),
              child: StudioWorkbenchSection(
                title: l10n.studioScriptStepNovelsSectionTitle,
                subtitle: summarizeNovelRows(l10n, novels),
                child: buildProjectNovelsWorkbenchSection(
                  ctx: context,
                  l10n: l10n,
                  showTitle: false,
                  novels: novels,
                  novelsLoading: _novelsLoading,
                  novelsBusy: _novelsBusy,
                  assetsBusy: _assetsBusy,
                  assetsLoading: _assetsLoading,
                  assetsScriptFilterLoading: _assetsScriptFilterLoading,
                  openWorkbench: () => widget.onOpenNovelWorkbench(
                    _novelsRef,
                    _novelsBusy,
                    _reloadAssetsAndStats,
                  ),
                  refreshNovels: () async {
                    setState(() => _novelsLoading[0] = true);
                    try {
                      await _reloadAssetsAndStats();
                    } finally {
                      if (mounted) {
                        setState(() => _novelsLoading[0] = false);
                      }
                    }
                  },
                  generateEvents: _generateTopNovelEvents,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExtractTab(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.studioScriptStepTabExtract,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleSubtitle - 2),
          Text(
            l10n.studioScriptStepExtractBody,
            style: studioHintStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          _buildScriptsSection(context, l10n),
        ],
      ),
    );
  }

  Widget _buildContentTabBar(BuildContext context, AppLocalizations l10n) {
    final tabBar = TabBar(
      isScrollable: true,
      dividerColor: Colors.transparent,
      labelPadding: EdgeInsets.symmetric(
        horizontal: StudioLayoutSpacing.insetDense,
        vertical: widget.focusMode ? StudioLayoutSpacing.titleTight / 2 : 0,
      ),
      indicatorSize: TabBarIndicatorSize.label,
      tabAlignment: TabAlignment.start,
      tabs: <Tab>[
        Tab(text: l10n.studioScriptStepTabNovel),
        Tab(text: l10n.studioScriptStepTabScripts),
        Tab(text: l10n.studioScriptStepTabExtract),
      ],
    );
    if (!widget.focusMode) {
      return tabBar;
    }
    return Theme(
      data: Theme.of(context).copyWith(
        tabBarTheme: studioWorkbenchTabBarTheme(context),
      ),
      child: tabBar,
    );
  }

  Widget _buildContentRailHeader(BuildContext context, AppLocalizations l10n) {
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StudioLayoutSpacing.cardInner - 4,
        StudioLayoutSpacing.stackMedium,
        StudioLayoutSpacing.cardInner - 4,
        StudioLayoutSpacing.inlineGap,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.studioScriptIntakeNovels,
              style: studioControlLabelStyle(context),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                l10n.studioScriptStepContentCounts(_novelCount, _scriptCount),
                style: studioHintStyle(context)?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentRail(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
          child: StudioApiErrorCallout(
            error: _loadError!,
            onRetry: _reloadContent,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!widget.focusMode) _buildContentRailHeader(context, l10n),
          _buildContentTabBar(context, l10n),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _buildNovelTab(context, l10n),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(
                    StudioLayoutSpacing.cardInner - 4,
                  ),
                  child: _buildScriptsSection(context, l10n),
                ),
                _buildExtractTab(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentColumn(
    BuildContext context,
    AppLocalizations l10n, {
    VoidCallback? onClose,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            StudioLayoutSpacing.cardInner - 4,
            StudioLayoutSpacing.stackMedium,
            StudioLayoutSpacing.cardInner - 4,
            StudioLayoutSpacing.inlineGap,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: StudioPaneHeader(
                  showBack: false,
                  title: l10n.productAgentScriptWorkspaceTitle,
                  subtitle: l10n.productAgentScriptWorkspaceSubtitle,
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: l10n.studioScriptStepCloseAgent,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        Expanded(child: widget.agentWorkspace),
      ],
    );
  }

  Widget _buildOpenAgentFab(BuildContext context, AppLocalizations l10n) {
    final tokens = StudioTokens.of(context);
    return Material(
      elevation: 3,
      shadowColor: studioShadowColor(context, alpha: 0.25),
      borderRadius: BorderRadius.circular(StudioSpacing.md),
      color: tokens.bgSurface.withValues(alpha: 0.96),
      child: InkWell(
        onTap: () => setState(() => _agentPaneOpen = true),
        borderRadius: BorderRadius.circular(StudioSpacing.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.smart_toy_outlined, size: 20, color: tokens.primary),
              const SizedBox(width: 8),
              Text(
                l10n.studioScriptStepOpenAgent,
                style: studioControlLabelStyle(context)?.copyWith(
                  color: tokens.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitLayout(
    BuildContext context,
    BoxConstraints constraints, {
    required bool stackVertically,
  }) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rail = _buildContentRail(context);

    if (!_agentPaneOpen) {
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: rail),
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildOpenAgentFab(context, l10n),
          ),
        ],
      );
    }

    if (stackVertically) {
      const minAgentColumnHeight = 140.0;
      final maxTopHeight = math.max(
        120.0,
        constraints.maxHeight - minAgentColumnHeight,
      );
      final topHeight = (constraints.maxHeight * 0.46)
          .clamp(120.0, math.min(420.0, maxTopHeight))
          .toDouble();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: topHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.bgInset,
                border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
              ),
              child: rail,
            ),
          ),
          Expanded(
            child: _buildAgentColumn(
              context,
              l10n,
              onClose: () => setState(() => _agentPaneOpen = false),
            ),
          ),
        ],
      );
    }

    final railWidth = (constraints.maxWidth * 0.36).clamp(300.0, 420.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgInset,
              border: Border(right: BorderSide(color: tokens.borderSubtle)),
            ),
            child: rail,
          ),
        ),
        SizedBox(
          width: railWidth,
          child: _buildAgentColumn(
            context,
            l10n,
            onClose: () => setState(() => _agentPaneOpen = false),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowTabbedLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            dividerColor: Colors.transparent,
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: <Tab>[
              Tab(text: l10n.studioScriptStepTabContent),
              Tab(text: l10n.studioScriptStepTabAgent),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _buildContentRail(context),
                _buildAgentColumn(context, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kScriptSplitBreakpoint) {
          return _buildSplitLayout(context, constraints, stackVertically: false);
        }
        if (constraints.maxWidth >= _kScriptStackBreakpoint) {
          return _buildSplitLayout(context, constraints, stackVertically: true);
        }
        return _buildNarrowTabbedLayout(context);
      },
    );
  }
}
