part of '../home_page.dart';

class _ScriptWorkbenchPanel extends StatefulWidget {
  const _ScriptWorkbenchPanel({
    required this.token,
    required this.projectLegacyId,
    required this.scriptLegacyId,
    required this.onExtractStateSynced,
    required this.onOpenEditImageWorkbench,
  });

  final String token;
  final int projectLegacyId;
  final int scriptLegacyId;
  final void Function(int? extractState) onExtractStateSynced;
  final Future<void> Function() onOpenEditImageWorkbench;

  @override
  State<_ScriptWorkbenchPanel> createState() => _ScriptWorkbenchPanelState();
}

class _ScriptWorkbenchPanelState extends State<_ScriptWorkbenchPanel> {
  bool _loadingContext = false;
  bool _runningAction = false;
  LegacyScriptsGetScriptApiItem? _scriptContext;
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
      final rows = await postScriptsGetScriptApi(
        widget.token,
        widget.projectLegacyId,
      );
      final current = findScriptContextByLegacyId(rows, widget.scriptLegacyId);
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
    final zip = await exportScriptsZip(widget.token, [widget.scriptLegacyId]);
    if (!mounted) return;
    setState(
      () => _exportLine = '导出完成：1 个剧本，ZIP ${formatBinarySize(zip.length)}。',
    );
  }

  Future<void> _pollExtractState() async {
    final rows = await pollScriptExtractState(widget.token, [
      widget.scriptLegacyId,
    ]);
    final current = findScriptExtractStateByLegacyId(
      rows,
      widget.scriptLegacyId,
    );
    if (!mounted) return;
    setState(() {
      _extractStateRow = current;
      _extractStateLine = describeScriptExtractState(
        extractState: current?.extractState,
        errorReason: current?.errorReason,
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
      projectLegacyId: widget.projectLegacyId,
      scriptLegacyIds: [widget.scriptLegacyId],
    );
    await _refreshWorkbench();
    if (!mounted) return;
    setState(() {
      _extractAssetsLine = '素材抽取已提交：${accepted.status} · ${accepted.message}';
      _extractStateLine = describeScriptExtractState(
        extractState: _extractStateRow?.extractState ?? _scriptContext?.extractState,
        errorReason: _extractStateRow?.errorReason ?? _scriptContext?.errorReason,
      );
    });
  }

  Future<void> _openEditImageWorkbench() async {
    await widget.onOpenEditImageWorkbench();
    if (!mounted) return;
    await _refreshWorkbench();
    if (!mounted) return;
    setState(() {
      _contextLine = _scriptContext == null
          ? '编辑图片工作台已关闭；当前剧本仍未出现在 get-script-api 结果里。'
          : '编辑图片工作台已关闭，已同步脚本上下文与提取状态。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final relatedAssets = _scriptContext?.relatedAssets ?? const [];
    final errorReason = (_scriptContext?.errorReason ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: outline.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('脚本工作台', style: theme.textTheme.titleSmall)),
              TextButton(
                onPressed: _loadingContext || _runningAction
                    ? null
                    : _refreshWorkbench,
                child: Text(_loadingContext ? '同步中…' : '同步工作台'),
              ),
            ],
          ),
          Text(
            _contextLine ?? '自动同步 get-script-api 上下文与提取状态，并支持导出 ZIP、发起素材抽取与编辑图片流程。',
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          if (_loadingContext)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            Text(
              _scriptContext == null
                  ? '还没有当前剧本的上下文快照。'
                  : '关联素材：${summarizeRelatedScriptAssets(relatedAssets)}',
              style: theme.textTheme.bodySmall,
            ),
            if (_scriptContext != null) ...[
              const SizedBox(height: 6),
              Text(
                '提取状态：${_scriptContext?.extractState ?? 0}'
                '${errorReason.isEmpty ? '' : ' · $errorReason'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: errorReason.isEmpty
                      ? outline
                      : theme.colorScheme.error,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _runningAction
                    ? null
                    : () => _runAction(_exportCurrentScript),
                child: const Text('导出当前剧本 ZIP'),
              ),
              TextButton(
                onPressed: _runningAction
                    ? null
                    : () => _runAction(_pollExtractState),
                child: const Text('轮询提取状态'),
              ),
              TextButton(
                onPressed: _runningAction
                    ? null
                    : () => _runAction(_startExtractAssets),
                child: const Text('提取当前剧本素材'),
              ),
              TextButton(
                onPressed: _runningAction
                    ? null
                    : () => _runAction(_openEditImageWorkbench),
                child: const Text('编辑图片工作台'),
              ),
            ],
          ),
          if (_exportLine != null) ...[
            const SizedBox(height: 8),
            Text(_exportLine!, style: theme.textTheme.bodySmall),
          ],
          if (_extractStateLine != null) ...[
            const SizedBox(height: 8),
            Text(_extractStateLine!, style: theme.textTheme.bodySmall),
          ],
          if (_extractAssetsLine != null) ...[
            const SizedBox(height: 8),
            Text(_extractAssetsLine!, style: theme.textTheme.bodySmall),
          ],
          if (_extractStateRow != null &&
              (_extractStateRow!.errorReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '最近提取错误：${_extractStateRow!.errorReason!.trim()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
