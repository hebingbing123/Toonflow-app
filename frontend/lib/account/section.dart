import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  Future<void> _deleteAccount() async {
    final response = await widget.controller.deleteAccount(
      confirmPhrase: _confirmController.text.trim(),
      acknowledgeIrreversible: _acknowledgeIrreversible,
    );
    if (response == null || !mounted) {
      return;
    }
    await widget.onAccountDeleted(response);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final canDelete =
        _acknowledgeIrreversible &&
        _confirmController.text.trim() == 'DELETE MY ACCOUNT' &&
        !widget.controller.deletingAccount;
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
                  l10n.accountSectionTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.accountRiskyPrefsTooltip,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.accountSectionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildExportPanel(context),
          const SizedBox(height: 14),
          _buildDeletePanel(context, canDelete),
        ],
      ),
    );
  }

  Widget _buildExportPanel(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
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
                  l10n.accountExportTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.notificationsRefresh),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
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
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: widget.controller.includeAuditLogs,
                onSelected: widget.controller.setIncludeAuditLogs,
                label: Text(l10n.accountExportIncludeAuditLogs),
              ),
              FilterChip(
                selected: widget.controller.includeNotifications,
                onSelected: widget.controller.setIncludeNotifications,
                label: Text(l10n.accountExportIncludeNotifications),
              ),
              Chip(
                label: Text(
                  l10n.accountExportActiveCount(widget.controller.activeCount),
                ),
              ),
              if (widget.controller.lastSavedPath != null)
                ActionChip(
                  label: Text(l10n.accountExportCopyLastSavedPath),
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: widget.controller.lastSavedPath!),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.controller.loading)
            const Center(child: CircularProgressIndicator())
          else if (widget.controller.items.isEmpty)
            Text(
              l10n.accountExportEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...widget.controller.items.map(
              (item) => _buildExportRow(context, item),
            ),
        ],
      ),
    );
  }

  Widget _buildExportRow(BuildContext context, AccountExportJobRecordV1 item) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final downloading = widget.controller.isDownloading(item.id);
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
            children: [
              Expanded(
                child: Text(
                  item.fileName ??
                      l10n.accountExportDefaultFileName(item.numericTaskId),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Chip(label: Text(_statusLabel(item.status))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.accountExportTaskLine(
              item.numericTaskId,
              _formatDateTime(item.createdAt),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.byteSize != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.accountExportSizeLine(_formatBytes(item.byteSize!)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (item.errorMessage != null &&
              item.errorMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.downloadReady)
                FilledButton.tonalIcon(
                  onPressed: downloading
                      ? null
                      : () async {
                          final path = await widget.controller.downloadExport(
                            item,
                          );
                          if (!context.mounted || path == null) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.accountExportSavedSnack(path)),
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
                TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: item.fileName!)),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: Text(l10n.accountExportCopyFileName),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeletePanel(BuildContext context, bool canDelete) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountDeleteTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(l10n.accountDeleteDescription, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.accountDeleteConfirmLabel,
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acknowledgeIrreversible,
            onChanged: (value) {
              setState(() {
                _acknowledgeIrreversible = value ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.accountDeleteIrreversibleAck),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (widget.controller.lastDeleteResponse != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.accountDeleteLastResponse(
                widget.controller.lastDeleteResponse!.ownedWorkspaceCount,
                widget.controller.lastDeleteResponse!.ownedProjectCount,
                widget.controller.lastDeleteResponse!.generationJobCount,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton(
            onPressed: canDelete ? _deleteAccount : null,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: widget.controller.deletingAccount
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.accountDeleteButton),
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

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
