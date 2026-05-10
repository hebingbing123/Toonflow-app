import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
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
                  '账户与隐私',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: '本机客户端偏好（删号、导出等「不再提示」与恢复确认）',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '统一管理账户数据导出、下载留档和不可逆删号。导出任务会走平台 job 队列，可反复生成新版快照。',
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
              Expanded(child: Text('数据导出', style: theme.textTheme.titleSmall)),
              TextButton.icon(
                onPressed: widget.controller.loading
                    ? null
                    : widget.controller.refresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
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
                label: const Text('创建导出包'),
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
                label: const Text('包含审计日志'),
              ),
              FilterChip(
                selected: widget.controller.includeNotifications,
                onSelected: widget.controller.setIncludeNotifications,
                label: const Text('包含通知记录'),
              ),
              Chip(label: Text('进行中 ${widget.controller.activeCount}')),
              if (widget.controller.lastSavedPath != null)
                ActionChip(
                  label: const Text('复制最近保存路径'),
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
              '还没有账户导出记录。',
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
                  item.fileName ?? '账户导出 #${item.numericTaskId}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Chip(label: Text(_statusLabel(item.status))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '任务 #${item.numericTaskId} · ${_formatDateTime(item.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (item.byteSize != null) ...[
            const SizedBox(height: 4),
            Text(
              '大小 ${_formatBytes(item.byteSize!)}',
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
                            SnackBar(content: Text('已保存导出包：$path')),
                          );
                        },
                  icon: downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  label: const Text('下载到本机'),
                ),
              if (item.fileName != null)
                TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: item.fileName!)),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('复制文件名'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeletePanel(BuildContext context, bool canDelete) {
    final theme = Theme.of(context);
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
          Text('删除账号', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            '删号会删除当前用户、其 owner workspace、个人项目、任务、通知和本地导出/媒体目录。共享 workspace 中的成员关系也会移除。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '输入 DELETE MY ACCOUNT 以确认',
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
            title: const Text('我确认这是不可逆操作，并接受相关 workspace / project 级联删除。'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (widget.controller.lastDeleteResponse != null) ...[
            const SizedBox(height: 8),
            Text(
              '最近一次删号响应：workspace ${widget.controller.lastDeleteResponse!.ownedWorkspaceCount} · '
              'project ${widget.controller.lastDeleteResponse!.ownedProjectCount} · '
              'job ${widget.controller.lastDeleteResponse!.generationJobCount}',
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
                : const Text('永久删除当前账号'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'queued':
        return '排队中';
      case 'running':
        return '生成中';
      case 'succeeded':
        return '可下载';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int part) => part.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
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
