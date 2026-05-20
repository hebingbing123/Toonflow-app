part of '../../home_page.dart';

class _ScriptWorkbenchPanel extends StatefulWidget {
  const _ScriptWorkbenchPanel({
    required this.token,
    required this.projectId,
    required this.scriptNumericId,
    required this.onExtractStateSynced,
    required this.onOpenEditImageWorkbench,
  });

  final String token;
  final String projectId;
  final int scriptNumericId;
  final void Function(int? extractState) onExtractStateSynced;
  final Future<void> Function() onOpenEditImageWorkbench;

  @override
  State<_ScriptWorkbenchPanel> createState() => _ScriptWorkbenchPanelState();
}

class _ScriptWorkbenchPanelState extends State<_ScriptWorkbenchPanel> {
  bool _loadingContext = false;
  bool _runningAction = false;
  ScriptWorkbenchDetailRow? _scriptContext;
  ScriptExtractStatePollRow? _extractStateRow;
  String? _contextLine;
  String? _exportLine;
  String? _extractAssetsLine;
  String? _extractStateLine;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refreshWorkbench);
  }

  Future<void> _refreshContext() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _loadingContext = true;
      _contextLine = null;
    });
    try {
      final rows = await postScriptsGetScriptApiByProjectId(
        widget.token,
        widget.projectId,
      );
      final current = findScriptContextByNumericId(
        rows,
        widget.scriptNumericId,
      );
      if (!mounted) return;
      setState(() {
        _scriptContext = current;
        _contextLine = current == null
            ? l10n.projectEditorScriptsSingleWorkbenchContextNotInApi
            : l10n.projectEditorScriptsSingleWorkbenchContextLoaded(
                current.relatedAssets.length,
              );
      });
      widget.onExtractStateSynced(current?.extractState);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _contextLine = l10n.projectEditorScriptsSingleWorkbenchContextReadFailed(
          describeUserVisibleApiErrorResolved(context, e),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingContext = false);
      }
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _runningAction = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(describeUserVisibleApiErrorResolved(context, e))),
      );
    } finally {
      if (mounted) {
        setState(() => _runningAction = false);
      }
    }
  }

  Future<void> _exportCurrentScript() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final zip = await exportScriptsZip(widget.token, [widget.scriptNumericId]);
    final diagnosis = diagnoseScriptWorkbench(
      l10n,
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    if (!mounted) return;
    setState(
      () => _exportLine = buildScriptWorkbenchFollowUp(
        l10n,
        actionSummary: l10n.projectEditorScriptsSingleWorkbenchFollowUpExportDone(
          formatBinarySize(zip.length),
        ),
        diagnosis: diagnosis,
      ),
    );
  }

  Future<void> _pollExtractState() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final rows = await pollScriptExtractState(widget.token, [
      widget.scriptNumericId,
    ]);
    final current = findScriptExtractStateByNumericId(
      rows,
      widget.scriptNumericId,
    );
    if (!mounted) return;
    final diagnosis = diagnoseScriptWorkbench(
      l10n,
      scriptContext: _scriptContext,
      extractStateRow: current,
    );
    final stateLine = describeScriptExtractState(
      l10n,
      extractState: current?.extractState,
      errorReason: current?.errorReason,
    );
    setState(() {
      _extractStateRow = current;
      _extractStateLine = buildScriptWorkbenchFollowUp(
        l10n,
        actionSummary: l10n.projectEditorScriptsSingleWorkbenchFollowUpPollState(
          stateLine,
        ),
        diagnosis: diagnosis,
      );
    });
    widget.onExtractStateSynced(current?.extractState);
  }

  Future<void> _refreshWorkbench() async {
    await _refreshContext();
    if (!mounted) return;
    await _pollExtractState();
  }

  Future<void> _startExtractAssets() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final accepted = await startScriptAssetExtract(
      widget.token,
      projectUuid: widget.projectId,
      scriptNumericIds: [widget.scriptNumericId],
    );
    await _refreshWorkbench();
    if (!mounted) return;
    final diagnosis = diagnoseScriptWorkbench(
      l10n,
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    setState(() {
      _extractAssetsLine = buildScriptWorkbenchFollowUp(
        l10n,
        actionSummary:
            l10n.projectEditorScriptsSingleWorkbenchFollowUpExtractSubmitted(
              accepted.status,
              accepted.message,
            ),
        diagnosis: diagnosis,
      );
      _extractStateLine = describeScriptExtractState(
        l10n,
        extractState:
            _extractStateRow?.extractState ?? _scriptContext?.extractState,
        errorReason:
            _extractStateRow?.errorReason ?? _scriptContext?.errorReason,
      );
    });
  }

  Future<void> _openEditImageWorkbench() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    await widget.onOpenEditImageWorkbench();
    if (!mounted) return;
    await _refreshWorkbench();
    if (!mounted) return;
    final diagnosis = diagnoseScriptWorkbench(
      l10n,
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    setState(() {
      _contextLine = _scriptContext == null
          ? l10n.projectEditorScriptsSingleWorkbenchEditClosedStillMissing
          : buildScriptWorkbenchFollowUp(
              l10n,
              actionSummary:
                  l10n.projectEditorScriptsSingleWorkbenchFollowUpEditClosedSynced,
              diagnosis: diagnosis,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final relatedAssets = _scriptContext?.relatedAssets ?? const [];
    final errorReason = (_scriptContext?.errorReason ?? '').trim();
    final diagnosis = diagnoseScriptWorkbench(
      l10n,
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    VoidCallback? recommendedAction;
    String recommendedActionLabel;
    switch (diagnosis.recommendedAction) {
      case ScriptWorkbenchRecommendedAction.syncWorkbench:
        recommendedAction = _loadingContext || _runningAction
            ? null
            : _refreshWorkbench;
        recommendedActionLabel = _loadingContext
            ? l10n.projectEditorScriptsSingleWorkbenchSyncBusy
            : scriptWorkbenchRecommendedActionLabel(
                l10n,
                diagnosis.recommendedAction,
              );
      case ScriptWorkbenchRecommendedAction.pollExtractState:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_pollExtractState);
        recommendedActionLabel = scriptWorkbenchRecommendedActionLabel(
          l10n,
          diagnosis.recommendedAction,
        );
      case ScriptWorkbenchRecommendedAction.startExtractAssets:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_startExtractAssets);
        recommendedActionLabel = scriptWorkbenchRecommendedActionLabel(
          l10n,
          diagnosis.recommendedAction,
        );
      case ScriptWorkbenchRecommendedAction.openEditImageWorkbench:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_openEditImageWorkbench);
        recommendedActionLabel = scriptWorkbenchRecommendedActionLabel(
          l10n,
          diagnosis.recommendedAction,
        );
      case ScriptWorkbenchRecommendedAction.exportScriptZip:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_exportCurrentScript);
        recommendedActionLabel = scriptWorkbenchRecommendedActionLabel(
          l10n,
          diagnosis.recommendedAction,
        );
    }
    return ScriptWorkbenchPanelView(
      model: ScriptWorkbenchPanelViewModel(
        contextLine: _contextLine,
        loadingContext: _loadingContext,
        runningAction: _runningAction,
        scriptContext: _scriptContext,
        extractStateRow: _extractStateRow,
        exportLine: _exportLine,
        extractStateLine: _extractStateLine,
        extractAssetsLine: _extractAssetsLine,
        diagnosis: diagnosis,
        relatedAssets: relatedAssets,
        errorReason: errorReason,
        recommendedActionLabel: recommendedActionLabel,
        recommendedAction: recommendedAction,
      ),
      callbacks: ScriptWorkbenchPanelViewCallbacks(
        onRefreshWorkbench: _loadingContext || _runningAction
            ? null
            : _refreshWorkbench,
        onExportCurrentScript: _runningAction
            ? null
            : () => _runAction(_exportCurrentScript),
        onPollExtractState: _runningAction
            ? null
            : () => _runAction(_pollExtractState),
        onStartExtractAssets: _runningAction
            ? null
            : () => _runAction(_startExtractAssets),
        onOpenEditImageWorkbench: _runningAction
            ? null
            : () => _runAction(_openEditImageWorkbench),
      ),
    );
  }
}
