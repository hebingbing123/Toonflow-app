import 'package:flutter/material.dart';

import 'config.dart';
import 'l10n/app_localizations.dart';
import 'local_prefs/risky_operation_confirm_prefs.dart';
import 'rust_api.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  bool _loading = true;
  String? _error;
  HealthResponse? _healthRoot;
  HealthResponse? _healthV1;
  ReadyV1Response? _ready;
  VersionResponse? _version;
  JobQueueStatsV1? _queueStats;
  DateTime? _lastUpdatedAt;

  bool get _showInternalQueueStats => kInternalOpsToken.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final healthRootFuture = fetchHealthRoot();
      final healthV1Future = fetchHealthV1();
      final readyFuture = fetchReadyV1();
      final versionFuture = fetchVersionV1();
      final queueStatsFuture = _showInternalQueueStats
          ? fetchJobQueueStatsV1(internalOpsToken: kInternalOpsToken)
          : Future<JobQueueStatsV1?>.value(null);
      final results = await Future.wait<Object?>([
        healthRootFuture,
        healthV1Future,
        readyFuture,
        versionFuture,
        queueStatsFuture,
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _healthRoot = results[0] as HealthResponse;
        _healthV1 = results[1] as HealthResponse;
        _ready = results[2] as ReadyV1Response;
        _version = results[3] as VersionResponse;
        _queueStats = results[4] as JobQueueStatsV1?;
        _lastUpdatedAt = DateTime.now();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _error = describeUserVisibleApiError(l10n, error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statusPageTitle),
        actions: [
          IconButton(
            tooltip: l10n.statusPageRefreshTooltip,
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const RiskyOperationConfirmPrefsOverflowMenu(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.statusPageHeadline, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l10n.statusPageIntroBase +
                (_showInternalQueueStats
                    ? l10n.statusPageIntroInternalSuffix
                    : ''),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.sync),
                label: Text(
                  _loading
                      ? l10n.statusPageRefreshing
                      : l10n.statusPageRefreshAction,
                ),
              ),
              OutlinedButton(
                onPressed: null,
                child: Text(l10n.statusPageApiBaseLabel(kApiBaseUrl)),
              ),
            ],
          ),
          if (_lastUpdatedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.statusPageLastUpdated(
                _lastUpdatedAt!.toLocal().toIso8601String(),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            _StatusBand(
              title: l10n.statusPageRequestFailed,
              tone: _BandTone.error,
              lines: [_error!],
            ),
          ],
          if (_healthRoot != null && _healthV1 != null && _ready != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: '/health',
                  value: _healthRoot!.status,
                  detail: _healthRoot!.service,
                ),
                _MetricTile(
                  label: '/api/v1/health',
                  value: _healthV1!.status,
                  detail: _healthV1!.service,
                ),
                _MetricTile(
                  label: '/api/v1/ready',
                  value: _ready!.status,
                  detail: 'database=${_ready!.database}',
                ),
              ],
            ),
          ],
          if (_version != null) ...[
            const SizedBox(height: 16),
            _StatusBand(
              title: l10n.statusPageVersionSectionTitle,
              tone: _BandTone.neutral,
              lines: [
                'service=${_version!.service}',
                'version=${_version!.version}',
                if (_version!.gitSha != null && _version!.gitSha!.isNotEmpty)
                  'git_sha=${_version!.gitSha}',
              ],
            ),
          ],
          if (_queueStats != null) ...[
            const SizedBox(height: 16),
            _StatusBand(
              title: l10n.statusPageInternalQueueSectionTitle,
              tone: _BandTone.info,
              lines: [
                'pending=${_queueStats!.pending}',
                'pending_claimable=${_queueStats!.pendingClaimable}',
                'running=${_queueStats!.running}',
                'dead=${_queueStats!.dead}',
                'failed_last_24h=${_queueStats!.failedLast24h}',
                'oldest_claimable_queued_age_secs=${_queueStats!.oldestClaimableQueuedAgeSecs ?? 'null'}',
                if (_queueStats!.pendingByKind.isNotEmpty)
                  'pending_by_kind=${_queueStats!.pendingByKind}',
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _BandTone { neutral, info, error }

class _StatusBand extends StatelessWidget {
  const _StatusBand({
    required this.title,
    required this.tone,
    required this.lines,
  });

  final String title;
  final _BandTone tone;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _BandTone.neutral => colorScheme.surfaceContainerHighest,
      _BandTone.info => colorScheme.secondaryContainer,
      _BandTone.error => colorScheme.errorContainer,
    };
    final foreground = switch (tone) {
      _BandTone.neutral => colorScheme.onSurface,
      _BandTone.info => colorScheme.onSecondaryContainer,
      _BandTone.error => colorScheme.onErrorContainer,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: foreground),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                line,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foreground),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
