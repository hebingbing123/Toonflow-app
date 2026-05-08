import 'package:flutter/material.dart';

/// 成片版本数据模型
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

/// 版本管理器组件
///
/// 提供成片版本管理功能：
/// - 显示版本列表
/// - 创建新版本
/// - 切换版本
/// - 删除版本
///
/// Requirements: 6
class VersionManager extends StatefulWidget {
  const VersionManager({
    required this.versions,
    required this.currentVersionId,
    required this.onCreateVersion,
    required this.onSwitchVersion,
    required this.onDeleteVersion,
    super.key,
  });

  /// 版本列表
  final List<AssemblyVersion> versions;

  /// 当前版本 ID
  final String currentVersionId;

  /// 创建新版本回调
  final Future<void> Function(String name) onCreateVersion;

  /// 切换版本回调
  final Future<void> Function(String versionId) onSwitchVersion;

  /// 删除版本回调
  final Future<void> Function(String versionId) onDeleteVersion;

  @override
  State<VersionManager> createState() => _VersionManagerState();
}

class _VersionManagerState extends State<VersionManager> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVersion = widget.versions.firstWhere(
      (v) => v.id == widget.currentVersionId,
      orElse: () => widget.versions.isNotEmpty
          ? widget.versions.first
          : AssemblyVersion(
              id: 'default',
              name: '默认版本',
              createdAt: DateTime.now(),
              shotCount: 0,
              shotConfig: {},
            ),
    );

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.history, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '版本管理',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _isLoading ? null : _showCreateVersionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('创建新版本'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 错误消息
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 当前版本信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前版本：${currentVersion.name}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '镜头数：${currentVersion.shotCount} · '
                          '创建时间：${_formatDateTime(currentVersion.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 版本列表
            Text(
              '所有版本 (${widget.versions.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (widget.versions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '暂无版本，点击上方按钮创建第一个版本',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.versions.length,
                itemBuilder: (context, index) {
                  final version = widget.versions[index];
                  final isCurrent = version.id == widget.currentVersionId;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isCurrent
                        ? theme.colorScheme.surfaceContainerHighest
                        : null,
                    child: ListTile(
                      leading: Icon(
                        isCurrent
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        version.name,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '镜头数：${version.shotCount} · '
                        '创建时间：${_formatDateTime(version.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isCurrent)
                            IconButton(
                              icon: const Icon(Icons.swap_horiz, size: 20),
                              tooltip: '切换到此版本',
                              onPressed: _isLoading
                                  ? null
                                  : () => _handleSwitchVersion(version.id),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: '删除版本',
                            onPressed: _isLoading || isCurrent
                                ? null
                                : () => _handleDeleteVersion(version),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // 加载指示器
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  /// 显示创建版本对话框
  Future<void> _showCreateVersionDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        var draftName = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('创建新版本'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('新版本将复制当前镜头配置。'),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '版本名称',
                      hintText: '例如：优化版 v2',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    maxLength: 50,
                    onChanged: (value) {
                      setDialogState(() {
                        draftName = value;
                      });
                    },
                    onSubmitted: (value) {
                      final name = value.trim();
                      if (name.isNotEmpty) {
                        Navigator.of(dialogContext).pop(name);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final name = draftName.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: const Text('创建'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _handleCreateVersion(result);
    }
  }

  /// 处理创建版本
  Future<void> _handleCreateVersion(String name) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreateVersion(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('版本 "$name" 创建成功'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '创建版本失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 处理切换版本
  Future<void> _handleSwitchVersion(String versionId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSwitchVersion(versionId);
      if (mounted) {
        final version = widget.versions.firstWhere((v) => v.id == versionId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到版本 "${version.name}"'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '切换版本失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 处理删除版本
  Future<void> _handleDeleteVersion(AssemblyVersion version) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(
            '确定要删除版本 "${version.name}" 吗？\n\n'
            '此操作无法撤销。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onDeleteVersion(version.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('版本 "${version.name}" 已删除'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '删除版本失败：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
}
