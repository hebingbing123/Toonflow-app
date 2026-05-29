part of 'version_manager.dart';

class AssemblyVersion {
  AssemblyVersion({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.shotCount,
    required this.shotConfig,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int shotCount;
  final Map<String, dynamic> shotConfig;

  factory AssemblyVersion.fromJson(Map<String, dynamic> json) {
    return AssemblyVersion(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      shotCount: json['shot_count'] as int? ?? 0,
      shotConfig: json['shot_config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'shot_count': shotCount,
      'shot_config': shotConfig,
    };
  }

  AssemblyVersion copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? shotCount,
    Map<String, dynamic>? shotConfig,
  }) {
    return AssemblyVersion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      shotCount: shotCount ?? this.shotCount,
      shotConfig: shotConfig ?? this.shotConfig,
    );
  }
}

/// 草稿数据模型
class AssemblyDraft {
  AssemblyDraft({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.shotCount,
    required this.shotConfig,
  });

  final String id;
  final String name;
  final DateTime savedAt;
  final int shotCount;
  final Map<String, dynamic> shotConfig;

  factory AssemblyDraft.fromJson(Map<String, dynamic> json) {
    return AssemblyDraft(
      id: json['id'] as String,
      name: json['name'] as String,
      savedAt: DateTime.parse(json['saved_at'] as String),
      shotCount: json['shot_count'] as int? ?? 0,
      shotConfig: json['shot_config'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'saved_at': savedAt.toIso8601String(),
      'shot_count': shotCount,
      'shot_config': shotConfig,
    };
  }

  AssemblyDraft copyWith({
    String? id,
    String? name,
    DateTime? savedAt,
    int? shotCount,
    Map<String, dynamic>? shotConfig,
  }) {
    return AssemblyDraft(
      id: id ?? this.id,
      name: name ?? this.name,
      savedAt: savedAt ?? this.savedAt,
      shotCount: shotCount ?? this.shotCount,
      shotConfig: shotConfig ?? this.shotConfig,
    );
  }
}

/// 版本管理器组件
///
/// 提供成片版本管理功能：
/// - 显示版本列表
/// - 创建新版本
/// - 切换版本
/// - 删除版本
/// - 保存草稿
/// - 恢复草稿
///
/// Requirements: 6, 7
