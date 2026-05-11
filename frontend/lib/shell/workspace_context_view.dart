import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class WorkspaceContextView extends StatelessWidget {
  const WorkspaceContextView({
    super.key,
    required this.loading,
    this.workspaceName,
    this.workspaceType,
    this.projectLabel,
    this.billingScope,
    this.workspacePlanTier,
    this.workspaceDailyJobQuota,
    this.workspaceJobsToday,
  });

  final bool loading;
  final String? workspaceName;
  final String? workspaceType;
  final String? projectLabel;
  final String? billingScope;
  final String? workspacePlanTier;
  final int? workspaceDailyJobQuota;
  final int? workspaceJobsToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final workspaceLine = loading
        ? l10n.workspaceContextLoading
        : (workspaceName?.trim().isNotEmpty == true
              ? workspaceName!.trim()
              : l10n.workspaceContextNoWorkspace);
    final scopeLine = projectLabel?.trim().isNotEmpty == true
        ? projectLabel!.trim()
        : l10n.workspaceContextNoProject;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.workspaces_outline, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          workspaceLine,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(scopeLine, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (workspaceType?.trim().isNotEmpty == true) ...<Widget>[
                    const SizedBox(width: 12),
                    Chip(
                      label: Text(workspaceType!.trim()),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
              // Display workspace billing when billing_scope = workspace (Task 6.2)
              if (billingScope == 'workspace' && workspacePlanTier != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildWorkspaceBillingInfo(context, l10n),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceBillingInfo(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final quota = workspaceDailyJobQuota;
    final today = workspaceJobsToday ?? 0;
    final quotaText =
        quota == null ? l10n.workspaceBillingUnlimited : '$quota';
    final usagePercent = quota != null && quota > 0
        ? (today / quota * 100).clamp(0, 100).toStringAsFixed(0)
        : '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.workspaceBillingTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.workspaceBillingPlan(
                      workspacePlanTier ?? l10n.workspaceBillingUnknownTier,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.workspaceBillingDailyQuota(quotaText),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$today / $quotaText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.workspaceBillingPercentUsed(usagePercent),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (quota != null && quota > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (today / quota).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                today >= quota
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

