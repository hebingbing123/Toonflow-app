import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../../rust_api.dart';
import '../dialogs/confirmation_dialogs.dart';
import 'version_comparison.dart';
import 'package:openflow_app/design_system/components/studio_card.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    final currentVersion = widget.versions.firstWhere(
      (v) => v.id == widget.currentVersionId,
      orElse: () => widget.versions.isNotEmpty
          ? widget.versions.first
          : AssemblyVersion(
              id: 'default',
              name: l10n.shortVideoVersionManagerDefaultVersion,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.history, size: 20, color: theme.colorScheme.primary),
                  Text(
                    l10n.shortVideoVersionManagerTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.versions.length >= 2)
                    FilledButton.tonalIcon(
                      onPressed: _isLoading ? null : _showCompareVersionsDialog,
                      icon: const Icon(Icons.compare_arrows, size: 18),
                      label: Text(l10n.shortVideoVersionManagerCompareVersions),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: _isLoading ? null : _showCreateVersionDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.shortVideoVersionManagerCreateNewVersion),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _isLoading ? null : _showSaveDraftDialog,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.shortVideoVersionManagerSaveDraft),
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
                    borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
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
                color: StudioTokens.of(context).primarySoft,
                borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
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
                          l10n.shortVideoVersionManagerCurrentVersion(
                            currentVersion.name,
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          l10n.shortVideoVersionManagerCurrentVersionMeta(
                            currentVersion.shotCount,
                            _formatDateTime(currentVersion.createdAt),
                          ),
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
              l10n.shortVideoVersionManagerAllVersions(widget.versions.length),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (widget.versions.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.shortVideoVersionManagerNoVersionsHint,
                icon: Icons.layers_outlined,
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < widget.versions.length; index++)
                    Builder(
                      builder: (context) {
                        final version = widget.versions[index];
                        final isCurrent = version.id == widget.currentVersionId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isCurrent
                              ? StudioTokens.of(context).primarySoft.withValues(
                                  alpha: 0.72,
                                )
                              : null,
                          child: ListTile(
                            leading: Icon(
                              isCurrent
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isCurrent
                                  ? StudioTokens.of(context).primary
                                  : StudioTokens.of(context).textSecondary,
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
                              l10n.shortVideoVersionManagerVersionRowSubtitle(
                                version.shotCount,
                                _formatDateTime(version.createdAt),
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isCurrent)
                                  IconButton(
                                    icon: const Icon(Icons.swap_horiz, size: 20),
                                    tooltip: l10n
                                        .shortVideoVersionManagerTooltipSwitchVersion,
                                    onPressed: _isLoading
                                        ? null
                                        : () => _handleSwitchVersion(version.id),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  tooltip: l10n
                                      .shortVideoVersionManagerTooltipDeleteVersion,
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
                ],
              ),

            const SizedBox(height: 24),

            // 草稿列表
            Row(
              children: [
                Text(
                  l10n.shortVideoVersionManagerDraftsHeader(
                    widget.drafts.length,
                    10,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.drafts.isNotEmpty)
                  TextButton.icon(
                    onPressed: _isLoading ? null : _showDraftsDialog,
                    icon: const Icon(Icons.list, size: 18),
                    label: Text(l10n.shortVideoVersionManagerViewAllDrafts),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (widget.drafts.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.shortVideoVersionManagerNoDraftsHint,
                icon: Icons.drafts_outlined,
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0;
                      index < (widget.drafts.length > 3 ? 3 : widget.drafts.length);
                      index++)
                    Builder(builder: (context) {
                  final draft = widget.drafts[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: StudioCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                      leading: Icon(
                        Icons.drafts_outlined,
                        color: theme.colorScheme.secondary,
                      ),
                      title: Text(draft.name),
                      subtitle: Text(
                        l10n.shortVideoVersionManagerDraftRowSubtitle(
                          draft.shotCount,
                          _formatDateTime(draft.savedAt),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, size: 20),
                            tooltip: l10n.shortVideoVersionManagerTooltipRestoreDraft,
                            onPressed: _isLoading
                                ? null
                                : () => _handleRestoreDraft(draft),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: l10n.shortVideoVersionManagerTooltipDeleteDraft,
                            onPressed: _isLoading
                                ? null
                                : () => _handleDeleteDraft(draft),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                    }),
                ],
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = await showStudioDialog<String>(
      context: context,
      builder: (context) {
        var draftName = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => StudioAlertDialog(
            title: Text(l10n.shortVideoVersionManagerCreateVersionDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shortVideoVersionManagerCreateVersionDialogBody),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.shortVideoVersionManagerVersionNameLabel,
                      hintText: l10n.shortVideoVersionManagerVersionNameHint,
                      border: const OutlineInputBorder(),
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
                child: Text(l10n.notificationsActionCancel),
              ),
              FilledButton(
                onPressed: () {
                  final name = draftName.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: Text(l10n.shortVideoVersionManagerCreateAction),
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
            content: Text(
              resolveAppLocalizationsForErrors(context)
                  .shortVideoVersionManagerSnackbarVersionCreated(name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorVersionCreate(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
            content: Text(
              resolveAppLocalizationsForErrors(context)
                  .shortVideoVersionManagerSnackbarVersionSwitched(version.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorVersionSwitch(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
      showDontShowAgain: true,
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
            content: Text(
              resolveAppLocalizationsForErrors(context)
                  .shortVideoVersionManagerSnackbarVersionDeleted(version.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorVersionDelete(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
        final l10n = resolveAppLocalizationsForErrors(context);
        showStudioDialog<void>(
          context: context,
          builder: (context) {
            return StudioAlertDialog(
              title: Text(l10n.shortVideoVersionManagerDraftLimitTitle),
              content: Text(l10n.shortVideoVersionManagerDraftLimitBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.shortVideoVersionManagerGotIt),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDraftsDialog();
                  },
                  child: Text(l10n.shortVideoVersionManagerViewDraftsList),
                ),
              ],
            );
          },
        );
      }
      return;
    }

    final l10n = resolveAppLocalizationsForErrors(context);
    final result = await showStudioDialog<String>(
      context: context,
      builder: (context) {
        var draftName = '';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => StudioAlertDialog(
            title: Text(l10n.shortVideoVersionManagerSaveDraftDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.shortVideoVersionManagerSaveDraftDialogBody),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.shortVideoVersionManagerDraftNameLabel,
                      hintText: l10n.shortVideoVersionManagerDraftNameHint,
                      border: const OutlineInputBorder(),
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
                child: Text(l10n.notificationsActionCancel),
              ),
              FilledButton(
                onPressed: () {
                  final name = draftName.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(dialogContext).pop(name);
                  }
                },
                child: Text(l10n.notificationsActionSave),
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
            content: Text(
              resolveAppLocalizationsForErrors(context)
                  .shortVideoVersionManagerSnackbarDraftSaved(name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorDraftSave(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
    final l10n = resolveAppLocalizationsForErrors(context);
    await showStudioDialog<void>(
      context: context,
      builder: (context) {
        return StudioAlertDialog(
          title: Text(l10n.shortVideoVersionManagerDraftListTitle),
          content: SizedBox(
            width: double.maxFinite,
            child: widget.drafts.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(l10n.shortVideoVersionManagerNoDraftsInList),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.drafts.length,
                    itemBuilder: (context, index) {
                      final draft = widget.drafts[index];
                      final theme = Theme.of(context);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: StudioCard(
                          padding: EdgeInsets.zero,
                          child: ListTile(
                          leading: Icon(
                            Icons.drafts_outlined,
                            color: theme.colorScheme.secondary,
                          ),
                          title: Text(draft.name),
                          subtitle: Text(
                            l10n.shortVideoVersionManagerDraftListRowSubtitle(
                              draft.shotCount,
                              _formatDateTime(draft.savedAt),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore, size: 20),
                                tooltip:
                                    l10n.shortVideoVersionManagerTooltipRestoreDraft,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleRestoreDraft(draft);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                tooltip:
                                    l10n.shortVideoVersionManagerTooltipDeleteDraft,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _handleDeleteDraft(draft);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.shortVideoSpaceProductionAssemblyClose),
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
      showDontShowAgain: true,
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
            content: Text(
              resolveAppLocalizationsForErrors(context)
                  .shortVideoVersionManagerSnackbarDraftRestored(draft.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorDraftRestore(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = resolveAppLocalizationsForErrors(context);
        return StudioAlertDialog(
          title: Text(l10n.shortVideoVersionManagerConfirmDeleteDraftTitle),
          content: Text(
            l10n.shortVideoVersionManagerConfirmDeleteDraftBody(draft.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.notificationsActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.notificationsActionDelete),
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
            content: Text(
              resolveAppLocalizationsForErrors(context)
                  .shortVideoVersionManagerSnackbarDraftDeleted(draft.name),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        setState(() {
          _errorMessage = l10nErr.shortVideoVersionManagerErrorDraftDelete(
            describeUserVisibleApiErrorResolved(context, e),
          );
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

    await showStudioDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final l10n = resolveAppLocalizationsForErrors(dialogContext);
            return StudioAlertDialog(
              title: Text(l10n.shortVideoVersionManagerCompareDialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.shortVideoVersionManagerCompareBaseLabel),
                    const SizedBox(height: 8),
                    StudioDropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: StudioLayoutSpacing.insetDense,
                          vertical: StudioSpacing.xs,
                        ),
                      ),
                      hint: Text(l10n.shortVideoVersionManagerCompareBaseHint),
                      initialValue: baseVersion?.id,
                      items: widget.versions.map((version) {
                        return DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            l10n.shortVideoVersionManagerCompareVersionWithShots(
                              version.name,
                              version.shotCount,
                            ),
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
                    Text(l10n.shortVideoVersionManagerCompareTargetLabel),
                    const SizedBox(height: 8),
                    StudioDropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: StudioLayoutSpacing.insetDense,
                          vertical: StudioSpacing.xs,
                        ),
                      ),
                      hint: Text(l10n.shortVideoVersionManagerCompareTargetHint),
                      initialValue: compareVersion?.id,
                      items: widget.versions.map((version) {
                        return DropdownMenuItem(
                          value: version.id,
                          child: Text(
                            l10n.shortVideoVersionManagerCompareVersionWithShots(
                              version.name,
                              version.shotCount,
                            ),
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
                  child: Text(l10n.notificationsActionCancel),
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
                  child: Text(l10n.shortVideoVersionManagerStartCompare),
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
    showStudioDialog<void>(
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
