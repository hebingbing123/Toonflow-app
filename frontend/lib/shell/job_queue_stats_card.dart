import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../config.dart';
import '../rust_api.dart';

/// Read-only PG job queue stats when **`INTERNAL_OPS_TOKEN`** dart-define matches server env.
class JobQueueStatsCard extends StatefulWidget {
  const JobQueueStatsCard({super.key});

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
      final s = await fetchJobQueueStatsV1(internalOpsToken: kInternalOpsToken);
      if (!mounted) return;
      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = describeUserVisibleApiError(l10n, e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shellJobQueueStatsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.shellJobQueueStatsSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _loading ? null : _load,
                  child: Text(
                    _loading ? l10n.helpHubLoading : l10n.helpHubRefresh,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (_stats != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                l10n.shellJobQueueStatsStatsLine(
                  '${_stats!.pending}',
                  '${_stats!.pendingClaimable}',
                  '${_stats!.running}',
                  '${_stats!.dead}',
                  '${_stats!.failedLast24h}',
                  '${_stats!.oldestClaimableQueuedAgeSecs ?? 'null'}',
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                l10n.shellJobQueueStatsPendingByKind(
                  '${_stats!.pendingByKind}',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
