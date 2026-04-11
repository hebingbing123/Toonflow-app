part of '../../home_page.dart';

class _AssetGenerationWorkbenchDialog extends StatefulWidget {
  const _AssetGenerationWorkbenchDialog({
    required this.token,
    required this.project,
    required this.scriptList,
    required this.visibleAssets,
    required this.assetsFilterScriptLegacyId,
    required this.initialSelectedIds,
    required this.initialFocusedAssetLegacyId,
    required this.initialScriptLegacyId,
    required this.onMutationStart,
    required this.onMutationEnd,
    required this.reloadAssetsAndStats,
  });

  final String token;
  final ProjectRow project;
  final List<ScriptBrief> scriptList;
  final List<AssetRow> Function() visibleAssets;
  final List<int?> assetsFilterScriptLegacyId;
  final Iterable<int> initialSelectedIds;
  final int? initialFocusedAssetLegacyId;
  final int initialScriptLegacyId;
  final VoidCallback onMutationStart;
  final VoidCallback onMutationEnd;
  final Future<void> Function() reloadAssetsAndStats;

  @override
  State<_AssetGenerationWorkbenchDialog> createState() =>
      _AssetGenerationWorkbenchDialogState();
}

class _AssetGenerationWorkbenchDialogState
    extends State<_AssetGenerationWorkbenchDialog> {
  late final TextEditingController _modelCtrl;
  late final TextEditingController _resolutionCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _batchNameCtrl;
  late final TextEditingController _batchLimitCtrl;

  late final Set<int> _selectedIds;
  int? _focusedAssetLegacyId;
  late int _selectedScriptLegacyId;
  String _selectedType = '';
  bool _loadingSummary = false;
  bool _busyMutation = false;
  AssetsDataResponseV1? _productionData;
  AssetsPollingImageResponseV1? _pollingData;
  LegacyAssetMaterialDataResponse? _materialData;
  LegacyAssetBatchGenerationDataResponse? _batchData;
  List<LegacyAssetPollingPromptAssetsItem>? _promptPollingData;
  String? _statusLine;

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController();
    _resolutionCtrl = TextEditingController();
    _imageUrlCtrl = TextEditingController();
    _batchNameCtrl = TextEditingController();
    _batchLimitCtrl = TextEditingController(text: '10');
    _selectedIds = <int>{...widget.initialSelectedIds};
    _focusedAssetLegacyId = widget.initialFocusedAssetLegacyId;
    _selectedScriptLegacyId = widget.initialScriptLegacyId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _syncWorkbenchSnapshot(includeProductionSummary: true);
    });
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _resolutionCtrl.dispose();
    _imageUrlCtrl.dispose();
    _batchNameCtrl.dispose();
    _batchLimitCtrl.dispose();
    super.dispose();
  }

  List<AssetRow> _filteredVisibleAssets() {
    final assets = widget.visibleAssets();
    if (_selectedType.isEmpty) return assets;
    return assets
        .where((a) => a.assetType.trim() == _selectedType)
        .toList(growable: false);
  }

  List<int> _sortedSelection() => sortUniqueAssetLegacyIds(_selectedIds);

  void _applySelection(Iterable<int> ids, String label) {
    final next = sortUniqueAssetLegacyIds(ids);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetLegacyId = next.isEmpty ? _focusedAssetLegacyId : next.first;
      _statusLine = next.isEmpty
          ? '$label：没有可选资产'
          : '$label：已选择 ${next.length} 条资产';
    });
  }

  void _applyScopedSelection(Iterable<int> candidateIds, String label) {
    final next = collectScopedAssetLegacyIds(
      candidateIds,
      _filteredVisibleAssets(),
    );
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetLegacyId = next.isEmpty ? null : next.first;
      _statusLine = next.isEmpty
          ? '$label：当前可见资产中没有匹配项'
          : '$label：已选择 ${next.length} 条资产';
    });
  }

  Future<void> _syncWorkbenchSnapshot({
    required bool includeProductionSummary,
    String? lead,
  }) async {
    setState(() {
      _loadingSummary = true;
      _statusLine = lead == null ? null : '$lead，正在同步工作台摘要…';
    });
    try {
      final selected = _sortedSelection();
      AssetsDataResponseV1? nextProductionData = _productionData;
      if (includeProductionSummary) {
        nextProductionData = await postProductionAssetsGetAssetsDataV1(
          widget.token,
          projectId: widget.project.legacyId,
          assetType: _selectedType.isEmpty ? null : _selectedType,
        );
      }
      AssetsPollingImageResponseV1? nextPollingData;
      List<LegacyAssetPollingPromptAssetsItem>? nextPromptPollingData;
      if (selected.isNotEmpty) {
        nextPollingData = await postProductionAssetsPollingImageV1(
          widget.token,
          projectId: widget.project.legacyId,
          assetIds: selected,
        );
        nextPromptPollingData = await postLegacyAssetsPollingPromptAssets(
          widget.token,
          selected,
        );
      }
      final currentVisibleAssets = _filteredVisibleAssets();
      final nextSelection = chooseVisibleAssetSelection(
        currentVisibleAssets,
        preferredIds: _selectedIds,
        preferredLegacyId: _focusedAssetLegacyId,
      );
      if (!mounted) return;
      setState(() {
        if (includeProductionSummary) _productionData = nextProductionData;
        _pollingData = nextPollingData;
        _promptPollingData = nextPromptPollingData;
        _selectedIds
          ..clear()
          ..addAll(nextSelection);
        _focusedAssetLegacyId = _selectedIds.isEmpty
            ? null
            : _selectedIds.first;
        _statusLine = summarizeAssetWorkbenchSnapshot(
          lead: lead,
          visibleAssets: currentVisibleAssets,
          selectedIds: _selectedIds,
          productionData: _productionData,
          pollingData: _pollingData,
          promptPollingData: _promptPollingData,
        );
      });
    } on RustApiException catch (e) {
      if (mounted) setState(() => _statusLine = '同步工作台摘要失败：$e');
    } catch (e) {
      if (mounted) setState(() => _statusLine = '同步工作台摘要失败：$e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    widget.onMutationStart();
    setState(() => _busyMutation = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (mounted) setState(() => _statusLine = '$e');
    } on FormatException catch (e) {
      if (mounted) setState(() => _statusLine = e.message);
    } catch (e) {
      if (mounted) setState(() => _statusLine = '$e');
    } finally {
      if (mounted) setState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visibleAssets();
    final scopedAssets = _filteredVisibleAssets();
    final typeSelections = collectAssetIdsByType(visible);
    final pollingSelections = _pollingData == null
        ? const <String, List<int>>{}
        : collectAssetIdsByImageState(_pollingData!.statuses);
    final promptSelections = _promptPollingData == null
        ? const <String, List<int>>{}
        : collectAssetIdsByPromptState(_promptPollingData!);
    final selected = _sortedSelection();
    final selectedSingleAssetId = selected.length == 1 ? selected.first : null;

    return AlertDialog(
      title: const Text('资产出图工作台'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把 production 资产摘要、批量出图、状态轮询、衍生图清理和封面 URL 更新收口到项目资产主流程，不再只依赖 system probe。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              _buildFilterRow(visible, typeSelections),
              const SizedBox(height: 8),
              _buildModelResolutionRow(),
              const SizedBox(height: 8),
              _buildBatchCandidateRow(),
              const SizedBox(height: 8),
              TextField(
                controller: _imageUrlCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: '更新封面 URL（单选时可用）',
                  helperText: '用于 production/assets/update-assets-url',
                ),
              ),
              const SizedBox(height: 12),
              _buildQueryActions(visible, scopedAssets, typeSelections),
              const SizedBox(height: 8),
              _buildMutationActions(
                selected,
                selectedSingleAssetId,
                scopedAssets,
              ),
              const SizedBox(height: 8),
              Text(
                widget.assetsFilterScriptLegacyId[0] == null
                    ? '当前按项目全量资产操作；可在主视图先切换"按剧本筛选"再进入工作台。'
                    : '当前主视图已按剧本 #${widget.assetsFilterScriptLegacyId[0]} 过滤资产，工作台默认沿用这批可见资产。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              if (_statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_productionData != null) ...[
                const SizedBox(height: 4),
                Text(
                  summarizeProductionAssetData(_productionData!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
              if (_pollingData != null) ...[
                const SizedBox(height: 4),
                Text(
                  summarizeAssetPollingStatuses(_pollingData!.statuses),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pollingSelections.entries
                      .map(
                        (entry) => ActionChip(
                          label: Text('${entry.key} ${entry.value.length} 条'),
                          onPressed: _busyMutation
                              ? null
                              : () => _applyScopedSelection(
                                  entry.value,
                                  '已按图片状态 ${entry.key} 重建选择',
                                ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (_materialData != null) ...[
                const SizedBox(height: 4),
                Text(
                  summarizeLegacyAssetMaterialData(_materialData!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text('使用素材上下文 ${_materialData!.data.length} 条'),
                      onPressed: _busyMutation
                          ? null
                          : () => _applyScopedSelection(
                              _materialData!.data.map((item) => item.id),
                              '已按素材上下文重建选择',
                            ),
                    ),
                  ],
                ),
              ],
              if (_batchData != null) ...[
                const SizedBox(height: 4),
                Text(
                  summarizeLegacyBatchGenerationData(_batchData!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: Text('使用批量候选 ${_batchData!.data.length} 条'),
                      onPressed: _busyMutation
                          ? null
                          : () => _applyScopedSelection(
                              _batchData!.data.map((item) => item.id),
                              '已按批量候选重建选择',
                            ),
                    ),
                  ],
                ),
              ],
              if (_promptPollingData != null) ...[
                const SizedBox(height: 4),
                Text(
                  summarizeLegacyPromptPolling(_promptPollingData!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: promptSelections.entries
                      .map(
                        (entry) => ActionChip(
                          label: Text('${entry.key} ${entry.value.length} 条'),
                          onPressed: _busyMutation
                              ? null
                              : () => _applyScopedSelection(
                                  entry.value,
                                  '已按 prompt 状态 ${entry.key} 重建选择',
                                ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: scopedAssets.length,
                  itemBuilder: (context, index) {
                    final asset = scopedAssets[index];
                    return CheckboxListTile(
                      dense: true,
                      value: _selectedIds.contains(asset.legacyId),
                      onChanged: _busyMutation
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedIds.add(asset.legacyId);
                                  _focusedAssetLegacyId = asset.legacyId;
                                  if (_selectedIds.length == 1) {
                                    _imageUrlCtrl.clear();
                                  }
                                } else {
                                  _selectedIds.remove(asset.legacyId);
                                  if (_focusedAssetLegacyId == asset.legacyId) {
                                    final remaining = sortUniqueAssetLegacyIds(
                                      _selectedIds,
                                    );
                                    _focusedAssetLegacyId = remaining.isEmpty
                                        ? null
                                        : remaining.first;
                                  }
                                }
                              });
                            },
                      title: Text('#${asset.legacyId} ${asset.name}'),
                      subtitle: Text(
                        [
                          asset.assetType,
                          asset.description?.trim().isNotEmpty == true
                              ? asset.description!.trim()
                              : '无描述',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busyMutation ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildFilterRow(
    List<AssetRow> visible,
    Map<String, List<int>> typeSelections,
  ) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _selectedScriptLegacyId,
            decoration: const InputDecoration(
              labelText: '生成使用的剧本',
              helperText: '批量出图会把所选资产投给这个剧本上下文',
            ),
            items: widget.scriptList
                .map(
                  (script) => DropdownMenuItem<int>(
                    value: script.legacyId,
                    child: Text(
                      '#${script.legacyId} ${script.name ?? ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: _busyMutation
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _selectedScriptLegacyId = value);
                  },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: '资产类型筛选',
              helperText: '同时影响 production 摘要读取和可见选择集',
            ),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(value: '', child: Text('（全部类型）')),
              ...typeSelections.keys.map(
                (type) =>
                    DropdownMenuItem<String>(value: type, child: Text(type)),
              ),
            ],
            onChanged: _busyMutation
                ? null
                : (value) async {
                    final nextType = value ?? '';
                    final nextVisibleAssets = nextType.isEmpty
                        ? visible
                        : visible
                              .where((a) => a.assetType.trim() == nextType)
                              .toList(growable: false);
                    final nextSelection = chooseVisibleAssetSelection(
                      nextVisibleAssets,
                      preferredIds: _selectedIds,
                      preferredLegacyId: _focusedAssetLegacyId,
                    );
                    setState(() {
                      _selectedType = nextType;
                      _selectedIds
                        ..clear()
                        ..addAll(nextSelection);
                      _focusedAssetLegacyId = _selectedIds.isEmpty
                          ? null
                          : _selectedIds.first;
                      _statusLine = nextType.isEmpty
                          ? '正在切换到全部类型并同步工作台摘要…'
                          : '正在切换到 $nextType 并同步工作台摘要…';
                    });
                    await _syncWorkbenchSnapshot(
                      includeProductionSummary: true,
                    );
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildModelResolutionRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(labelText: '模型（可选）'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _resolutionCtrl,
            decoration: const InputDecoration(labelText: '分辨率（可选）'),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchCandidateRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _batchNameCtrl,
            decoration: const InputDecoration(labelText: '批量候选名称过滤（可选）'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _batchLimitCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '候选 limit'),
          ),
        ),
      ],
    );
  }

  Widget _buildQueryActions(
    List<AssetRow> visible,
    List<AssetRow> scopedAssets,
    Map<String, List<int>> typeSelections,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: _loadingSummary || _busyMutation
              ? null
              : () => _syncWorkbenchSnapshot(includeProductionSummary: true),
          child: Text(_loadingSummary ? '同步中…' : '同步当前工作台摘要'),
        ),
        TextButton(
          onPressed: _busyMutation
              ? null
              : () => _runMutation(() async {
                  final response = await postLegacyAssetsGetMaterialData(
                    widget.token,
                    widget.project.legacyId,
                  );
                  if (mounted) {
                    setState(() {
                      _materialData = response;
                      _statusLine = summarizeLegacyAssetMaterialData(response);
                    });
                  }
                }),
          child: const Text('读取素材上下文'),
        ),
        TextButton(
          onPressed: _busyMutation || visible.isEmpty
              ? null
              : () => _runMutation(() async {
                  final effectiveType = _selectedType.isEmpty
                      ? visible.first.assetType.trim()
                      : _selectedType;
                  final limit = int.tryParse(_batchLimitCtrl.text.trim()) ?? 10;
                  if (effectiveType.isEmpty) {
                    throw const FormatException('批量候选读取需要有效资产类型');
                  }
                  if (limit <= 0) {
                    throw const FormatException('候选 limit 需要大于 0');
                  }
                  final response = await postLegacyAssetsBatchGenerationData(
                    widget.token,
                    projectLegacyId: widget.project.legacyId,
                    assetType: effectiveType,
                    name: _batchNameCtrl.text.trim(),
                    limit: limit,
                  );
                  if (mounted) {
                    setState(() {
                      _batchData = response;
                      _statusLine =
                          '${summarizeLegacyBatchGenerationData(response)} · type=$effectiveType';
                    });
                  }
                }),
          child: const Text('读取批量候选'),
        ),
        TextButton(
          onPressed: _busyMutation
              ? null
              : () => _applySelection(
                  scopedAssets.map((a) => a.legacyId),
                  '已全选当前可见资产',
                ),
          child: const Text('全选当前可见资产'),
        ),
        TextButton(
          onPressed: _busyMutation
              ? null
              : () => _applySelection(
                  _selectedType.isEmpty
                      ? scopedAssets.map((a) => a.legacyId)
                      : (typeSelections[_selectedType] ?? const <int>[]),
                  _selectedType.isEmpty
                      ? '已按全部类型重建选择'
                      : '已按 $_selectedType 重建选择',
                ),
          child: const Text('按类型重建选择'),
        ),
        TextButton(
          onPressed: _busyMutation
              ? null
              : () => _applySelection(const <int>[], '已清空选择'),
          child: const Text('清空选择'),
        ),
      ],
    );
  }

  Widget _buildMutationActions(
    List<int> selected,
    int? selectedSingleAssetId,
    List<AssetRow> scopedAssets,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: _busyMutation || selected.isEmpty
              ? null
              : () => _runMutation(() async {
                  final response =
                      await postProductionAssetsBatchGenerateAssetsImageV1(
                        widget.token,
                        projectId: widget.project.legacyId,
                        scriptId: _selectedScriptLegacyId,
                        assetIds: selected,
                        model: _modelCtrl.text.trim().isEmpty
                            ? null
                            : _modelCtrl.text.trim(),
                        resolution: _resolutionCtrl.text.trim().isEmpty
                            ? null
                            : _resolutionCtrl.text.trim(),
                      );
                  await _syncWorkbenchSnapshot(
                    includeProductionSummary: true,
                    lead:
                        '已为 ${response.total} 条资产创建出图任务，队列 ${response.enqueued.length} 条',
                  );
                }),
          child: Text(_busyMutation ? '处理中…' : '批量发起资产出图'),
        ),
        TextButton(
          onPressed: _busyMutation || selected.isEmpty
              ? null
              : () => _runMutation(() async {
                  final response = await postProductionAssetsPollingImageV1(
                    widget.token,
                    projectId: widget.project.legacyId,
                    assetIds: selected,
                  );
                  if (mounted) {
                    setState(() {
                      _pollingData = response;
                      _statusLine = summarizeAssetWorkbenchSnapshot(
                        visibleAssets: scopedAssets,
                        selectedIds: _selectedIds,
                        productionData: _productionData,
                        pollingData: _pollingData,
                        promptPollingData: _promptPollingData,
                      );
                    });
                  }
                }),
          child: const Text('轮询图片状态'),
        ),
        TextButton(
          onPressed: _busyMutation || selected.isEmpty
              ? null
              : () => _runMutation(() async {
                  final response = await postLegacyAssetsPollingPromptAssets(
                    widget.token,
                    selected,
                  );
                  if (mounted) {
                    setState(() {
                      _promptPollingData = response;
                      _statusLine = summarizeAssetWorkbenchSnapshot(
                        visibleAssets: scopedAssets,
                        selectedIds: _selectedIds,
                        productionData: _productionData,
                        pollingData: _pollingData,
                        promptPollingData: _promptPollingData,
                      );
                    });
                  }
                }),
          child: const Text('轮询 prompt 状态'),
        ),
        TextButton(
          onPressed: _busyMutation || selected.isEmpty
              ? null
              : () => _runMutation(() async {
                  final response =
                      await postProductionAssetsDeleteAssetsDerivativeV1(
                        widget.token,
                        projectId: widget.project.legacyId,
                        assetIds: selected,
                      );
                  await widget.reloadAssetsAndStats();
                  await _syncWorkbenchSnapshot(
                    includeProductionSummary: true,
                    lead:
                        '已删除 ${response.deleted} 个衍生图记录，资产 ${response.assetIds.join(", ")}',
                  );
                }),
          child: const Text('清理衍生图'),
        ),
        TextButton(
          onPressed:
              _busyMutation ||
                  selectedSingleAssetId == null ||
                  _imageUrlCtrl.text.trim().isEmpty
              ? null
              : () => _runMutation(() async {
                  final response = await postProductionAssetsUpdateAssetsUrlV1(
                    widget.token,
                    projectId: widget.project.legacyId,
                    assetId: selectedSingleAssetId,
                    imageUrl: _imageUrlCtrl.text.trim(),
                  );
                  await widget.reloadAssetsAndStats();
                  await _syncWorkbenchSnapshot(
                    includeProductionSummary: true,
                    lead:
                        '已更新资产 #${response.assetId} 封面 URL：${response.message}',
                  );
                }),
          child: const Text('更新封面 URL'),
        ),
      ],
    );
  }
}
