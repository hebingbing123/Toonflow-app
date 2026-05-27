import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/studio_typography.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../l10n/billing_l10n_helpers.dart';
import '../rust_api.dart';

/// Backend may return the English default even when the UI locale is Chinese.
bool isBackendDefaultPersonalWorkspaceName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final lower = trimmed.toLowerCase();
  return lower == 'personal workspace' || trimmed == '个人工作区';
}

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
    this.inline = false,
    this.embedded = false,
    this.titleBarChrome = false,
    this.titleBarDense = false,
    this.onProjectScopeTap,
  });

  final bool loading;

  /// Single-line bar for Studio compact shell (billing in expansion).
  final bool compact;
  final bool inline;

  /// Inside [StudioPipelineStrip]; skip outer card chrome.
  final bool embedded;

  /// Product shell top title bar (macOS integrated or desktop chrome row).
  final bool titleBarChrome;

  /// Single-line scope summary when title bar width is tight.
  final bool titleBarDense;

  /// When set, the project scope row navigates to the scoped project home (shell).
  final VoidCallback? onProjectScopeTap;
  final String? workspaceName;
  final String? workspaceType;
  final String? projectLabel;
  final String? billingScope;
  final String? workspacePlanTier;
  final int? workspaceDailyJobQuota;
  final int? workspaceJobsToday;

  bool _hasActionableProjectScope(AppLocalizations l10n, String scopeLine) {
    if (onProjectScopeTap == null || loading) {
      return false;
    }
    return scopeLine != l10n.workspaceContextNoProject;
  }

  Widget _wrapProjectScopeTapTarget({
    required BuildContext context,
    required AppLocalizations l10n,
    required StudioTokens tokens,
    required String scopeLine,
    required Widget child,
  }) {
    if (!_hasActionableProjectScope(l10n, scopeLine)) {
      return child;
    }
    return Tooltip(
      message: l10n.projectEditorBasicsHomeSectionTitle,
      waitDuration: const Duration(milliseconds: 350),
      child: InkWell(
        onTap: onProjectScopeTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        hoverColor: tokens.bgInset.withValues(alpha: 0.65),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: child,
        ),
      ),
    );
  }

  Widget _buildTitleBarProjectScopeRow({
    required BuildContext context,
    required ThemeData theme,
    required StudioTokens tokens,
    required AppLocalizations l10n,
    required String scopeLine,
    required double iconSize,
    required double fontSize,
    required Color textColor,
  }) {
    final row = Row(
      children: <Widget>[
        Icon(
          Icons.folder_open_outlined,
          size: iconSize,
          color: _hasActionableProjectScope(l10n, scopeLine)
              ? tokens.accent.withValues(alpha: 0.9)
              : tokens.textMuted,
        ),
        const SizedBox(width: StudioSpacing.xs),
        Expanded(
          child: Text(
            scopeLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor,
              fontSize: fontSize,
              height: 1.1,
              decoration: _hasActionableProjectScope(l10n, scopeLine)
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: tokens.accent.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
    return _wrapProjectScopeTapTarget(
      context: context,
      l10n: l10n,
      tokens: tokens,
      scopeLine: scopeLine,
      child: row,
    );
  }

  String? _workspaceTypeLabel(AppLocalizations l10n, String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'personal' => l10n.workspaceTypePersonal,
      'enterprise' => l10n.workspaceTypeEnterprise,
      _ => raw!.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final workspaceTypeLabel = _workspaceTypeLabel(l10n, workspaceType);
    final width = MediaQuery.sizeOf(context).width;
    final resolvedWorkspaceName = workspaceName?.trim();
    final workspaceLine = loading
        ? l10n.workspaceContextLoading
        : (resolvedWorkspaceName?.isNotEmpty == true
              ? (isBackendDefaultPersonalWorkspaceName(resolvedWorkspaceName!)
                    ? l10n.workspaceContextPersonalDefaultName
                    : resolvedWorkspaceName)
              : l10n.workspaceContextNoWorkspace);
    final scopeLine = projectLabel?.trim().isNotEmpty == true
        ? projectLabel!.trim()
        : l10n.workspaceContextNoProject;
    final showBilling =
        billingScope == 'workspace' && workspacePlanTier != null;

    if (inline) {
      final summary = '$workspaceLine · $scopeLine';
      final billingSummary = showBilling
          ? '${planTierDisplayName(l10n, workspacePlanTier)} · '
                '${workspaceJobsToday ?? 0}/${workspaceDailyJobQuota ?? l10n.workspaceBillingUnlimited}'
          : null;
      final tooltip = billingSummary == null
          ? summary
          : '$summary\n$billingSummary';

      if (titleBarChrome) {
        Widget buildTitleBarDenseRow() {
          return Row(
            children: <Widget>[
              Icon(
                Icons.workspaces_outline,
                size: 12,
                color: tokens.accent,
              ),
              const SizedBox(width: StudioSpacing.xs),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontSize: StudioTypography.of(context).meta,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          );
        }

        Widget buildTitleBarTwoLineColumn() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.workspaces_outline,
                    size: 12,
                    color: tokens.accent,
                  ),
                  const SizedBox(width: StudioSpacing.xs),
                  Expanded(
                    child: Text(
                      workspaceLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textPrimary,
                        fontSize: StudioTypography.of(context).meta,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (workspaceTypeLabel != null) ...<Widget>[
                    const SizedBox(width: StudioSpacing.xs),
                    Flexible(
                      fit: FlexFit.loose,
                      child: _InlineContextChip(
                        label: workspaceTypeLabel,
                        compact: true,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: StudioLayoutSpacing.titleTight),
              _buildTitleBarProjectScopeRow(
                context: context,
                theme: theme,
                tokens: tokens,
                l10n: l10n,
                scopeLine: scopeLine,
                iconSize: StudioTypography.of(context).meta,
                fontSize: StudioTypography.of(context).meta,
                textColor: _hasActionableProjectScope(l10n, scopeLine)
                    ? tokens.accent.withValues(alpha: 0.92)
                    : tokens.textSecondary,
              ),
            ],
          );
        }

        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 350),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useDense =
                  titleBarDense || constraints.maxHeight < 36;
              final body = useDense
                  ? buildTitleBarDenseRow()
                  : buildTitleBarTwoLineColumn();
              return _wrapProjectScopeTapTarget(
                context: context,
                l10n: l10n,
                tokens: tokens,
                scopeLine: scopeLine,
                child: SizedBox(
                  width: constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : double.infinity,
                  child: body,
                ),
              );
            },
          ),
        );
      }

      // embedded 模式：更清晰的两行布局
      if (embedded) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 第一行：工作区
            Row(
              children: <Widget>[
                Icon(
                  Icons.workspaces_outline,
                  size: 14,
                  color: tokens.accent,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Flexible(
                  child: Text(
                    workspaceLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textPrimary,
                      fontSize: StudioTypography.of(context).body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (workspaceTypeLabel != null) ...<Widget>[
                  const SizedBox(width: StudioSpacing.xs),
                  _InlineContextChip(
                    label: workspaceTypeLabel,
                    compact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.titleTight),
            // 第二行：项目
            Row(
              children: <Widget>[
                Icon(
                  Icons.folder_open_outlined,
                  size: 13,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Flexible(
                  child: Text(
                    scopeLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                      fontSize: StudioTypography.of(context).hint,
                    ),
                  ),
                ),
                if (showBilling) ...<Widget>[
                  const SizedBox(width: StudioSpacing.xs),
                  _InlineContextChip(
                    label: billingSummary!,
                    compact: true,
                  ),
                ],
              ],
            ),
          ],
        );
      }
      
      // 非 embedded 模式：保持原来的单行布局
      final row = Row(
        children: <Widget>[
          Icon(
            Icons.workspaces_outline,
            size: 16,
            color: tokens.accent,
          ),
          const SizedBox(width: StudioSpacing.xs),
          Expanded(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
                fontSize: embedded ? StudioTypography.of(context).hint : null,
              ),
            ),
          ),
          if (workspaceTypeLabel != null &&
              (embedded || width >= 1520)) ...<Widget>[
            const SizedBox(width: StudioSpacing.xs),
            _InlineContextChip(label: workspaceTypeLabel),
          ],
          if (showBilling && !embedded && width >= 1680) ...<Widget>[
            const SizedBox(width: StudioSpacing.xs),
            _InlineContextChip(label: billingSummary!),
          ],
        ],
      );
      if (embedded) {
        return Tooltip(
          message: tooltip,
          waitDuration: const Duration(milliseconds: 350),
          child: row,
        );
      }
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 350),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bgSurface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
            border: Border.all(color: tokens.surfaceHighlight),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioLayoutSpacing.insetDense,
              vertical: StudioLayoutSpacing.inlineGap,
            ),
            child: row,
          ),
        ),
      );
    }

    if (compact) {
      final useExpandedDesktopLayout = width >= 1500;
      if (useExpandedDesktopLayout) {
        return Padding(
          padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioLayoutSpacing.stackMedium),
              child: Wrap(
                spacing: StudioSpacing.sm,
                runSpacing: StudioSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.workspaces_outline,
                        size: 18,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          workspaceLine,
                          style: studioCardTitleStyle(context),
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
                  if (workspaceTypeLabel != null)
                    StudioChip(
                      label: Text(workspaceTypeLabel),
                      visualDensity: VisualDensity.standard,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
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
      if (!showBilling) {
        return Padding(
          padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
          child: Tooltip(
            message: '$workspaceLine\n$scopeLine',
            waitDuration: const Duration(milliseconds: 350),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.bgSurface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioSpacing.radiusCard,
                  vertical: StudioSpacing.radiusComfort,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.workspaces_outline,
                      size: 16,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Text(
                        '$workspaceLine · $scopeLine',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: StudioTokens.of(context).textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (workspaceTypeLabel != null) ...<Widget>[
                      const SizedBox(width: StudioSpacing.xs),
                      _InlineContextChip(label: workspaceTypeLabel),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.bgSurface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              StudioSpacing.radiusCard,
              0,
              StudioSpacing.radiusCard,
              StudioSpacing.radiusCard,
            ),
            initiallyExpanded: false,
            title: Row(
              children: <Widget>[
                Icon(Icons.workspaces_outline, size: 18, color: tokens.accent),
                const SizedBox(width: StudioSpacing.xs),
                Expanded(
                  child: Text(
                    '$workspaceLine · $scopeLine',
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (workspaceTypeLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(left: StudioSpacing.xs),
                    child: StudioChip(
                      label: Text(workspaceTypeLabel),
                      visualDensity: VisualDensity.standard,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
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
      padding: const EdgeInsets.only(top: StudioSpacing.radiusComfort),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgSurface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.workspaces_outline, size: 18),
                  const SizedBox(width: StudioLayoutSpacing.inlineGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          workspaceLine,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: StudioLayoutSpacing.titleTight),
                        Text(scopeLine, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (workspaceTypeLabel != null) ...<Widget>[
                    const SizedBox(width: StudioSpacing.sm),
                    StudioChip(
                      label: Text(workspaceTypeLabel),
                    ),
                  ],
                ],
              ),
              // Display workspace billing when billing_scope = workspace (Task 6.2)
              if (billingScope == 'workspace' && workspacePlanTier != null) ...[
                const SizedBox(height: StudioSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: StudioSpacing.sm),
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
            const SizedBox(width: StudioSpacing.xs),
            Text(
              l10n.workspaceBillingTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
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
                  const SizedBox(height: StudioLayoutSpacing.titleTight),
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
                const SizedBox(height: StudioLayoutSpacing.titleTight),
                Text(
                  l10n.workspaceBillingPercentUsed(usagePercent),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (quota != null && quota > 0) ...[
          const SizedBox(height: StudioSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
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
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.radiusComfort,
        vertical: StudioSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
        border: Border.all(color: studioPanelBorderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: StudioTokens.of(context).textSecondary),
          const SizedBox(width: StudioSpacing.xs),
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

class _InlineContextChip extends StatelessWidget {
  const _InlineContextChip({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: compact ? 0.75 : 0.92),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
        border: Border.all(
          color: tokens.surfaceHighlight.withValues(alpha: compact ? 0.6 : 0.9),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : StudioLayoutSpacing.inlineGap,
          vertical: compact ? 3 : 5,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
            fontSize: compact ? StudioTypography.of(context).meta : null,
          ),
        ),
      ),
    );
  }
}
