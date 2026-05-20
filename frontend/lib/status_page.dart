import 'package:flutter/material.dart';

import 'config.dart';
import 'l10n/native_bridge_startup_labels.dart';
import 'l10n/studio_code_labels.dart';
import 'design_system/components/studio_text_styles.dart';
import 'design_system/tokens.dart';
import 'local_prefs/risky_operation_confirm_prefs.dart';
import 'native_bridge/native_bridge_bootstrap.dart';
import 'rust_api.dart';

bool shouldOpenStatusPageForInitialUri(Uri uri) {
  final path = uri.path.trim();
  return path == '/status' || path == '/status/';
}

Future<HealthResponse> _statusPageFetchHealthRootDefault() => fetchHealthRoot();
Future<HealthResponse> _statusPageFetchHealthV1Default() => fetchHealthV1();
Future<ReadyV1Response> _statusPageFetchReadyV1Default() => fetchReadyV1();
Future<VersionResponse> _statusPageFetchVersionV1Default() => fetchVersionV1();

class StatusPageFetchers {
  StatusPageFetchers({
    Future<HealthResponse> Function()? fetchHealthRoot,
    Future<HealthResponse> Function()? fetchHealthV1,
    Future<ReadyV1Response> Function()? fetchReadyV1,
    Future<VersionResponse> Function()? fetchVersionV1,
    Future<JobQueueStatsV1?> Function(String internalOpsToken)?
    fetchJobQueueStats,
  }) : fetchHealthRoot = fetchHealthRoot ?? _statusPageFetchHealthRootDefault,
       fetchHealthV1 = fetchHealthV1 ?? _statusPageFetchHealthV1Default,
       fetchReadyV1 = fetchReadyV1 ?? _statusPageFetchReadyV1Default,
       fetchVersionV1 = fetchVersionV1 ?? _statusPageFetchVersionV1Default,
       fetchJobQueueStats = fetchJobQueueStats ?? _defaultFetchJobQueueStats;

  final Future<HealthResponse> Function() fetchHealthRoot;
  final Future<HealthResponse> Function() fetchHealthV1;
  final Future<ReadyV1Response> Function() fetchReadyV1;
  final Future<VersionResponse> Function() fetchVersionV1;
  final Future<JobQueueStatsV1?> Function(String internalOpsToken)
  fetchJobQueueStats;

  static Future<JobQueueStatsV1?> _defaultFetchJobQueueStats(
    String internalOpsToken,
  ) {
    return fetchJobQueueStatsV1(internalOpsToken: internalOpsToken);
  }
}

class StatusPage extends StatefulWidget {
  StatusPage({
    super.key,
    StatusPageFetchers? fetchers,
    NativeBridgeBootstrap? bootstrap,
  }) : fetchers = fetchers ?? StatusPageFetchers(),
       bootstrap = bootstrap ?? NativeBridgeBootstrap.instance;

  final StatusPageFetchers fetchers;
  final NativeBridgeBootstrap bootstrap;

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
      final healthRootFuture = widget.fetchers.fetchHealthRoot();
      final healthV1Future = widget.fetchers.fetchHealthV1();
      final readyFuture = widget.fetchers.fetchReadyV1();
      final versionFuture = widget.fetchers.fetchVersionV1();
      final queueStatsFuture = _showInternalQueueStats
          ? widget.fetchers.fetchJobQueueStats(kInternalOpsToken)
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
        _error = describeUserVisibleApiErrorResolved(context, error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
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
        padding: const EdgeInsets.all(StudioSpacing.sm),
        children: [
          Text(l10n.statusPageHeadline, style: studioPageTitleStyle(context)),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.statusPageIntroBase +
                (_showInternalQueueStats
                    ? l10n.statusPageIntroInternalSuffix
                    : ''),
            style: studioSectionIntroStyle(context),
          ),
          const SizedBox(height: StudioSpacing.sm),
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
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
              SelectableText(
                l10n.statusPageApiBaseLabel(kApiBaseUrl),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (_lastUpdatedAt != null) ...[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.statusPageLastUpdated(
                _lastUpdatedAt!.toLocal().toIso8601String(),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: StudioSpacing.sm),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: StudioSpacing.sm),
            _StatusBand(
              title: l10n.statusPageRequestFailed,
              tone: _BandTone.error,
              lines: [_error!],
            ),
          ],
          if (_healthRoot != null && _healthV1 != null && _ready != null) ...[
            const SizedBox(height: StudioSpacing.sm),
            Wrap(
              spacing: StudioSpacing.sm,
              runSpacing: StudioSpacing.sm,
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
                  detail: l10n.statusPageReadyDatabaseLine(_ready!.database),
                ),
              ],
            ),
          ],
          if (_version != null) ...[
            const SizedBox(height: StudioSpacing.sm),
            _StatusBand(
              title: l10n.statusPageVersionSectionTitle,
              tone: _BandTone.neutral,
              lines: [
                l10n.statusPageVersionServiceLine(_version!.service),
                l10n.statusPageVersionNumberLine(_version!.version),
                if (_version!.gitSha != null && _version!.gitSha!.isNotEmpty)
                  l10n.statusPageVersionGitShaLine(_version!.gitSha!),
              ],
            ),
          ],
          const SizedBox(height: StudioSpacing.sm),
          ListenableBuilder(
            listenable: widget.bootstrap,
            builder: (context, _) {
              final snapshot = widget.bootstrap.snapshot;
              return _StatusBand(
                title: l10n.statusPageDesktopBridgeSectionTitle,
                tone: switch (snapshot.state) {
                  NativeBridgeStartupState.ready => _BandTone.info,
                  NativeBridgeStartupState.failed => _BandTone.error,
                  NativeBridgeStartupState.skipped => _BandTone.neutral,
                  NativeBridgeStartupState.idle => _BandTone.neutral,
                },
                lines: [
                  l10n.statusPageBridgeStateLine(snapshot.state.name),
                  l10n.statusPageBridgeMessageLine(
                    nativeBridgeStartupMessage(l10n, snapshot),
                  ),
                  if (snapshot.libraryPath != null)
                    l10n.statusPageBridgeLibraryPathLine(snapshot.libraryPath!),
                  if (snapshot.error != null)
                    l10n.statusPageBridgeErrorLine('${snapshot.error}'),
                ],
              );
            },
          ),
          if (_queueStats != null) ...[
            const SizedBox(height: StudioSpacing.sm),
            _StatusBand(
              title: l10n.statusPageInternalQueueSectionTitle,
              tone: _BandTone.info,
              lines: [
                l10n.statusPageQueueMetricLine(
                  studioJobQueueMetricLabel(l10n, 'pending'),
                  '${_queueStats!.pending}',
                ),
                l10n.statusPageQueueMetricLine(
                  studioJobQueueMetricLabel(l10n, 'claimable'),
                  '${_queueStats!.pendingClaimable}',
                ),
                l10n.statusPageQueueMetricLine(
                  studioJobQueueMetricLabel(l10n, 'running'),
                  '${_queueStats!.running}',
                ),
                l10n.statusPageQueueMetricLine(
                  studioJobQueueMetricLabel(l10n, 'dead'),
                  '${_queueStats!.dead}',
                ),
                l10n.statusPageQueueMetricLine(
                  studioJobQueueMetricLabel(l10n, 'failed_last_24h'),
                  '${_queueStats!.failedLast24h}',
                ),
                l10n.statusPageQueueMetricLine(
                  studioJobQueueMetricLabel(l10n, 'oldest_claimable_queued_age_secs'),
                  '${_queueStats!.oldestClaimableQueuedAgeSecs ?? l10n.platformStatusHealthUnknown}',
                ),
                if (_queueStats!.pendingByKind.isNotEmpty)
                  l10n.statusPageQueueMetricLine(
                    studioJobQueueMetricLabel(l10n, 'pending_by_kind'),
                    _queueStats!.pendingByKind.entries
                        .map(
                          (entry) =>
                              '${studioJobKindLabel(l10n, entry.key)}=${entry.value}',
                        )
                        .join(', '),
                  ),
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
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
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
      width: 228,
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            value,
            style: studioProjectTitleStyle(
              context,
            )?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(detail, style: studioHintStyle(context)),
        ],
      ),
    );
  }
}
