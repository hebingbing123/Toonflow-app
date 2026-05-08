import 'package:flutter/material.dart';

import '../config.dart';
import '../rust_api/jobs/queue_stats.dart';

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
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Job queue stats (internal)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Uses INTERNAL_OPS_TOKEN dart-define → GET /api/v1/jobs/queue/stats',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _loading ? null : _load,
                  child: Text(_loading ? 'Loading…' : 'Refresh'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              SelectableText(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_stats != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                'pending=${_stats!.pending} claimable=${_stats!.pendingClaimable} '
                'running=${_stats!.running} dead=${_stats!.dead} '
                'failed_24h=${_stats!.failedLast24h} '
                'oldest_claimable_s=${_stats!.oldestClaimableQueuedAgeSecs ?? 'null'}',
              ),
              const SizedBox(height: 8),
              SelectableText(
                'pending_by_kind: ${_stats!.pendingByKind}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
