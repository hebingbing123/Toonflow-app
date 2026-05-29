part of 'version_comparison.dart';

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
