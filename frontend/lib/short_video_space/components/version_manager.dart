import 'package:flutter/material.dart';
import '../dialogs/confirmation_dialogs.dart';
import 'version_comparison.dart';

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
class VersionManager extends StatefulWidget {
  const VersionManager({
    required this.versions,
    required this.currentVersionId,
    required this.drafts,
    required this.onCreateVersion,
    required this.onSwitchVersion,
    required this.onDeleteVersion,
    required this.onSaveDraft,
    required this.onRestoreDraft,
    required this.onDeleteDraft,
    super.key,
  });

  /// 版本列表
  final List<AssemblyVersion> versions;

  /// 当前版本 ID
  final String currentVersionId;

  /// 草稿列表
  final List<AssemblyDraft> drafts;

  /// 创建新版本回调
  final Future<void> Function(String name) onCreateVersion;

  /// 切换版本回调
  final Future<void> Function(String versionId) onSwitchVersion;

  /// 删除版本回调
  final Future<void> Function(String versionId) onDeleteVersion;

  /// 保存草稿回调
  final Future<void> Function(String name) onSaveDraft;

  /// 恢复草稿回调
  final Future<void> Function(String draftId) onRestoreDraft;

  /// 删除草稿回调
  final Future<void> Function(String draftId) onDeleteDraft;

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
        child: SingleChildScrollView(
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
                  if (widget.versions.length >= 2)
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _showCompareVersionsDialog,
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: const Text('对比版本'),
                    ),
                  if (widget.versions.length >= 2)
                    const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _isLoading ? null : _showCreateVersionDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('创建新版本'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _isLoading ? null : _showSaveDraftDialog,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('保存草稿'),
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

            const SizedBox(height: 24),

            // 草稿列表
            Row(
              children: [
                Text(
                  '草稿 (${widget.drafts.length}/10)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.drafts.isNotEmpty)
                  TextButton.icon(
                    onPressed: _isLoading ? null : _showDraftsDialog,
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('查看全部'),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (widget.drafts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '暂无草稿，点击上方"保存草稿"按钮保存当前编辑状态',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              // 显示最近的 3 个草稿
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.drafts.length > 3 ? 3 : widget.drafts.length,
                itemBuilder: (context, index) {
                  final draft = widget.drafts[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.drafts_outlined,
                        color: theme.colorScheme.secondary,
                      ),
                      title: Text(draft.name),
                      subtitle: Text(
                        '镜头数：${draft.shotCount} · '
                        '保存时间：${_formatDateTime(draft.savedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, size: 20),
                            tooltip: '恢复草稿',
                            onPressed: _isLoading
                                ? null
                                : () => _handleRestoreDraft(draft),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: '删除草稿',
                            onPressed: _isLoading
                                ? null
                                : () => _handleDeleteDraft(draft),
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
    final confirmed = await showDeleteVersionConfirmation(
      context,
      versionName: version.name,
      showDontShowAgain: false, // TODO: Enable after proper SharedPreferences setup
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

  /// 显示保存草稿对话框
  Future<void> _showSaveDraftDialog() async {
    // 检查草稿数量限制
    if (widget.drafts.length >= 10) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('草稿数量已达上限'),
              content: const Text(
                '最多只能保存 10 个草稿。\n\n'
                '请先删除一些旧草稿，然后再保存新草稿。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('知道了'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDraftsDialog();
                  },
                  child: const Text('查看草稿'),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        var draftName = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('保存草稿'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('草稿将保存当前编辑状态，方便稍后继续编辑。'),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: '草稿名称',
                      hintText: '例如：实验性剪辑 v1',
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
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await _handleSaveDraft(result);
    }
  }

  /// 处理保存草稿
  Future<void> _handleSaveDraft(String name) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSaveDraft(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('草稿 "$name" 保存成功'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '保存草稿失败：$e';
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

  /// 显示草稿列表对话框
  Future<void> _showDraftsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('草稿列表'),
          content: SizedBox(
            width: double.maxFinite,
            child: widget.drafts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('暂无草稿'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.drafts.length,
                    itemBuilder: (context, index) {
                      final draft = widget.drafts[index];
                      final theme = Theme.of(context);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.drafts_outlined,
                            color: theme.colorScheme.secondary,
                          ),
                          title: Text(draft.name),
                          subtitle: Text(
                            '镜头数：${draft.shotCount}\n'
                            '保存时间：${_formatDateTime(draft.savedAt)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore, size: 20),
                                tooltip: '恢复草稿',
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleRestoreDraft(draft);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                tooltip: '删除草稿',
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleDeleteDraft(draft);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  /// 处理恢复草稿
  Future<void> _handleRestoreDraft(AssemblyDraft draft) async {
    // 显示确认对话框
    final confirmed = await showRestoreDraftConfirmation(
      context,
      draftName: draft.name,
      showDontShowAgain: false, // TODO: Enable after proper SharedPreferences setup
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onRestoreDraft(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('草稿 "${draft.name}" 已恢复'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '恢复草稿失败：$e';
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

  /// 处理删除草稿
  Future<void> _handleDeleteDraft(AssemblyDraft draft) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(
            '确定要删除草稿 "${draft.name}" 吗？\n\n'
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
      await widget.onDeleteDraft(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('草稿 "${draft.name}" 已删除'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '删除草稿失败：$e';
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

  /// 显示版本对比对话框
  Future<void> _showCompareVersionsDialog() async {
    if (widget.versions.length < 2) {
      return;
    }

    // 选择两个版本进行对比
    AssemblyVersion? baseVersion;
    AssemblyVersion? compareVersion;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('选择要对比的版本'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('选择基准版本（旧版本）：'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      hint: const Text('选择基准版本'),
                      initialValue: baseVersion?.id,
                      items: widget.versions.map((version) {
                        return DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            '${version.name} (${version.shotCount} 镜头)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          baseVersion = widget.versions.firstWhere(
                            (v) => v.id == value,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('选择对比版本（新版本）：'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      hint: const Text('选择对比版本'),
                      initialValue: compareVersion?.id,
                      items: widget.versions.map((version) {
                        return DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            '${version.name} (${version.shotCount} 镜头)',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          compareVersion = widget.versions.firstWhere(
                            (v) => v.id == value,
                          );
                        });
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
                  onPressed: baseVersion != null && 
                             compareVersion != null && 
                             baseVersion!.id != compareVersion!.id
                      ? () {
                          Navigator.of(dialogContext).pop();
                          _showVersionComparison(baseVersion!, compareVersion!);
                        }
                      : null,
                  child: const Text('开始对比'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示版本对比界面
  void _showVersionComparison(
    AssemblyVersion baseVersion,
    AssemblyVersion compareVersion,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return VersionComparison(
          baseVersion: baseVersion,
          compareVersion: compareVersion,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}
