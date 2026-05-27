import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';
import 'package:flutter/services.dart';

import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_skeleton.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../design_system/studio_motion.dart';
import '../l10n/app_localizations.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import '../utils/localized_formatting.dart';
import 'controller.dart';

class AccountSection extends StatefulWidget {
  const AccountSection({
    super.key,
    required this.controller,
    required this.onAccountDeleted,
  });

  final AccountController controller;
  final Future<void> Function(AccountDeleteResponseV1 response)
  onAccountDeleted;

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  static const String _deleteConfirmPhrase = 'DELETE MY ACCOUNT';

  final _confirmController = TextEditingController();
  bool _acknowledgeIrreversible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    widget.controller.prime();
  }

  @override
  void didUpdateWidget(covariant AccountSection oldWidget) {
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
    _confirmController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
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
                    l10n.accountSectionTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.accountRiskyPrefsTooltip,
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(l10n.accountSectionSubtitle, style: studioSectionIntroStyle(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final response = await widget.controller.deleteAccount(
      confirmPhrase: _deletePhraseMatches(_confirmController.text)
          ? _deleteConfirmPhrase
          : _confirmController.text.trim(),
      acknowledgeIrreversible: _acknowledgeIrreversible,
    );
    if (response == null || !mounted) {
      return;
    }
    await widget.onAccountDeleted(response);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final canDelete =
        _acknowledgeIrreversible &&
        _deletePhraseMatches(_confirmController.text) &&
        !widget.controller.deletingAccount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1080;
        final comfortable = constraints.maxWidth >= 720;
        final panels = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 11,
                    child: _buildExportPanel(context, comfortable: comfortable),
                  ),
                  SizedBox(width: comfortable ? 18 : 14),
                  Expanded(
                    flex: 9,
                    child: _buildDeletePanel(
                      context,
                      canDelete,
                      comfortable: comfortable,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildExportPanel(context, comfortable: comfortable),
                  SizedBox(height: comfortable ? 18 : 14),
                  _buildDeletePanel(
                    context,
                    canDelete,
                    comfortable: comfortable,
                  ),
                ],
              );

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildStudioHeader(context, l10n),
                SizedBox(height: comfortable ? 16 : StudioLayoutSpacing.stackMedium),
                panels,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportPanel(BuildContext context, {required bool comfortable}) {
    final l10n = resolveAppLocalizationsForErrors(context);

    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: EdgeInsets.all(
          comfortable ? StudioLayoutSpacing.insetComfortable : StudioSpacing.sm,
        ),
        child: LayoutBuilder(
        builder: (context, constraints) {
          final stackHeader = constraints.maxWidth < 720;
          final headerDetails = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.accountExportTitle,
                style: studioCardTitleStyle(context),
              ),
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StudioChip(
                    label: Text(
                      l10n.accountExportActiveCount(
                        widget.controller.activeCount,
                      ),
                    ),
                  ),
                  if (widget.controller.lastSavedPath != null)
                    StudioActionChip(
                      label: Text(l10n.accountExportCopyLastSavedPath),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: widget.controller.lastSavedPath!),
                      ),
                    ),
                ],
              ),
            ],
          );
          final actions = StudioDenseActionRow(
            spacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                style: studioFormOutlinedIconLabeledButtonStyle(context),
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.notificationsRefresh),
              ),
              FilledButton.tonalIcon(
                style: studioFormIconLabeledButtonStyle(context),
                onPressed: widget.controller.creatingExport
                    ? null
                    : widget.controller.requestExport,
                icon: widget.controller.creatingExport
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined),
                label: Text(l10n.accountExportCreate),
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (stackHeader) ...<Widget>[
                headerDetails,
                const SizedBox(height: StudioLayoutSpacing.stackMedium),
                actions,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: headerDetails),
                    const SizedBox(width: 16),
                    Flexible(child: actions),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  StudioFilterChip(
                    selected: widget.controller.includeAuditLogs,
                    onSelected: widget.controller.setIncludeAuditLogs,
                    label: Text(l10n.accountExportIncludeAuditLogs),
                  ),
                  StudioFilterChip(
                    selected: widget.controller.includeNotifications,
                    onSelected: widget.controller.setIncludeNotifications,
                    label: Text(l10n.accountExportIncludeNotifications),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.controller.loading)
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    StudioSkeleton(height: 18),
                    SizedBox(height: StudioSpacing.sm),
                    StudioSkeleton(height: 56),
                    SizedBox(height: StudioSpacing.sm),
                    StudioSkeleton(height: 56),
                  ],
                )
              else if (widget.controller.items.isEmpty)
                StudioEmptyState.emptyData(
                  title: l10n.accountExportEmpty,
                  icon: Icons.cloud_download_outlined,
                )
              else
                ...widget.controller.items.map(
                  (item) => _buildExportRow(context, item),
                ),
            ],
          );
        },
        ),
      ),
    );
  }

  Widget _buildExportRow(BuildContext context, AccountExportJobRecordV1 item) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final downloading = widget.controller.isDownloading(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      decoration: studioInsetPanelDecoration(
        context,
        backgroundColor: tokens.bgElevated.withValues(alpha: 0.72),
        borderRadius: StudioSpacing.radiusCard,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackedHeader = constraints.maxWidth < 460;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (stackedHeader) ...<Widget>[
                Text(
                  item.fileName ??
                      l10n.accountExportDefaultFileName(item.numericTaskId),
                  style: studioCardTitleStyle(context),
                ),
                const SizedBox(height: 8),
                StudioChip(label: Text(_statusLabel(item.status))),
              ] else
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.fileName ??
                            l10n.accountExportDefaultFileName(
                              item.numericTaskId,
                            ),
                        style: studioCardTitleStyle(context),
                      ),
                    ),
                    const SizedBox(width: StudioLayoutSpacing.inlineGap),
                    StudioChip(label: Text(_statusLabel(item.status))),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                l10n.accountExportTaskLine(
                  item.numericTaskId,
                  _formatDateTime(item.createdAt),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: StudioTokens.of(context).textSecondary,
                ),
              ),
              if (item.byteSize != null) ...<Widget>[
                const SizedBox(height: StudioLayoutSpacing.titleTight),
                Text(
                  l10n.accountExportSizeLine(
                    _formatBytes(context, item.byteSize!),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ),
              ],
              if (item.errorMessage != null &&
                  item.errorMessage!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: StudioLayoutSpacing.titleTight),
                Text(
                  item.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              StudioDenseActionRow(
                spacing: 8,
                children: <Widget>[
                  if (item.downloadReady)
                    FilledButton.tonalIcon(
                      style: studioFormIconLabeledButtonStyle(context),
                      onPressed: downloading
                          ? null
                          : () async {
                              final path = await widget.controller
                                  .downloadExport(item);
                              if (!context.mounted || path == null) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.accountExportSavedSnack(path),
                                  ),
                                ),
                              );
                            },
                      icon: downloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(l10n.accountExportDownload),
                    ),
                  if (item.fileName != null)
                    OutlinedButton.icon(
                      style: studioFormOutlinedIconLabeledButtonStyle(context),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: item.fileName!),
                      ),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: Text(l10n.accountExportCopyFileName),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeletePanel(
    BuildContext context,
    bool canDelete, {
    required bool comfortable,
  }) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 720;
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colorScheme.error.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.accountDeleteTitle,
                    style: studioCardTitleStyle(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.accountDeleteDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
                height: 1.5,
              ),
            ),
            if (widget.controller.lastDeleteResponse != null) ...<Widget>[
              const SizedBox(height: StudioLayoutSpacing.stackMedium),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.24),
                  ),
                  color: tokens.textPrimary.withValues(alpha: 0.03),
                ),
                child: Text(
                  l10n.accountDeleteLastResponse(
                    widget.controller.lastDeleteResponse!.ownedWorkspaceCount,
                    widget.controller.lastDeleteResponse!.ownedProjectCount,
                    widget.controller.lastDeleteResponse!.generationJobCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ],
        );
        final form = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: split ? 360 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildDeleteConfirmPrompt(context, l10n),
              const SizedBox(height: StudioSpacing.sm),
              TextField(
                controller: _confirmController,
                onChanged: (_) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textCapitalization: TextCapitalization.characters,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 0.2,
                ),
                decoration: InputDecoration(
                  hintText: _deleteConfirmPhrase,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: StudioTokens.of(context).textSecondary.withValues(
                      alpha: 0.68,
                    ),
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: StudioSpacing.sm),
              _buildAcknowledgeTile(context, l10n),
              const SizedBox(height: StudioSpacing.sm),
              SizedBox(
                width: split ? null : double.infinity,
                child: FilledButton.icon(
                  onPressed: canDelete ? _deleteAccount : null,
                  style: studioFormDestructiveIconLabeledButtonStyle(context),
                  icon: widget.controller.deletingAccount
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever_outlined),
                  label: Text(l10n.accountDeleteButton),
                ),
              ),
            ],
          ),
        );

        return DecoratedBox(
          decoration:
              studioInsetPanelDecoration(context).copyWith(
                borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    tokens.bgSurface.withValues(alpha: 0.98),
                    tokens.bgInset.withValues(alpha: 0.96),
                    theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                  ],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.colorScheme.error.withValues(alpha: 0.05),
                    blurRadius: 20,
                    spreadRadius: -14,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
          child: Padding(
            padding: EdgeInsets.all(
              comfortable
                  ? StudioLayoutSpacing.insetComfortable
                  : StudioSpacing.sm,
            ),
            child: split
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 11, child: summary),
                    const SizedBox(width: StudioSpacing.sm),
                    Expanded(
                      flex: 9,
                      child: Align(alignment: Alignment.topRight, child: form),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    summary,
                    const SizedBox(height: StudioLayoutSpacing.stackMedium),
                    form,
                  ],
                ),
          ),
        );
      },
    );
  }

  Widget _buildAcknowledgeTile(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);

    void setAcknowledged(bool value) {
      setState(() {
        _acknowledgeIrreversible = value;
      });
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setAcknowledged(!_acknowledgeIrreversible),
        child: AnimatedContainer(
          duration: studioAnimationDuration(
            context,
            const Duration(milliseconds: 220),
          ),
          curve: studioAnimationCurve(context, Curves.easeOutCubic),
          padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _acknowledgeIrreversible
                  ? theme.colorScheme.error.withValues(alpha: 0.42)
                  : tokens.borderSubtle.withValues(alpha: 0.55),
            ),
            color: _acknowledgeIrreversible
                ? theme.colorScheme.error.withValues(alpha: 0.08)
                : tokens.textPrimary.withValues(alpha: 0.02),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: _acknowledgeIrreversible,
                onChanged: (value) => setAcknowledged(value ?? false),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
              const SizedBox(width: StudioSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: StudioLayoutSpacing.microGap),
                  child: Text(
                    l10n.accountDeleteIrreversibleAck,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmPrompt(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final prompt = l10n.accountDeleteConfirmLabel;
    final parts = prompt.split(_deleteConfirmPhrase);
    final prefix = parts.first.trim();
    final suffix = parts.length > 1
        ? parts.sublist(1).join(_deleteConfirmPhrase).trim()
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.18),
        ),
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.08),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (prefix.isNotEmpty)
            Text(
              prefix,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
                height: 1.4,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioLayoutSpacing.inlineGap,
              vertical: StudioLayoutSpacing.microGap,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.24),
              ),
              color: theme.colorScheme.surface.withValues(alpha: 0.84),
            ),
            child: Text(
              _deleteConfirmPhrase,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFamily: 'monospace',
                letterSpacing: 0.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (suffix.isNotEmpty)
            Text(
              suffix,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).textSecondary,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    final l10n = resolveAppLocalizationsForErrors(context);
    switch (status) {
      case 'queued':
        return l10n.accountExportStatusQueued;
      case 'running':
        return l10n.accountExportStatusRunning;
      case 'succeeded':
        return l10n.accountExportStatusSucceeded;
      case 'failed':
        return l10n.accountExportStatusFailed;
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime value) {
    return LocalizedFormatting.formatShortDateTime(context, value);
  }

  bool _deletePhraseMatches(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ') ==
        _deleteConfirmPhrase;
  }

  String _formatBytes(BuildContext context, int bytes) {
    return LocalizedFormatting.formatFileSize(context, bytes);
  }
}
