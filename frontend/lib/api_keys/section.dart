import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'controller.dart';

enum _ExpiryPreset { none, sevenDays, thirtyDays, ninetyDays, custom }

class ApiKeysSection extends StatefulWidget {
  const ApiKeysSection({super.key, required this.controller});

  final ApiKeysController controller;

  @override
  State<ApiKeysSection> createState() => _ApiKeysSectionState();
}

class _ApiKeysSectionState extends State<ApiKeysSection> {
  final _displayNameController = TextEditingController();
  ApiKeyScopeV1 _scope = ApiKeyScopeV1.readOnly;
  _ExpiryPreset _expiryPreset = _ExpiryPreset.none;
  DateTime? _customExpiryDate;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.prime();
  }

  @override
  void didUpdateWidget(covariant ApiKeysSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      widget.controller.prime();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _displayNameController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _createExpiresAtIso() {
    return _expiryToIso(_expiryPreset, _customExpiryDate);
  }

  Future<void> _createKey() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showSnackBar('请先填写密钥名称');
      return;
    }
    if (_expiryPreset == _ExpiryPreset.custom && _customExpiryDate == null) {
      _showSnackBar('请先选择过期日期');
      return;
    }
    await widget.controller.createKey(
      displayName: displayName,
      scope: _scope,
      expiresAt: _createExpiresAtIso(),
    );
    if (!mounted) {
      return;
    }
    if (widget.controller.latestPlaintextToken != null) {
      _displayNameController.clear();
      setState(() {
        _scope = ApiKeyScopeV1.readOnly;
        _expiryPreset = _ExpiryPreset.none;
        _customExpiryDate = null;
      });
    }
  }

  Future<void> _copyText(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<DateTime?> _pickExpiryDate({DateTime? initialDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      helpText: '选择过期日期',
    );
    return picked;
  }

  Future<void> _pickCustomCreateExpiry() async {
    final picked = await _pickExpiryDate(initialDate: _customExpiryDate);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _expiryPreset = _ExpiryPreset.custom;
      _customExpiryDate = picked;
    });
  }

  Future<void> _showRotateDialog(ApiKeyRecordV1 item) async {
    var expiryPreset = _ExpiryPreset.none;
    DateTime? customDate;
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDialogDate() async {
              final picked = await _pickExpiryDate(initialDate: customDate);
              if (picked == null) {
                return;
              }
              setDialogState(() {
                expiryPreset = _ExpiryPreset.custom;
                customDate = picked;
              });
            }

            return AlertDialog(
              title: Text('轮换 ${item.displayName}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '轮换会立即作废旧 secret，并只显示一次新的明文 token。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('过期策略', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(
                          label: '保留当前',
                          selected: expiryPreset == _ExpiryPreset.none,
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.none;
                            });
                          },
                        ),
                        _choiceChip(
                          label: '清除过期',
                          selected:
                              expiryPreset == _ExpiryPreset.custom &&
                              customDate ==
                                  DateTime.fromMillisecondsSinceEpoch(0),
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.custom;
                              customDate = DateTime.fromMillisecondsSinceEpoch(
                                0,
                              );
                            });
                          },
                        ),
                        _choiceChip(
                          label: '7 天',
                          selected: expiryPreset == _ExpiryPreset.sevenDays,
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.sevenDays;
                              customDate = null;
                            });
                          },
                        ),
                        _choiceChip(
                          label: '30 天',
                          selected: expiryPreset == _ExpiryPreset.thirtyDays,
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.thirtyDays;
                              customDate = null;
                            });
                          },
                        ),
                        _choiceChip(
                          label: '自定义日期',
                          selected:
                              expiryPreset == _ExpiryPreset.custom &&
                              customDate != null &&
                              customDate !=
                                  DateTime.fromMillisecondsSinceEpoch(0),
                          onSelected: () {
                            pickDialogDate();
                          },
                        ),
                      ],
                    ),
                    if (customDate != null &&
                        customDate !=
                            DateTime.fromMillisecondsSinceEpoch(0)) ...[
                      const SizedBox(height: 8),
                      Text(
                        '将于 ${_fmtDate(customDate!)} 23:59 UTC 过期',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final expiresAt = switch (expiryPreset) {
                      _ExpiryPreset.none => null,
                      _ExpiryPreset.sevenDays => _expiryToIso(
                        _ExpiryPreset.sevenDays,
                        null,
                      ),
                      _ExpiryPreset.thirtyDays => _expiryToIso(
                        _ExpiryPreset.thirtyDays,
                        null,
                      ),
                      _ExpiryPreset.ninetyDays => _expiryToIso(
                        _ExpiryPreset.ninetyDays,
                        null,
                      ),
                      _ExpiryPreset.custom =>
                        customDate == DateTime.fromMillisecondsSinceEpoch(0)
                            ? ''
                            : _expiryToIso(_ExpiryPreset.custom, customDate),
                    };
                    Navigator.of(context).pop(expiresAt);
                  },
                  child: const Text('轮换'),
                ),
              ],
            );
          },
        );
      },
    );
    if (action == null) {
      return;
    }
    await widget.controller.rotateKey(item.id, expiresAt: action);
  }

  Future<void> _showRevokeDialog(ApiKeyRecordV1 item) async {
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('撤销 ${item.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '撤销后现有 token 将立即失效，直到再次恢复或轮换。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '原因（可选）',
                  hintText: '例如：凭据暴露、环境下线、机器人停用',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('撤销'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await widget.controller.revokeKey(
          item.id,
          reason: reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'API 密钥',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: '本机客户端偏好（密钥轮换/删除等「不再提示」与恢复确认）',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '为服务端自动化、CLI、CI/CD 与内部集成签发用户级凭据。只读 key 只能调用 GET/HEAD/OPTIONS；读写 key 才允许执行变更类 REST 接口。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildCreatePanel(context),
          const SizedBox(height: 14),
          _buildListPanel(context),
          const SizedBox(height: 14),
          _buildAuditPanel(context),
        ],
      ),
    );
  }

  Widget _buildCreatePanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('签发新密钥', style: theme.textTheme.titleSmall)),
              TextButton.icon(
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _displayNameController,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '例如 CI deploy / data export / internal bot',
            ),
          ),
          const SizedBox(height: 8),
          Text('权限', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip(
                label: '只读',
                selected: _scope == ApiKeyScopeV1.readOnly,
                onSelected: () {
                  setState(() {
                    _scope = ApiKeyScopeV1.readOnly;
                  });
                },
              ),
              _choiceChip(
                label: '读写',
                selected: _scope == ApiKeyScopeV1.readWrite,
                onSelected: () {
                  setState(() {
                    _scope = ApiKeyScopeV1.readWrite;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('过期策略', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip(
                label: '不过期',
                selected: _expiryPreset == _ExpiryPreset.none,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.none;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: '7 天',
                selected: _expiryPreset == _ExpiryPreset.sevenDays,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.sevenDays;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: '30 天',
                selected: _expiryPreset == _ExpiryPreset.thirtyDays,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.thirtyDays;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: '90 天',
                selected: _expiryPreset == _ExpiryPreset.ninetyDays,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.ninetyDays;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: _customExpiryDate == null
                    ? '自定义日期'
                    : _fmtDate(_customExpiryDate!),
                selected: _expiryPreset == _ExpiryPreset.custom,
                onSelected: _pickCustomCreateExpiry,
              ),
            ],
          ),
          if (_expiryPreset == _ExpiryPreset.custom &&
              _customExpiryDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '将于 ${_fmtDate(_customExpiryDate!)} 23:59 UTC 过期',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: widget.controller.creating ? null : _createKey,
            icon: widget.controller.creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.key_outlined),
            label: Text(widget.controller.creating ? '签发中…' : '创建 API key'),
          ),
          if (widget.controller.latestPlaintextToken != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('一次性明文', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '这个 secret 只会显示这一次。请立刻复制到凭据管理器、CI secret 或你的集成配置里。',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(widget.controller.latestPlaintextToken!),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copyText(
                          widget.controller.latestPlaintextToken!,
                          '已复制一次性明文 API key',
                        ),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: const Text('复制明文'),
                      ),
                      TextButton(
                        onPressed: widget.controller.clearLatestPlaintextToken,
                        child: const Text('隐藏'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('现有密钥', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('active ${widget.controller.activeCount}')),
              Chip(label: Text('revoked ${widget.controller.revokedCount}')),
              Chip(label: Text('total ${widget.controller.items.length}')),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.controller.loading)
            const Center(child: CircularProgressIndicator())
          else if (widget.controller.items.isEmpty)
            Text(
              '还没有 API key。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...widget.controller.items.map(
              (item) => _buildKeyCard(context, item),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyCard(BuildContext context, ApiKeyRecordV1 item) {
    final busy = widget.controller.busyKeyId == item.id;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.displayName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(item.isUsable ? '可用' : '不可用'),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(item.isActive ? 'active' : 'revoked'),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (item.isExpired)
                          const Chip(
                            label: Text('expired'),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(
                            item.scope == ApiKeyScopeV1.readOnly ? '只读' : '读写',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '复制 publicId',
                onPressed: () => _copyText(item.publicId, '已复制 publicId'),
                icon: const Icon(Icons.tag_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(item.keyHint),
          const SizedBox(height: 4),
          Text(
            'publicId: ${item.publicId}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '创建 ${_fmt(item.createdAt)} · 更新 ${_fmt(item.updatedAt)} · 使用 ${item.useCount} 次',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.lastUsedAt != null)
            Text(
              '最近使用 ${_fmt(item.lastUsedAt!)} · ${item.lastUsedMethod ?? ''} ${item.lastUsedPath ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.lastUsedIp != null || item.lastUsedUserAgent != null)
            Text(
              '来源 ${item.lastUsedIp ?? 'unknown'}${item.lastUsedUserAgent == null ? '' : ' · ${item.lastUsedUserAgent}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.expiresAt != null)
            Text(
              '过期时间 ${_fmt(item.expiresAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.rotatedAt != null)
            Text(
              '最近轮换 ${_fmt(item.rotatedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.revokedAt != null)
            Text(
              '撤销时间 ${_fmt(item.revokedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: busy ? null : () => _showRotateDialog(item),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
                label: const Text('轮换'),
              ),
              if (item.isActive)
                OutlinedButton(
                  onPressed: busy ? null : () => _showRevokeDialog(item),
                  child: const Text('撤销'),
                )
              else
                OutlinedButton(
                  onPressed: busy || item.isExpired
                      ? null
                      : () => widget.controller.activateKey(item.id),
                  child: Text(item.isExpired ? '已过期，需轮换' : '恢复'),
                ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('删除 API key'),
                            content: SelectableText(
                              '即将删除 ${item.displayName}\n${item.keyHint}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await widget.controller.deleteKey(item.id);
                        }
                      },
                child: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('管理审计', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (widget.controller.auditItems.isEmpty)
            Text(
              '还没有 API key 生命周期记录。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...widget.controller.auditItems.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.eventSummary, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${item.eventType} · ${_fmt(item.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.metadata.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: item.metadata.entries
                            .map(
                              (entry) => Chip(
                                label: Text(
                                  '${entry.key}: ${_metadataValue(entry.value)}',
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  ChoiceChip _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  String _metadataValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is List) {
      return value.join(', ');
    }
    return '$value';
  }

  String _fmtDate(DateTime raw) {
    final mm = raw.month.toString().padLeft(2, '0');
    final dd = raw.day.toString().padLeft(2, '0');
    return '${raw.year}-$mm-$dd';
  }

  String _fmt(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return raw;
    }
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$mm-$dd $hh:$min';
  }
}

String? _expiryToIso(_ExpiryPreset preset, DateTime? customDate) {
  final now = DateTime.now().toUtc();
  final target = switch (preset) {
    _ExpiryPreset.none => null,
    _ExpiryPreset.sevenDays => now.add(const Duration(days: 7)),
    _ExpiryPreset.thirtyDays => now.add(const Duration(days: 30)),
    _ExpiryPreset.ninetyDays => now.add(const Duration(days: 90)),
    _ExpiryPreset.custom =>
      customDate == null
          ? null
          : DateTime.utc(
              customDate.year,
              customDate.month,
              customDate.day,
              23,
              59,
              59,
            ),
  };
  if (target == null) {
    return null;
  }
  return DateTime.utc(
    target.year,
    target.month,
    target.day,
    23,
    59,
    59,
  ).toIso8601String();
}
