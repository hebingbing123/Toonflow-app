part of '../../home_page.dart';

class _ScriptWorkbenchPanel extends StatefulWidget {
  const _ScriptWorkbenchPanel({
    required this.token,
    required this.projectId,
    required this.projectNumericId,
    required this.scriptNumericId,
    required this.onExtractStateSynced,
    required this.onOpenEditImageWorkbench,
  });

  final String token;
  final String projectId;
  final int projectNumericId;
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
            ? '当前剧本暂未出现在 get-script-api 结果里。'
            : '已加载脚本上下文：素材 ${current.relatedAssets.length} 项';
      });
      widget.onExtractStateSynced(current?.extractState);
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _contextLine = '脚本上下文读取失败：$e');
    } catch (e) {
      if (!mounted) return;
      setState(() => _contextLine = '脚本上下文读取失败：$e');
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
    } on RustApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _runningAction = false);
      }
    }
  }

  Future<void> _exportCurrentScript() async {
    final zip = await exportScriptsZip(widget.token, [widget.scriptNumericId]);
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    if (!mounted) return;
    setState(
      () => _exportLine = buildScriptWorkbenchFollowUp(
        actionSummary: '导出完成：1 个剧本，ZIP ${formatBinarySize(zip.length)}。',
        diagnosis: diagnosis,
      ),
    );
  }

  Future<void> _pollExtractState() async {
    final rows = await pollScriptExtractState(widget.token, [
      widget.scriptNumericId,
    ]);
    final current = findScriptExtractStateByNumericId(
      rows,
      widget.scriptNumericId,
    );
    if (!mounted) return;
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: _scriptContext,
      extractStateRow: current,
    );
    setState(() {
      _extractStateRow = current;
      _extractStateLine = buildScriptWorkbenchFollowUp(
        actionSummary:
            '已轮询当前剧本提取状态：${describeScriptExtractState(extractState: current?.extractState, errorReason: current?.errorReason)}',
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
    final accepted = await startScriptAssetExtract(
      widget.token,
      projectUuid: widget.projectId,
      scriptNumericIds: [widget.scriptNumericId],
    );
    await _refreshWorkbench();
    if (!mounted) return;
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    setState(() {
      _extractAssetsLine = buildScriptWorkbenchFollowUp(
        actionSummary: '素材抽取已提交：${accepted.status} · ${accepted.message}',
        diagnosis: diagnosis,
      );
      _extractStateLine = describeScriptExtractState(
        extractState:
            _extractStateRow?.extractState ?? _scriptContext?.extractState,
        errorReason:
            _extractStateRow?.errorReason ?? _scriptContext?.errorReason,
      );
    });
  }

  Future<void> _openEditImageWorkbench() async {
    await widget.onOpenEditImageWorkbench();
    if (!mounted) return;
    await _refreshWorkbench();
    if (!mounted) return;
    final diagnosis = diagnoseScriptWorkbench(
      scriptContext: _scriptContext,
      extractStateRow: _extractStateRow,
    );
    setState(() {
      _contextLine = _scriptContext == null
          ? '编辑图片工作台已关闭；当前剧本仍未出现在 get-script-api 结果里。'
          : buildScriptWorkbenchFollowUp(
              actionSummary: '编辑图片工作台已关闭，已同步脚本上下文与提取状态。',
              diagnosis: diagnosis,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final relatedAssets = _scriptContext?.relatedAssets ?? const [];
    final errorReason = (_scriptContext?.errorReason ?? '').trim();
    final diagnosis = diagnoseScriptWorkbench(
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
            ? '同步中…'
            : describeScriptWorkbenchRecommendedAction(
                diagnosis.recommendedAction,
              );
      case ScriptWorkbenchRecommendedAction.pollExtractState:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_pollExtractState);
        recommendedActionLabel = describeScriptWorkbenchRecommendedAction(
          diagnosis.recommendedAction,
        );
      case ScriptWorkbenchRecommendedAction.startExtractAssets:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_startExtractAssets);
        recommendedActionLabel = describeScriptWorkbenchRecommendedAction(
          diagnosis.recommendedAction,
        );
      case ScriptWorkbenchRecommendedAction.openEditImageWorkbench:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_openEditImageWorkbench);
        recommendedActionLabel = describeScriptWorkbenchRecommendedAction(
          diagnosis.recommendedAction,
        );
      case ScriptWorkbenchRecommendedAction.exportScriptZip:
        recommendedAction = _runningAction
            ? null
            : () => _runAction(_exportCurrentScript);
        recommendedActionLabel = describeScriptWorkbenchRecommendedAction(
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
