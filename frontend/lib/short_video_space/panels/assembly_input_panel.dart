import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';

import '../../design_system/components/studio_async_data_view.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/ix/studio_api_error_callout.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../view.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Assembly input diagnostic panel (storyboard + assets + assembly per shot).
class AssemblyInputPanel extends StatelessWidget {
  const AssemblyInputPanel({
    super.key,
    required this.ui,
    required this.l10n,
    this.onFixStoryboard,
    this.onFixProduction,
    this.onFixClipDesk,
    this.onOpenTaskCenter,
    this.onCancelJob,
    this.onRetryJob,
    this.onCreateDraftFromJob,
  });

  final AssemblyInputPanelUi ui;
  final AppLocalizations l10n;
  final VoidCallback? onFixStoryboard;
  final VoidCallback? onFixProduction;
  final VoidCallback? onFixClipDesk;
  final VoidCallback? onOpenTaskCenter;
  final VoidCallback? onCancelJob;
  final VoidCallback? onRetryJob;
  final VoidCallback? onCreateDraftFromJob;

  @override
  Widget build(BuildContext context) {
    if (!ui.visible) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = studioPanelMutedColor(context);

    if (ui.unavailable) {
      return Text(ui.headline, style: theme.textTheme.bodyMedium?.copyWith(color: muted));
    }

    return StudioAsyncDataView(
      loading: ui.loading,
      scrollableLoading: false,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ui.headline, style: theme.textTheme.titleSmall),
        if (ui.gate.blockingShotCount > 0) ...[
          const SizedBox(height: StudioSpacing.xs),
          Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            child: Padding(
              padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shortVideoSpaceAssemblyInputBlockingBanner(
                      ui.gate.blockingShotCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final line in ui.gate.blockingReasonLines.take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: StudioSpacing.chromeActionGap),
                      child: Text(
                        '· $line',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (ui.activeJob != null) ...[
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          _ActiveJobBanner(
            job: ui.activeJob!,
            l10n: l10n,
            onOpenTaskCenter: onOpenTaskCenter,
            onCancel: onCancelJob,
            onRetry: onRetryJob,
            onCreateDraft: onCreateDraftFromJob,
          ),
        ],
        if (ui.rows.isNotEmpty) ...[
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              itemCount: ui.rows.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = ui.rows[index];
                return studioStaggeredItem(
                  index,
                  entranceKey: ui.rows.length,
                  child: _ShotRow(
                    row: row,
                    l10n: l10n,
                    onFix: () => _openFix(row),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    ),
    );
  }

  void _openFix(AssemblyInputShotRowUi row) {
    switch (row.primaryFixTarget) {
      case AssemblyInputFixTarget.storyboard:
        onFixStoryboard?.call();
        break;
      case AssemblyInputFixTarget.production:
        onFixProduction?.call();
        break;
      case AssemblyInputFixTarget.clipDesk:
        onFixClipDesk?.call();
        break;
    }
  }
}

class _ActiveJobBanner extends StatelessWidget {
  const _ActiveJobBanner({
    required this.job,
    required this.l10n,
    this.onOpenTaskCenter,
    this.onCancel,
    this.onRetry,
    this.onCreateDraft,
  });

  final AssemblyActiveJobUi job;
  final AppLocalizations l10n;
  final VoidCallback? onOpenTaskCenter;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shortVideoSpaceAssemblyInputActiveJob(
              job.jobId.length > 8 ? job.jobId.substring(0, 8) : job.jobId,
              job.status,
            ),
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (job.errorLine != null) ...[
            const SizedBox(height: StudioSpacing.xs),
            StudioApiErrorCallout(
              error: job.errorLine!,
              emphasis: StudioApiErrorCalloutEmphasis.subtle,
              onRetry: onRetry,
            ),
          ],
          if (job.manifestPath != null)
            Text(job.manifestPath!, style: theme.textTheme.bodySmall),
          const SizedBox(height: StudioSpacing.xs),
          Wrap(
            spacing: StudioSpacing.xs,
            children: [
              if (onOpenTaskCenter != null)
                TextButton(
                  onPressed: onOpenTaskCenter,
                  child: Text(l10n.shortVideoSpaceAssemblyInputOpenTaskCenter),
                ),
              if (job.canCancel && onCancel != null)
                TextButton(onPressed: onCancel, child: Text(l10n.shortVideoSpaceProductionAssemblyCancelTask)),
              if (job.canRetry && onRetry != null)
                TextButton(onPressed: onRetry, child: Text(l10n.shortVideoSpaceProductionAssemblyRetryTask)),
              if (onCreateDraft != null && job.manifestPath != null)
                TextButton(
                  onPressed: onCreateDraft,
                  child: Text(l10n.shortVideoSpaceAssemblyInputCreateDraftFromJob),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShotRow extends StatelessWidget {
  const _ShotRow({
    required this.row,
    required this.l10n,
    required this.onFix,
  });

  final AssemblyInputShotRowUi row;
  final AppLocalizations l10n;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = row.sbIndex == null ? '' : ' #${row.sbIndex}';
    final title = 'S${row.scriptNumericId} · SB${row.storyboardNumericId}$slot';
    final statusLabel = row.ready
        ? l10n.shortVideoSpaceAssemblyInputShotReady
        : l10n.shortVideoSpaceAssemblyInputShotBlocking;
    final statusColor = row.ready ? theme.colorScheme.primary : theme.colorScheme.error;

    return StudioListRow(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: row.ready ? null : onFix,
      title: Text(title, style: theme.textTheme.bodySmall),
      subtitle: row.gapLabels.isEmpty
          ? null
          : Text(row.gapLabels.join(' · '), style: theme.textTheme.bodySmall),
      trailing: Wrap(
        spacing: StudioSpacing.chromeActionGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StudioChip(
            label: Text(statusLabel, style: theme.textTheme.labelSmall),
            backgroundColor: statusColor.withValues(alpha: 0.12),
          ),
          if (!row.ready)
            TextButton(onPressed: onFix, child: Text(_fixLabel(l10n, row.primaryFixTarget))),
        ],
      ),
    );
  }

  String _fixLabel(AppLocalizations l10n, AssemblyInputFixTarget target) {
    switch (target) {
      case AssemblyInputFixTarget.storyboard:
        return l10n.shortVideoSpaceAssemblyInputFixStoryboard;
      case AssemblyInputFixTarget.production:
        return l10n.shortVideoSpaceAssemblyInputFixProduction;
      case AssemblyInputFixTarget.clipDesk:
        return l10n.shortVideoSpaceAssemblyInputFixClipDesk;
    }
  }
}
