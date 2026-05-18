import 'package:flutter/material.dart';

import '../config.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../rust_api.dart';

/// Read-only PG job queue stats when **`OPENFLOW_INTERNAL_OPS_TOKEN`** dart-define matches server env.
class JobQueueStatsCard extends StatefulWidget {
  const JobQueueStatsCard({super.key, this.loadStats = _defaultLoadStats});

  final Future<JobQueueStatsV1> Function() loadStats;

  static Future<JobQueueStatsV1> _defaultLoadStats() {
    return fetchJobQueueStatsV1(internalOpsToken: kInternalOpsToken);
  }

  @override
  State<JobQueueStatsCard> createState() => _JobQueueStatsCardState();
}

class _JobQueueStatsCardState extends State<JobQueueStatsCard> {
  String? _error;
  JobQueueStatsV1? _stats;
  bool _loading = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.loadStats();
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _error = describeUserVisibleApiError(l10n, e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shellJobQueueStatsTitle,
              style: studioCardTitleStyle(context),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.shellJobQueueStatsSubtitle,
              style: studioSectionIntroStyle(context),
            ),
            const SizedBox(height: StudioSpacing.sm),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.sync),
              label: Text(_loading ? l10n.helpHubLoading : l10n.helpHubRefresh),
            ),
            if (_error != null) ...[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_stats != null) ...[
              const SizedBox(height: StudioSpacing.sm),
              Wrap(
                spacing: StudioSpacing.xs,
                runSpacing: StudioSpacing.xs,
                children: <Widget>[
                  _QueueMetricChip(
                    label: 'pending',
                    value: '${_stats!.pending}',
                  ),
                  _QueueMetricChip(
                    label: 'claimable',
                    value: '${_stats!.pendingClaimable}',
                  ),
                  _QueueMetricChip(
                    label: 'running',
                    value: '${_stats!.running}',
                  ),
                  _QueueMetricChip(label: 'dead', value: '${_stats!.dead}'),
                  _QueueMetricChip(
                    label: 'failed 24h',
                    value: '${_stats!.failedLast24h}',
                  ),
                  _QueueMetricChip(
                    label: 'oldest secs',
                    value: '${_stats!.oldestClaimableQueuedAgeSecs ?? 'null'}',
                  ),
                ],
              ),
              if (_stats!.pendingByKind.isNotEmpty) ...<Widget>[
                const SizedBox(height: StudioSpacing.sm),
                Text('pending_by_kind', style: theme.textTheme.labelMedium),
                const SizedBox(height: 6),
                Wrap(
                  spacing: StudioSpacing.xs,
                  runSpacing: StudioSpacing.xs,
                  children: _stats!.pendingByKind.entries
                      .map(
                        (entry) => _QueueMetricChip(
                          label: entry.key,
                          value: '${entry.value}',
                        ),
                      )
                      .toList(),
                ),
              ] else ...<Widget>[
                const SizedBox(height: StudioSpacing.xs),
                SelectableText(
                  l10n.shellJobQueueStatsStatsLine(
                    '${_stats!.pending}',
                    '${_stats!.pendingClaimable}',
                    '${_stats!.running}',
                    '${_stats!.dead}',
                    '${_stats!.failedLast24h}',
                    '${_stats!.oldestClaimableQueuedAgeSecs ?? 'null'}',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: StudioSpacing.xs),
              SelectableText(
                l10n.shellJobQueueStatsPendingByKind(
                  '${_stats!.pendingByKind}',
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueMetricChip extends StatelessWidget {
  const _QueueMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodySmall,
            children: <InlineSpan>[
              TextSpan(
                text: '$label ',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              TextSpan(text: value),
            ],
          ),
        ),
      ),
    );
  }
}
