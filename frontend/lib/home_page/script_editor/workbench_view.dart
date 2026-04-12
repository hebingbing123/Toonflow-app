part of '../../home_page.dart';

/// 脚本工作台视图，承载建议卡片、状态摘要与动作入口布局。
extension _ScriptWorkbenchPanelView on _ScriptWorkbenchPanelState {
  Widget _buildScriptWorkbenchPanelView({
    required BuildContext context,
    required ThemeData theme,
    required Color outline,
    required ScriptWorkbenchDiagnosis diagnosis,
    required List<RelatedAssetSummary> relatedAssets,
    required String errorReason,
    required VoidCallback? recommendedAction,
    required String recommendedActionLabel,
  }) {
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
            _contextLine ??
                '自动同步 get-script-api 上下文与提取状态，并支持导出 ZIP、发起素材抽取与编辑图片流程。',
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(diagnosis.summary, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  diagnosis.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: recommendedAction,
                  child: Text(recommendedActionLabel),
                ),
              ],
            ),
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
