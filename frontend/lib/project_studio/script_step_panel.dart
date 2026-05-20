import 'package:flutter/material.dart';

import '../design_system/components/studio_empty_state.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_editor/novels/support.dart';
import 'novel_inline_import_section.dart';
import '../project_editor/novels/workbench_section_builder.dart';
import '../project_editor/scripts/section_builder.dart';
import '../rust_api.dart';

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

  @override
  void initState() {
    super.initState();
    _reloadContent();
    if (widget.openNovelWorkbenchOnMount) {
      _pendingNovelWorkbenchOpen = true;
    }
  }

  Future<void> _reloadContent() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioScriptNovelInlineImport(
            accessToken: widget.accessToken,
            project: widget.project,
            onReload: _reloadContent,
            onOpenFullWorkbench: () => widget.onOpenNovelWorkbench(
              _novelsRef,
              _novelsBusy,
              _reloadAssetsAndStats,
            ),
          ),
          if (novels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              l10n.studioScriptStepNovelsSectionTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            buildProjectNovelsWorkbenchSection(
              ctx: context,
              l10n: l10n,
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
          ],
        ],
      ),
    );
  }

  Widget _buildExtractTab(BuildContext context, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.studioScriptStepTabExtract,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.studioScriptStepExtractBody,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildScriptsSection(context, l10n),
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
      return StudioEmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.studioScriptStepLoadErrorTitle,
        subtitle: _loadError!,
        actionLabel: l10n.studioScriptStepRetry,
        onAction: _reloadContent,
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabs: <Tab>[
              Tab(text: l10n.studioScriptStepTabNovel),
              Tab(text: l10n.studioScriptStepTabScripts),
              Tab(text: l10n.studioScriptStepTabExtract),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _buildNovelTab(context, l10n),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 380,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.bgInset,
                    border: Border(
                      right: BorderSide(color: tokens.borderSubtle),
                    ),
                  ),
                  child: _buildContentRail(context),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(
                        l10n.productAgentScriptWorkspaceTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: widget.agentWorkspace),
                  ],
                ),
              ),
            ],
          );
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TabBar(
                tabs: <Tab>[
                  Tab(text: l10n.studioScriptStepTabContent),
                  Tab(text: l10n.studioScriptStepTabAgent),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _buildContentRail(context),
                    widget.agentWorkspace,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
