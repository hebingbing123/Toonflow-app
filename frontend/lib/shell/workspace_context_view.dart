import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/billing_l10n_helpers.dart';
import '../rust_api.dart';

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
    this.compact = false,
  });

  final bool loading;

  /// Single-line bar for Studio compact shell (billing in expansion).
  final bool compact;
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final width = MediaQuery.sizeOf(context).width;
    final workspaceLine = loading
        ? l10n.workspaceContextLoading
        : (workspaceName?.trim().isNotEmpty == true
              ? workspaceName!.trim()
              : l10n.workspaceContextNoWorkspace);
    final scopeLine = projectLabel?.trim().isNotEmpty == true
        ? projectLabel!.trim()
        : l10n.workspaceContextNoProject;

    if (compact) {
      final showBilling =
          billingScope == 'workspace' && workspacePlanTier != null;
      final useExpandedDesktopLayout = width >= 1500;
      if (useExpandedDesktopLayout) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.workspaces_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          workspaceLine,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  _CompactMetaChip(
                    icon: Icons.folder_open_outlined,
                    label: scopeLine,
                  ),
                  if (workspaceType?.trim().isNotEmpty == true)
                    Chip(
                      label: Text(workspaceType!.trim()),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  if (showBilling)
                    _CompactMetaChip(
                      icon: Icons.account_balance_wallet_outlined,
                      label:
                          '${planTierDisplayName(l10n, workspacePlanTier)} · '
                          '${workspaceJobsToday ?? 0}/${workspaceDailyJobQuota ?? l10n.workspaceBillingUnlimited}',
                    ),
                ],
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            initiallyExpanded: false,
            title: Row(
              children: <Widget>[
                Icon(
                  Icons.workspaces_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$workspaceLine · $scopeLine',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (workspaceType?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text(workspaceType!.trim()),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            children: showBilling
                ? <Widget>[_buildWorkspaceBillingInfo(context, l10n)]
                : const <Widget>[],
          ),
        ),
      );
    }

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
    final quotaText = quota == null ? l10n.workspaceBillingUnlimited : '$quota';
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
                      planTierDisplayName(l10n, workspacePlanTier),
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

class _CompactMetaChip extends StatelessWidget {
  const _CompactMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
