import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showSnackBar(l10n.apiKeysSnackFillName);
      return;
    }
    if (_expiryPreset == _ExpiryPreset.custom && _customExpiryDate == null) {
      _showSnackBar(l10n.apiKeysSnackPickExpiry);
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
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      helpText: l10n.apiKeysDatePickerHelp,
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
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(l10n.apiKeysRotateTitle(item.displayName)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.apiKeysRotateBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.apiKeysExpiryPolicy,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip(
                          label: l10n.apiKeysExpiryKeepCurrent,
                          selected: expiryPreset == _ExpiryPreset.none,
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.none;
                            });
                          },
                        ),
                        _choiceChip(
                          label: l10n.apiKeysExpiryClearExpiry,
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
                          label: l10n.apiKeysExpirySevenDays,
                          selected: expiryPreset == _ExpiryPreset.sevenDays,
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.sevenDays;
                              customDate = null;
                            });
                          },
                        ),
                        _choiceChip(
                          label: l10n.apiKeysExpiryThirtyDays,
                          selected: expiryPreset == _ExpiryPreset.thirtyDays,
                          onSelected: () {
                            setDialogState(() {
                              expiryPreset = _ExpiryPreset.thirtyDays;
                              customDate = null;
                            });
                          },
                        ),
                        _choiceChip(
                          label: l10n.apiKeysExpiryCustomDate,
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
                        l10n.apiKeysExpiresAtUtc(_fmtDate(customDate!)),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.globalSearchCancel),
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
                  child: Text(l10n.apiKeysActionRotate),
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
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.apiKeysRevokeTitle(item.displayName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.apiKeysRevokeBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.apiKeysRevokeReasonLabel,
                  hintText: l10n.apiKeysRevokeReasonHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.globalSearchCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.apiKeysActionRevoke),
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
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.apiKeysSectionTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.apiKeysRiskyPrefsTooltip,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.apiKeysIntroBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildCreatePanel(context, l10n),
          const SizedBox(height: 14),
          _buildListPanel(context, l10n),
          const SizedBox(height: 14),
          _buildAuditPanel(context, l10n),
        ],
      ),
    );
  }

  Widget _buildCreatePanel(BuildContext context, AppLocalizations l10n) {
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
              Expanded(
                child: Text(
                  l10n.apiKeysCreateNewTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.apiKeysRefresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _displayNameController,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: l10n.apiKeysDisplayNameLabel,
              hintText: l10n.apiKeysDisplayNameHint,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.apiKeysPermissionTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip(
                label: l10n.apiKeysScopeReadOnly,
                selected: _scope == ApiKeyScopeV1.readOnly,
                onSelected: () {
                  setState(() {
                    _scope = ApiKeyScopeV1.readOnly;
                  });
                },
              ),
              _choiceChip(
                label: l10n.apiKeysScopeReadWrite,
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
          Text(l10n.apiKeysExpiryPolicy, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choiceChip(
                label: l10n.apiKeysExpiryNever,
                selected: _expiryPreset == _ExpiryPreset.none,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.none;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: l10n.apiKeysExpirySevenDays,
                selected: _expiryPreset == _ExpiryPreset.sevenDays,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.sevenDays;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: l10n.apiKeysExpiryThirtyDays,
                selected: _expiryPreset == _ExpiryPreset.thirtyDays,
                onSelected: () {
                  setState(() {
                    _expiryPreset = _ExpiryPreset.thirtyDays;
                    _customExpiryDate = null;
                  });
                },
              ),
              _choiceChip(
                label: l10n.apiKeysExpiryNinetyDays,
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
                    ? l10n.apiKeysExpiryCustomDate
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
                l10n.apiKeysExpiresAtUtc(_fmtDate(_customExpiryDate!)),
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
            label: Text(
              widget.controller.creating
                  ? l10n.apiKeysCreating
                  : l10n.apiKeysCreateButton,
            ),
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
                  Text(
                    l10n.apiKeysPlaintextOnceTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.apiKeysPlaintextOnceBody,
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
                          l10n.apiKeysCopiedPlaintextSnack,
                        ),
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: Text(l10n.apiKeysCopyPlaintext),
                      ),
                      TextButton(
                        onPressed: widget.controller.clearLatestPlaintextToken,
                        child: Text(l10n.apiKeysHidePlaintext),
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

  Widget _buildListPanel(BuildContext context, AppLocalizations l10n) {
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
          Text(l10n.apiKeysExistingKeysTitle, style: theme.textTheme.titleSmall),
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
              l10n.apiKeysEmptyList,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...widget.controller.items.map(
              (item) => _buildKeyCard(context, l10n, item),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyCard(
    BuildContext context,
    AppLocalizations l10n,
    ApiKeyRecordV1 item,
  ) {
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
                          label: Text(
                            item.isUsable
                                ? l10n.apiKeysChipUsable
                                : l10n.apiKeysChipUnusable,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(
                            item.isActive
                                ? l10n.apiKeysChipActive
                                : l10n.apiKeysChipRevoked,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (item.isExpired)
                          Chip(
                            label: Text(l10n.apiKeysChipExpired),
                            visualDensity: VisualDensity.compact,
                          ),
                        Chip(
                          label: Text(
                            item.scope == ApiKeyScopeV1.readOnly
                                ? l10n.apiKeysScopeReadOnly
                                : l10n.apiKeysScopeReadWrite,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.apiKeysCopyPublicIdTooltip,
                onPressed: () =>
                    _copyText(item.publicId, l10n.apiKeysCopiedPublicIdSnack),
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
            l10n.apiKeysMetaLine(
              _fmt(item.createdAt),
              _fmt(item.updatedAt),
              item.useCount,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.lastUsedAt != null)
            Text(
              l10n.apiKeysLastUsedLine(
                _fmt(item.lastUsedAt!),
                item.lastUsedMethod ?? '',
                item.lastUsedPath ?? '',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.lastUsedIp != null || item.lastUsedUserAgent != null)
            Text(
              l10n.apiKeysSourceLine(
                '${item.lastUsedIp ?? 'unknown'}${item.lastUsedUserAgent == null ? '' : ' · ${item.lastUsedUserAgent}'}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.expiresAt != null)
            Text(
              l10n.apiKeysExpiresAtLine(_fmt(item.expiresAt!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.rotatedAt != null)
            Text(
              l10n.apiKeysRotatedAtLine(_fmt(item.rotatedAt!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (item.revokedAt != null)
            Text(
              l10n.apiKeysRevokedAtLine(_fmt(item.revokedAt!)),
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
                label: Text(l10n.apiKeysActionRotate),
              ),
              if (item.isActive)
                OutlinedButton(
                  onPressed: busy ? null : () => _showRevokeDialog(item),
                  child: Text(l10n.apiKeysActionRevoke),
                )
              else
                OutlinedButton(
                  onPressed: busy || item.isExpired
                      ? null
                      : () => widget.controller.activateKey(item.id),
                  child: Text(
                    item.isExpired
                        ? l10n.apiKeysExpiredNeedsRotate
                        : l10n.apiKeysRestore,
                  ),
                ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l10n.apiKeysDeleteTitle),
                            content: SelectableText(
                              l10n.apiKeysDeleteBody(
                                item.displayName,
                                item.keyHint,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(l10n.globalSearchCancel),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(l10n.apiKeysDelete),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await widget.controller.deleteKey(item.id);
                        }
                      },
                child: Text(l10n.apiKeysDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditPanel(BuildContext context, AppLocalizations l10n) {
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
          Text(l10n.apiKeysAuditTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (widget.controller.auditItems.isEmpty)
            Text(
              l10n.apiKeysAuditEmpty,
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
