part of 'version_comparison.dart';

// ignore_for_file: invalid_use_of_protected_member

class VersionComparison extends StatefulWidget {
  const VersionComparison({
    required this.baseVersion,
    required this.compareVersion,
    required this.onClose,
    super.key,
  });

  /// 基准版本（旧版本）
  final AssemblyVersion baseVersion;

  /// 对比版本（新版本）
  final AssemblyVersion compareVersion;

  /// 关闭回调
  final VoidCallback onClose;

  @override
  State<VersionComparison> createState() => _VersionComparisonState();
}

class _VersionComparisonState extends State<VersionComparison> {
  late List<ShotDifference> _differences;
  late ComparisonStatistics _statistics;
  bool _showOnlyChanges = false;
  String _searchQuery = '';
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _computeDifferences();
  }

  /// 计算两个版本之间的差异
  void _computeDifferences() {
    final baseShots = widget.baseVersion.shotConfig['shots'] as List? ?? [];
    final compareShots =
        widget.compareVersion.shotConfig['shots'] as List? ?? [];

    final differences = <ShotDifference>[];
    final baseShotMap = <String, dynamic>{};
    final compareShotMap = <String, dynamic>{};

    // 构建镜头映射
    for (final shot in baseShots) {
      if (shot is Map<String, dynamic>) {
        final id = shot['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          baseShotMap[id] = shot;
        }
      }
    }

    for (final shot in compareShots) {
      if (shot is Map<String, dynamic>) {
        final id = shot['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          compareShotMap[id] = shot;
        }
      }
    }

    // 查找新增和修改的镜头
    for (final entry in compareShotMap.entries) {
      final shotId = entry.key;
      final compareShot = entry.value as Map<String, dynamic>;

      if (!baseShotMap.containsKey(shotId)) {
        // 新增的镜头
        differences.add(
          ShotDifference(shotId: shotId, type: DifferenceType.added),
        );
      } else {
        // 检查是否有修改
        final baseShot = baseShotMap[shotId] as Map<String, dynamic>;
        final shotDiffs = _compareShots(shotId, baseShot, compareShot);
        differences.addAll(shotDiffs);
      }
    }

    // 查找删除的镜头
    for (final shotId in baseShotMap.keys) {
      if (!compareShotMap.containsKey(shotId)) {
        differences.add(
          ShotDifference(shotId: shotId, type: DifferenceType.removed),
        );
      }
    }

    // 计算统计信息
    final addedCount = differences
        .where((d) => d.type == DifferenceType.added)
        .length;
    final removedCount = differences
        .where((d) => d.type == DifferenceType.removed)
        .length;
    final modifiedShotIds = differences
        .where((d) => d.type == DifferenceType.modified)
        .map((d) => d.shotId)
        .toSet();
    final modifiedCount = modifiedShotIds.length;
    final totalShots = compareShotMap.length + removedCount;
    final unchangedCount =
        totalShots - addedCount - removedCount - modifiedCount;

    setState(() {
      _differences = differences;
      _statistics = ComparisonStatistics(
        totalShots: totalShots,
        addedCount: addedCount,
        removedCount: removedCount,
        modifiedCount: modifiedCount,
        unchangedCount: unchangedCount,
      );
    });
  }

  /// 对比两个镜头的详细差异
  List<ShotDifference> _compareShots(
    String shotId,
    Map<String, dynamic> baseShot,
    Map<String, dynamic> compareShot,
  ) {
    final differences = <ShotDifference>[];
    final allKeys = {...baseShot.keys, ...compareShot.keys};

    for (final key in allKeys) {
      final baseValue = baseShot[key];
      final compareValue = compareShot[key];

      if (baseValue != compareValue) {
        differences.add(
          ShotDifference(
            shotId: shotId,
            type: DifferenceType.modified,
            fieldName: key,
            oldValue: baseValue,
            newValue: compareValue,
          ),
        );
      }
    }

    return differences;
  }

  /// 过滤差异列表
  List<ShotDifference> get _filteredDifferences {
    final l10n = resolveAppLocalizationsForErrors(context);
    var filtered = _differences;

    // 仅显示变化
    if (_showOnlyChanges) {
      filtered = filtered
          .where((d) => d.type != DifferenceType.unchanged)
          .toList();
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        return d.shotId.toLowerCase().contains(query) ||
            d.localizedDescription(l10n).toLowerCase().contains(query) ||
            (d.fieldName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// 导出对比报告
  Future<void> _exportComparisonReport() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final l10n = resolveAppLocalizationsForErrors(context);
      final report = _generateReportText(l10n);

      // 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: report));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.shortVideoVersionComparisonReportCopied),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: l10n.shortVideoVersionComparisonSnackbarView,
              textColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: () {
                _showReportDialog(report);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = resolveAppLocalizationsForErrors(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.shortVideoVersionComparisonExportFailed(
                describeUserVisibleApiErrorResolved(context, e),
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  /// 生成报告文本
  String _generateReportText(AppLocalizations l10n) {
    final buffer = StringBuffer();

    buffer.writeln(l10n.shortVideoVersionComparisonReportTitle);
    buffer.writeln();

    buffer.writeln(l10n.shortVideoVersionComparisonReportVersionInfo);
    buffer.writeln();
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportBaseVersionLine(
        widget.baseVersion.name,
      ),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportCreatedAt(
        _formatDateTime(widget.baseVersion.createdAt),
      ),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportShotCount(
        widget.baseVersion.shotCount,
      ),
    );
    buffer.writeln();
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportCompareVersionLine(
        widget.compareVersion.name,
      ),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportCreatedAt(
        _formatDateTime(widget.compareVersion.createdAt),
      ),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportShotCount(
        widget.compareVersion.shotCount,
      ),
    );
    buffer.writeln();

    buffer.writeln(l10n.shortVideoVersionComparisonReportStatistics);
    buffer.writeln();
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportTotalShots(_statistics.totalShots),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportAdded(_statistics.addedCount),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportRemoved(_statistics.removedCount),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportModified(_statistics.modifiedCount),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportUnchanged(
        _statistics.unchangedCount,
      ),
    );
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportChangeRate(
        '${_statistics.changePercentage.toStringAsFixed(1)}%',
      ),
    );
    buffer.writeln();

    buffer.writeln(l10n.shortVideoVersionComparisonReportDetails);
    buffer.writeln();

    final added = _differences
        .where((d) => d.type == DifferenceType.added)
        .toList();
    final removed = _differences
        .where((d) => d.type == DifferenceType.removed)
        .toList();
    final modified = _differences
        .where((d) => d.type == DifferenceType.modified)
        .toList();

    if (added.isNotEmpty) {
      buffer.writeln(
        l10n.shortVideoVersionComparisonReportSectionAdded(added.length),
      );
      buffer.writeln();
      for (final diff in added) {
        buffer.writeln(
          l10n.shortVideoVersionComparisonReportShotItem(diff.shotId),
        );
      }
      buffer.writeln();
    }

    if (removed.isNotEmpty) {
      buffer.writeln(
        l10n.shortVideoVersionComparisonReportSectionRemoved(removed.length),
      );
      buffer.writeln();
      for (final diff in removed) {
        buffer.writeln(
          l10n.shortVideoVersionComparisonReportShotItem(diff.shotId),
        );
      }
      buffer.writeln();
    }

    if (modified.isNotEmpty) {
      buffer.writeln(l10n.shortVideoVersionComparisonReportSectionModified);
      buffer.writeln();

      final modifiedByShot = <String, List<ShotDifference>>{};
      for (final diff in modified) {
        modifiedByShot.putIfAbsent(diff.shotId, () => []).add(diff);
      }

      for (final entry in modifiedByShot.entries) {
        buffer.writeln(
          l10n.shortVideoVersionComparisonReportShotHeading(entry.key),
        );
        buffer.writeln();
        for (final diff in entry.value) {
          final field = diff.fieldName ?? '';
          buffer.writeln(
            l10n.shortVideoVersionComparisonReportFieldLine(field),
          );
          buffer.writeln(
            l10n.shortVideoVersionComparisonReportOldValue(
              _formatVersionComparisonValue(l10n, diff.oldValue),
            ),
          );
          buffer.writeln(
            l10n.shortVideoVersionComparisonReportNewValue(
              _formatVersionComparisonValue(l10n, diff.newValue),
            ),
          );
        }
        buffer.writeln();
      }
    }

    buffer.writeln(l10n.shortVideoVersionComparisonReportSeparator);
    buffer.writeln(
      l10n.shortVideoVersionComparisonReportGeneratedFooter(
        _formatDateTime(DateTime.now()),
      ),
    );

    return buffer.toString();
  }

  /// 显示报告对话框
  void _showReportDialog(String report) {
    showStudioDialog<void>(
      context: context,
      builder: (context) {
        final dialogL10n = resolveAppLocalizationsForErrors(context);
        return StudioAlertDialog(
          title: Text(dialogL10n.shortVideoVersionComparisonReportDialogTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                report,
                style: studioMonospaceMetaStyle(context),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(dialogL10n.shortVideoSpaceProductionAssemblyClose),
            ),
            FilledButton(
              style: studioFormPrimaryButtonStyle(context),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        dialogL10n.shortVideoVersionComparisonClipboardCopied,
                      ),
                    ),
                  );
                }
              },
              child: Text(dialogL10n.shortVideoVersionComparisonCopy),
            ),
          ],
        );
      },
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final filteredDiffs = _filteredDifferences;

    return StudioDialogFrame(
      child: Container(
        width: studioConstrainedDialogWidth(
          context,
          maxWidth: 960,
          horizontalMargin: 48,
        ),
        height: studioAdaptiveDialogHeight(
          context,
          fraction: 0.88,
          min: 420,
          max: 720,
        ),
        padding: const EdgeInsets.all(StudioSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: StudioIconSize.lg,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: StudioSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shortVideoVersionComparisonTitle,
                        style: studioDialogTitleStyle(context),
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        '${widget.baseVersion.name} → ${widget.compareVersion.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: StudioTokens.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StudioIconButton(
                  icon: Icons.close,
                  label: l10n.shortVideoSpaceProductionAssemblyClose,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.md),

            // 统计信息卡片
            Card(
              color: StudioTokens.of(context).primarySoft,
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.add_circle_outline,
                        label: l10n.shortVideoVersionComparisonStatAdded,
                        value: _statistics.addedCount.toString(),
                        color: StudioTokens.of(context).success,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.remove_circle_outline,
                        label: l10n.shortVideoVersionComparisonStatRemoved,
                        value: _statistics.removedCount.toString(),
                        color: StudioTokens.of(context).danger,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.edit_outlined,
                        label: l10n.shortVideoVersionComparisonStatModified,
                        value: _statistics.modifiedCount.toString(),
                        color: StudioTokens.of(context).warning,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.check_circle_outline,
                        label: l10n.shortVideoVersionComparisonStatUnchanged,
                        value: _statistics.unchangedCount.toString(),
                        color: StudioTokens.of(context).textMuted,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.percent,
                        label: l10n.shortVideoVersionComparisonStatChangeRate,
                        value:
                            '${_statistics.changePercentage.toStringAsFixed(1)}%',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: StudioSpacing.sm),

            // 工具栏
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l10n.shortVideoVersionComparisonSearchHint,
                      prefixIcon: const Icon(Icons.search, size: StudioIconSize.md),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: StudioSpacing.sm),
                Wrap(
                  spacing: StudioSpacing.xs,
                  runSpacing: StudioSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StudioFilterChip(
                      label: Text(
                        l10n.shortVideoVersionComparisonShowChangesOnly,
                      ),
                      selected: _showOnlyChanges,
                      onSelected: (selected) {
                        setState(() {
                          _showOnlyChanges = selected;
                        });
                      },
                      avatar: Icon(
                        _showOnlyChanges
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        size: StudioIconSize.sm,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isExporting ? null : _exportComparisonReport,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: StudioIconSize.sm),
                      label: Text(l10n.shortVideoVersionComparisonExportReport),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.sm),

            // 差异列表
            Expanded(
              child: filteredDiffs.isEmpty
                  ? Center(
                      child: _searchQuery.isNotEmpty
                          ? StudioEmptyState.noResults(
                              title: l10n
                                  .shortVideoVersionComparisonEmptyNoMatch,
                            )
                          : StudioEmptyState.emptyData(
                              title: l10n
                                  .shortVideoVersionComparisonEmptyIdentical,
                              icon: Icons.check_circle_outline,
                            ),
                    )
                  : StudioCard(
                      padding: EdgeInsets.zero,
                      child: ListView.builder(
                        itemCount: filteredDiffs.length,
                        itemBuilder: (context, index) {
                          final diff = filteredDiffs[index];
                          return studioStaggeredItem(
                            index,
                            entranceKey: filteredDiffs.length,
                            child: _DifferenceListItem(difference: diff),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
