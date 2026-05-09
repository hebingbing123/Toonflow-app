import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'version_manager.dart';

/// 版本对比差异类型
enum DifferenceType {
  added,    // 新增
  removed,  // 删除
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

  String get description {
    switch (type) {
      case DifferenceType.added:
        return '新增镜头';
      case DifferenceType.removed:
        return '删除镜头';
      case DifferenceType.modified:
        return fieldName != null ? '修改 $fieldName' : '修改';
      case DifferenceType.unchanged:
        return '未变化';
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
    final compareShots = widget.compareVersion.shotConfig['shots'] as List? ?? [];

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
        differences.add(ShotDifference(
          shotId: shotId,
          type: DifferenceType.added,
        ));
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
        differences.add(ShotDifference(
          shotId: shotId,
          type: DifferenceType.removed,
        ));
      }
    }

    // 计算统计信息
    final addedCount = differences.where((d) => d.type == DifferenceType.added).length;
    final removedCount = differences.where((d) => d.type == DifferenceType.removed).length;
    final modifiedShotIds = differences
        .where((d) => d.type == DifferenceType.modified)
        .map((d) => d.shotId)
        .toSet();
    final modifiedCount = modifiedShotIds.length;
    final totalShots = compareShotMap.length + removedCount;
    final unchangedCount = totalShots - addedCount - removedCount - modifiedCount;

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
        differences.add(ShotDifference(
          shotId: shotId,
          type: DifferenceType.modified,
          fieldName: key,
          oldValue: baseValue,
          newValue: compareValue,
        ));
      }
    }

    return differences;
  }

  /// 过滤差异列表
  List<ShotDifference> get _filteredDifferences {
    var filtered = _differences;

    // 仅显示变化
    if (_showOnlyChanges) {
      filtered = filtered.where((d) => d.type != DifferenceType.unchanged).toList();
    }

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        return d.shotId.toLowerCase().contains(query) ||
            d.description.toLowerCase().contains(query) ||
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
      final report = _generateReportText();
      
      // 复制到剪贴板
      await Clipboard.setData(ClipboardData(text: report));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('对比报告已复制到剪贴板'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            action: SnackBarAction(
              label: '查看',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败：$e'),
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
  String _generateReportText() {
    final buffer = StringBuffer();
    
    // 标题
    buffer.writeln('# 版本对比报告');
    buffer.writeln();
    
    // 版本信息
    buffer.writeln('## 版本信息');
    buffer.writeln();
    buffer.writeln('**基准版本（旧）：** ${widget.baseVersion.name}');
    buffer.writeln('- 创建时间：${_formatDateTime(widget.baseVersion.createdAt)}');
    buffer.writeln('- 镜头数：${widget.baseVersion.shotCount}');
    buffer.writeln();
    buffer.writeln('**对比版本（新）：** ${widget.compareVersion.name}');
    buffer.writeln('- 创建时间：${_formatDateTime(widget.compareVersion.createdAt)}');
    buffer.writeln('- 镜头数：${widget.compareVersion.shotCount}');
    buffer.writeln();
    
    // 统计信息
    buffer.writeln('## 差异统计');
    buffer.writeln();
    buffer.writeln('- 总镜头数：${_statistics.totalShots}');
    buffer.writeln('- 新增镜头：${_statistics.addedCount}');
    buffer.writeln('- 删除镜头：${_statistics.removedCount}');
    buffer.writeln('- 修改镜头：${_statistics.modifiedCount}');
    buffer.writeln('- 未变化镜头：${_statistics.unchangedCount}');
    buffer.writeln('- 变化率：${_statistics.changePercentage.toStringAsFixed(1)}%');
    buffer.writeln();
    
    // 详细差异
    buffer.writeln('## 详细差异');
    buffer.writeln();
    
    // 按类型分组
    final added = _differences.where((d) => d.type == DifferenceType.added).toList();
    final removed = _differences.where((d) => d.type == DifferenceType.removed).toList();
    final modified = _differences.where((d) => d.type == DifferenceType.modified).toList();
    
    if (added.isNotEmpty) {
      buffer.writeln('### 新增镜头 (${added.length})');
      buffer.writeln();
      for (final diff in added) {
        buffer.writeln('- 镜头 ${diff.shotId}');
      }
      buffer.writeln();
    }
    
    if (removed.isNotEmpty) {
      buffer.writeln('### 删除镜头 (${removed.length})');
      buffer.writeln();
      for (final diff in removed) {
        buffer.writeln('- 镜头 ${diff.shotId}');
      }
      buffer.writeln();
    }
    
    if (modified.isNotEmpty) {
      buffer.writeln('### 修改镜头');
      buffer.writeln();
      
      // 按镜头分组
      final modifiedByShot = <String, List<ShotDifference>>{};
      for (final diff in modified) {
        modifiedByShot.putIfAbsent(diff.shotId, () => []).add(diff);
      }
      
      for (final entry in modifiedByShot.entries) {
        buffer.writeln('#### 镜头 ${entry.key}');
        buffer.writeln();
        for (final diff in entry.value) {
          buffer.writeln('- **${diff.fieldName}**');
          buffer.writeln('  - 旧值：${_formatValue(diff.oldValue)}');
          buffer.writeln('  - 新值：${_formatValue(diff.newValue)}');
        }
        buffer.writeln();
      }
    }
    
    // 生成时间
    buffer.writeln('---');
    buffer.writeln('*报告生成时间：${_formatDateTime(DateTime.now())}*');
    
    return buffer.toString();
  }

  /// 格式化值
  String _formatValue(dynamic value) {
    if (value == null) return '(空)';
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value ? '是' : '否';
    if (value is List) return '列表 (${value.length} 项)';
    if (value is Map) return '对象 (${value.length} 个字段)';
    return value.toString();
  }

  /// 显示报告对话框
  void _showReportDialog(String report) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('对比报告'),
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
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                }
              },
              child: const Text('复制'),
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
    final filteredDiffs = _filteredDifferences;

    return Dialog(
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
                Icon(Icons.compare_arrows, size: 24, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '版本对比',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.baseVersion.name} → ${widget.compareVersion.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: '关闭',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 统计信息卡片
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.add_circle_outline,
                        label: '新增',
                        value: _statistics.addedCount.toString(),
                        color: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.remove_circle_outline,
                        label: '删除',
                        value: _statistics.removedCount.toString(),
                        color: Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.edit_outlined,
                        label: '修改',
                        value: _statistics.modifiedCount.toString(),
                        color: Colors.orange,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.check_circle_outline,
                        label: '未变化',
                        value: _statistics.unchangedCount.toString(),
                        color: Colors.grey,
                      ),
                    ),
                    Expanded(
                      child: _StatisticItem(
                        icon: Icons.percent,
                        label: '变化率',
                        value: '${_statistics.changePercentage.toStringAsFixed(1)}%',
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
              children: [
                // 搜索框
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '搜索镜头 ID 或字段名...',
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
                
                // 仅显示变化
                FilterChip(
                  label: const Text('仅显示变化'),
                  selected: _showOnlyChanges,
                  onSelected: (selected) {
                    setState(() {
                      _showOnlyChanges = selected;
                    });
                  },
                  avatar: Icon(
                    _showOnlyChanges ? Icons.filter_alt : Icons.filter_alt_outlined,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 导出报告按钮
                FilledButton.tonalIcon(
                  onPressed: _isExporting ? null : _exportComparisonReport,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: const Text('导出报告'),
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
                                ? '没有找到匹配的差异'
                                : '两个版本完全相同',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 差异列表项组件
class _DifferenceListItem extends StatelessWidget {
  const _DifferenceListItem({
    required this.difference,
  });

  final ShotDifference difference;

  Color _getTypeColor(BuildContext context) {
    switch (difference.type) {
      case DifferenceType.added:
        return Colors.green;
      case DifferenceType.removed:
        return Colors.red;
      case DifferenceType.modified:
        return Colors.orange;
      case DifferenceType.unchanged:
        return Colors.grey;
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

  String _formatValue(dynamic value) {
    if (value == null) return '(空)';
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is bool) return value ? '是' : '否';
    if (value is List) return '列表 (${value.length} 项)';
    if (value is Map) return '对象 (${value.length} 个字段)';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _getTypeColor(context);

    return ListTile(
      leading: Icon(
        _getTypeIcon(),
        color: typeColor,
      ),
      title: Row(
        children: [
          Text(
            '镜头 ${difference.shotId}',
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
              difference.description,
              style: TextStyle(
                fontSize: 12,
                color: typeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: difference.type == DifferenceType.modified && difference.fieldName != null
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '旧',
                          style: TextStyle(fontSize: 10, color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatValue(difference.oldValue),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '新',
                          style: TextStyle(fontSize: 10, color: Colors.green),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatValue(difference.newValue),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
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
