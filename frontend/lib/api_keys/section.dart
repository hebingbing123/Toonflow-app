import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';
import 'package:flutter/services.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../l10n/app_localizations.dart';
import '../l10n/studio_code_labels.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'controller.dart';
import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/components/studio_text_styles.dart';
import 'package:openflow_app/design_system/tokens.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
    final l10n = resolveAppLocalizationsForErrors(context);
    var expiryPreset = _ExpiryPreset.none;
    DateTime? customDate;
    final action = await showStudioDialog<String>(
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

            return StudioAlertDialog(
              title: Text(l10n.apiKeysRotateTitle(item.displayName)),
              content: SizedBox(
                width: studioConstrainedDialogWidth(context, maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.apiKeysRotateBody,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: StudioSpacing.sm),
                    Text(
                      l10n.apiKeysExpiryPolicy,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    Wrap(
                      spacing: StudioSpacing.xs,
                      runSpacing: StudioSpacing.xs,
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
                      const SizedBox(height: StudioSpacing.xs),
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
                  style: studioFormPrimaryButtonStyle(context),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final reasonController = TextEditingController();
    try {
      final confirmed = await showStudioDialog<bool>(
        context: context,
        builder: (context) => StudioAlertDialog(
          title: Text(l10n.apiKeysRevokeTitle(item.displayName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.apiKeysRevokeBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: StudioSpacing.sm),
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
              style: studioFormPrimaryButtonStyle(context),
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

  Widget _buildStudioHeader(BuildContext context, AppLocalizations l10n) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: studioShadowColor(context, alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.apiKeysSectionTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.apiKeysRiskyPrefsTooltip,
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(l10n.apiKeysIntroBody, style: studioSectionIntroStyle(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Padding(
          padding: EdgeInsets.only(top: compact ? StudioSpacing.radiusComfort : StudioSpacing.sm),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildStudioHeader(context, l10n),
                SizedBox(height: compact ? 10 : StudioLayoutSpacing.stackMedium),
                _buildCreatePanel(context, l10n, compact: compact),
                SizedBox(height: compact ? 12 : 14),
                _buildListPanel(context, l10n, compact: compact),
                SizedBox(height: compact ? 12 : 14),
                _buildAuditPanel(context, l10n, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreatePanel(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final panelPadding = compact ? 14.0 : 16.0;
    final refreshButton = compact
        ? IconButton(
            tooltip: l10n.apiKeysRefresh,
            onPressed: widget.controller.loading
                ? null
                : widget.controller.refresh,
            icon: const Icon(Icons.refresh, size: 20),
          )
        : TextButton.icon(
            onPressed: widget.controller.loading
                ? null
                : widget.controller.refresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.apiKeysRefresh),
          );
    final createButton = FilledButton.tonalIcon(
      style: studioFormIconLabeledButtonStyle(context),
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
    );

    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(panelPadding),
        child: StudioCollapsibleFilterPanel(
        collapsible: true,
        title: l10n.apiKeysCreateNewTitle,
        subtitle: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(alignment: Alignment.centerRight, child: refreshButton),
            const SizedBox(height: StudioSpacing.xs),
          TextField(
            controller: _displayNameController,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.apiKeysDisplayNameLabel,
              hintText: l10n.apiKeysDisplayNameHint,
            ),
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(l10n.apiKeysPermissionTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
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
          const SizedBox(height: StudioSpacing.sm),
          Text(l10n.apiKeysExpiryPolicy, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
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
              padding: const EdgeInsets.only(top: StudioSpacing.xs),
              child: Text(
                l10n.apiKeysExpiresAtUtc(_fmtDate(_customExpiryDate!)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StudioTokens.of(context).textSecondary,
                ),
              ),
            ),
          SizedBox(height: compact ? 10 : 12),
          if (compact)
            SizedBox(width: double.infinity, child: createButton)
          else
            createButton,
          if (widget.controller.latestPlaintextToken != null) ...[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
              decoration: BoxDecoration(
                color: StudioTokens.of(context).accentSoft.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.apiKeysPlaintextOnceTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: StudioLayoutSpacing.titleTight),
                  Text(
                    l10n.apiKeysPlaintextOnceBody,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: StudioLayoutSpacing.inlineGap),
                  SelectableText(widget.controller.latestPlaintextToken!),
                  const SizedBox(height: StudioSpacing.xs),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copyText(
                            widget.controller.latestPlaintextToken!,
                            l10n.apiKeysCopiedPlaintextSnack,
                          ),
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: Text(l10n.apiKeysCopyPlaintext),
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        TextButton(
                          onPressed:
                              widget.controller.clearLatestPlaintextToken,
                          child: Text(l10n.apiKeysHidePlaintext),
                        ),
                      ],
                    )
                  else
                    StudioDenseActionRow(
                      spacing: StudioSpacing.xs,
                      children: [
                        OutlinedButton.icon(
                          style: studioFormOutlinedIconLabeledButtonStyle(context),
                          onPressed: () => _copyText(
                            widget.controller.latestPlaintextToken!,
                            l10n.apiKeysCopiedPlaintextSnack,
                          ),
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: Text(l10n.apiKeysCopyPlaintext),
                        ),
                        TextButton(
                          onPressed:
                              widget.controller.clearLatestPlaintextToken,
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
      ),
      ),
    );
  }

  Widget _buildListPanel(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? StudioLayoutSpacing.stackMedium : StudioSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.apiKeysExistingKeysTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Wrap(
              spacing: StudioSpacing.xs,
              runSpacing: StudioSpacing.xs,
              children: <Widget>[
                StudioChip(
                  label: Text(
                    l10n.apiKeysStatActive(widget.controller.activeCount),
                  ),
                ),
                StudioChip(
                  label: Text(
                    l10n.apiKeysStatRevoked(widget.controller.revokedCount),
                  ),
                ),
                StudioChip(
                  label: Text(
                    l10n.apiKeysStatTotal(widget.controller.items.length),
                  ),
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            StudioAsyncDataView(
              loading: widget.controller.loading,
              isEmpty: widget.controller.items.isEmpty,
              empty: StudioEmptyState.emptyData(
                title: l10n.apiKeysEmptyList,
                icon: Icons.vpn_key_outlined,
              ),
              child: Column(
                children: widget.controller.items
                    .map(
                      (item) => _buildKeyCard(
                        context,
                        l10n,
                        item,
                        compact: compact,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyCard(
    BuildContext context,
    AppLocalizations l10n,
    ApiKeyRecordV1 item, {
    required bool compact,
  }) {
    final busy = widget.controller.busyKeyId == item.id;
    final theme = Theme.of(context);
    final primaryAction = FilledButton.tonalIcon(
      style: studioFormIconLabeledButtonStyle(context),
      onPressed: busy ? null : () => _showRotateDialog(item),
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_outlined),
      label: Text(l10n.apiKeysActionRotate),
    );
    final stateAction = item.isActive
        ? OutlinedButton(
            style: studioFormSecondaryButtonStyle(context),
            onPressed: busy ? null : () => _showRevokeDialog(item),
            child: Text(l10n.apiKeysActionRevoke),
          )
        : OutlinedButton(
            style: studioFormSecondaryButtonStyle(context),
            onPressed: busy || item.isExpired
                ? null
                : () => widget.controller.activateKey(item.id),
            child: Text(
              item.isExpired
                  ? l10n.apiKeysExpiredNeedsRotate
                  : l10n.apiKeysRestore,
            ),
          );
    final deleteAction = OutlinedButton(
      style: studioFormSecondaryButtonStyle(context),
      onPressed: busy
          ? null
          : () async {
              final confirmed = await showStudioDialog<bool>(
                context: context,
                builder: (context) => StudioAlertDialog(
                  title: Text(l10n.apiKeysDeleteTitle),
                  content: SelectableText(
                    l10n.apiKeysDeleteBody(item.displayName, item.keyHint),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.globalSearchCancel),
                    ),
                    FilledButton(
                      style: studioFormPrimaryButtonStyle(context),
                      onPressed: () => Navigator.of(context).pop(true),
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
    );

    return Container(
      margin: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      padding: EdgeInsets.all(compact ? StudioLayoutSpacing.inlineGap : StudioLayoutSpacing.insetDense),
      decoration: BoxDecoration(
        border: Border.all(color: studioPanelBorderColor(context)),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
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
                    const SizedBox(height: StudioLayoutSpacing.titleTight),
                    Wrap(
                      spacing: StudioSpacing.xs,
                      runSpacing: StudioSpacing.xs,
                      children: [
                        StudioChip(
                          label: Text(
                            item.isUsable
                                ? l10n.apiKeysChipUsable
                                : l10n.apiKeysChipUnusable,
                          ),
                        ),
                        StudioChip(
                          label: Text(
                            item.isActive
                                ? l10n.apiKeysChipActive
                                : l10n.apiKeysChipRevoked,
                          ),
                        ),
                        if (item.isExpired)
                          StudioChip(
                            label: Text(l10n.apiKeysChipExpired),
                          ),
                        StudioChip(
                          label: Text(
                            item.scope == ApiKeyScopeV1.readOnly
                                ? l10n.apiKeysScopeReadOnly
                                : l10n.apiKeysScopeReadWrite,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                style: studioUtilityIconButtonStyle(context),
                tooltip: l10n.apiKeysCopyPublicIdTooltip,
                onPressed: () =>
                    _copyText(item.publicId, l10n.apiKeysCopiedPublicIdSnack),
                icon: const Icon(Icons.tag_outlined),
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
          SelectableText(item.keyHint),
          const SizedBox(height: StudioLayoutSpacing.titleTight),
          Text(
            l10n.apiKeysPublicIdLine(item.publicId),
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleTight),
          Text(
            l10n.apiKeysMetaLine(
              _fmt(item.createdAt),
              _fmt(item.updatedAt),
              item.useCount,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: StudioTokens.of(context).textSecondary,
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
                color: StudioTokens.of(context).textSecondary,
              ),
            ),
          if (item.lastUsedIp != null || item.lastUsedUserAgent != null)
            Text(
              l10n.apiKeysSourceLine(
                '${studioApiKeysLastUsedLabel(l10n, item.lastUsedIp ?? '')}${item.lastUsedUserAgent == null ? '' : ' · ${item.lastUsedUserAgent}'}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.expiresAt != null)
            Text(
              l10n.apiKeysExpiresAtLine(_fmt(item.expiresAt!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
              ),
            ),
          if (item.rotatedAt != null)
            Text(
              l10n.apiKeysRotatedAtLine(_fmt(item.rotatedAt!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
              ),
            ),
          if (item.revokedAt != null)
            Text(
              l10n.apiKeysRevokedAtLine(_fmt(item.revokedAt!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
              ),
            ),
          const SizedBox(height: StudioSpacing.xs),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primaryAction,
                const SizedBox(height: StudioSpacing.xs),
                stateAction,
                const SizedBox(height: StudioSpacing.xs),
                deleteAction,
              ],
            )
          else
            StudioDenseActionRow(
              spacing: StudioSpacing.xs,
              children: [primaryAction, stateAction, deleteAction],
            ),
        ],
      ),
    );
  }

  Widget _buildAuditPanel(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(
          compact ? StudioLayoutSpacing.stackMedium : StudioSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.apiKeysAuditTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: StudioSpacing.xs),
          if (widget.controller.auditItems.isEmpty)
            StudioEmptyState.emptyData(
              title: l10n.apiKeysAuditEmpty,
              icon: Icons.history_outlined,
            )
          else
            ...studioStaggeredChildren(
              widget.controller.auditItems.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: StudioSpacing.xs),
                  padding: EdgeInsets.all(
                    compact
                        ? StudioLayoutSpacing.inlineGap
                        : StudioLayoutSpacing.insetDense,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: studioPanelBorderColor(context)),
                    borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.eventSummary, style: theme.textTheme.titleSmall),
                      const SizedBox(height: StudioLayoutSpacing.titleTight),
                      Text(
                        '${item.eventType} · ${_fmt(item.createdAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StudioTokens.of(context).textSecondary,
                        ),
                      ),
                      if (item.metadata.isNotEmpty) ...[
                        const SizedBox(height: StudioSpacing.xs),
                        Wrap(
                          spacing: StudioSpacing.xs,
                          runSpacing: StudioSpacing.xs,
                          children: studioStaggeredChildren(
                            item.metadata.entries.map(
                              (entry) => StudioChip(
                                label: Text(
                                  '${entry.key}: ${_metadataValue(entry.value)}',
                                ),
                              ),
                            ),
                            entranceKey: item.metadata.length,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              entranceKey: widget.controller.auditItems.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return StudioChoiceChip(
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
