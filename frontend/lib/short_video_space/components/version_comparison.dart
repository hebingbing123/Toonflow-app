import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
import '../../design_system/studio_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'version_manager.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

String _formatVersionComparisonValue(AppLocalizations l10n, dynamic value) {
  if (value == null) return l10n.shortVideoVersionComparisonValueEmpty;
  if (value is String) return value;
  if (value is num) return value.toString();
  if (value is bool) {
    return value
        ? l10n.shortVideoVersionComparisonValueYes
        : l10n.shortVideoVersionComparisonValueNo;
  }
  if (value is List) {
    return l10n.shortVideoVersionComparisonValueList(value.length);
  }
  if (value is Map) {
    return l10n.shortVideoVersionComparisonValueObject(value.length);
  }
  return value.toString();
}

/// 版本对比差异类型
enum DifferenceType {
  added, // 新增
  removed, // 删除
  modified, // 修改
  unchanged, // 未变化
}

/// 镜头差异信息
class ShotDifference {
  ShotDifference({
    required this.shotId,
    required this.type,
    this.fieldName,
    this.oldValue,
    this.newValue,
  });

  final String shotId;
  final DifferenceType type;
  final String? fieldName;
  final dynamic oldValue;
  final dynamic newValue;

  String localizedDescription(AppLocalizations l10n) {
    switch (type) {
      case DifferenceType.added:
        return l10n.shortVideoVersionComparisonDiffAdded;
      case DifferenceType.removed:
        return l10n.shortVideoVersionComparisonDiffRemoved;
      case DifferenceType.modified:
        return fieldName != null
            ? l10n.shortVideoVersionComparisonDiffModifiedField(fieldName!)
            : l10n.shortVideoVersionComparisonDiffModifiedGeneric;
      case DifferenceType.unchanged:
        return l10n.shortVideoVersionComparisonDiffUnchanged;
    }
  }
}

/// 版本对比统计信息
class ComparisonStatistics {
  ComparisonStatistics({
    required this.totalShots,
    required this.addedCount,
    required this.removedCount,
    required this.modifiedCount,
    required this.unchangedCount,
  });

  final int totalShots;
  final int addedCount;
  final int removedCount;
  final int modifiedCount;
  final int unchangedCount;

  int get changedCount => addedCount + removedCount + modifiedCount;

  double get changePercentage {
    if (totalShots == 0) return 0.0;
    return (changedCount / totalShots) * 100;
  }
}

/// 版本对比组件
///
/// 提供版本对比功能：
/// - 显示两个版本的差异
/// - 高亮显示变化的内容
/// - 统计差异数量
/// - 导出对比报告
///
/// Requirements: 8
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
              textColor: Colors.white,
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
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(dialogL10n.shortVideoSpaceProductionAssemblyClose),
            ),
            FilledButton(
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
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.shortVideoVersionComparisonTitle,
                        style: studioDialogTitleStyle(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.baseVersion.name} → ${widget.compareVersion.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: StudioTokens.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: l10n.shortVideoSpaceProductionAssemblyClose,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 统计信息卡片
            Card(
              color: theme.colorScheme.primaryContainer,
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
            const SizedBox(height: 16),

            // 工具栏
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: l10n.shortVideoVersionComparisonSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
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
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
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
                        size: 18,
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
                          : const Icon(Icons.download, size: 18),
                      label: Text(l10n.shortVideoVersionComparisonExportReport),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 差异列表
            Expanded(
              child: filteredDiffs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? l10n.shortVideoVersionComparisonEmptyNoMatch
                                : l10n.shortVideoVersionComparisonEmptyIdentical,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: StudioTokens.of(context).textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Card(
                      child: ListView.builder(
                        itemCount: filteredDiffs.length,
                        itemBuilder: (context, index) {
                          final diff = filteredDiffs[index];
                          return _DifferenceListItem(difference: diff);
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

/// 统计项组件
class _StatisticItem extends StatelessWidget {
  const _StatisticItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}

/// 差异列表项组件
class _DifferenceListItem extends StatelessWidget {
  const _DifferenceListItem({required this.difference});

  final ShotDifference difference;

  Color _getTypeColor(BuildContext context) {
    final tokens = StudioTokens.of(context);
    switch (difference.type) {
      case DifferenceType.added:
        return tokens.success;
      case DifferenceType.removed:
        return tokens.danger;
      case DifferenceType.modified:
        return tokens.warning;
      case DifferenceType.unchanged:
        return tokens.textMuted;
    }
  }

  IconData _getTypeIcon() {
    switch (difference.type) {
      case DifferenceType.added:
        return Icons.add_circle;
      case DifferenceType.removed:
        return Icons.remove_circle;
      case DifferenceType.modified:
        return Icons.edit;
      case DifferenceType.unchanged:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final typeColor = _getTypeColor(context);

    return ListTile(
      leading: Icon(_getTypeIcon(), color: typeColor),
      title: Row(
        children: [
          Text(
            l10n.shortVideoVersionComparisonShotTitle(difference.shotId),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: typeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              difference.localizedDescription(l10n),
              style: TextStyle(
                fontSize: 12,
                color: typeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle:
          difference.type == DifferenceType.modified &&
              difference.fieldName != null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.shortVideoVersionComparisonBadgeOld,
                          style: TextStyle(
                            fontSize: StudioTypography.of(context).meta,
                            color: tokens.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatVersionComparisonValue(
                            l10n,
                            difference.oldValue,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.danger,
                            decoration: TextDecoration.lineThrough,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.shortVideoVersionComparisonBadgeNew,
                          style: TextStyle(
                            fontSize: StudioTypography.of(context).meta,
                            color: tokens.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatVersionComparisonValue(
                            l10n,
                            difference.newValue,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.success,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
