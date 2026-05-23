import 'dart:async';

import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_filter_row.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/components/studio_text_styles.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../l10n/studio_code_labels.dart';
import '../rust_api.dart';

class PlatformStatusSection extends StatefulWidget {
  const PlatformStatusSection({super.key, this.onOverallHealthChanged});

  final void Function(bool overallHealthy, List<String> degradedEndpoints)?
  onOverallHealthChanged;

  @override
  State<PlatformStatusSection> createState() => _PlatformStatusSectionState();
}

class _PlatformStatusSectionState extends State<PlatformStatusSection> {
  bool _loading = false;
  String? _error;
  int _windowMinutes = 60;
  bool _autoRefreshEnabled = true;
  HealthResponse? _health;
  ReadyV1Response? _ready;
  VersionResponse? _version;
  SliStatusResponse? _sliStatus;
  MetricsResponse? _metrics;
  DateTime? _lastUpdatedAt;
  bool? _previousHealthy;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefreshTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (!_autoRefreshEnabled) {
      return;
    }
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        fetchHealthV1(),
        fetchReadyV1(),
        fetchVersionV1(),
        fetchSliStatusV1(windowMinutes: _windowMinutes),
        fetchMetricsV1(windowMinutes: _windowMinutes),
      ]);
      if (!mounted) {
        return;
      }
      final nextHealth = _resolveOverallHealthy(
        health: results[0] as HealthResponse,
        ready: results[1] as ReadyV1Response,
        sli: results[3] as SliStatusResponse,
      );
      final nextDegradedEndpoints = _degradedEndpointNames(
        results[4] as MetricsResponse,
      );
      final previousHealthy = _previousHealthy;
      setState(() {
        _health = results[0] as HealthResponse;
        _ready = results[1] as ReadyV1Response;
        _version = results[2] as VersionResponse;
        _sliStatus = results[3] as SliStatusResponse;
        _metrics = results[4] as MetricsResponse;
        _lastUpdatedAt = DateTime.now();
        _previousHealthy = nextHealth;
      });
      if (previousHealthy != null && previousHealthy != nextHealth) {
        widget.onOverallHealthChanged?.call(nextHealth, nextDegradedEndpoints);
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                nextHealth
                    ? l10n.platformStatusRecoveredHealthy
                    : l10n.platformStatusDegradedWarning,
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool _resolveOverallHealthy({
    required HealthResponse health,
    required ReadyV1Response ready,
    required SliStatusResponse sli,
  }) {
    return health.status == 'ok' && ready.status == 'ok' && sli.healthy;
  }

  List<String> _degradedEndpointNames(MetricsResponse metrics) {
    return metrics.endpoints.entries
        .where(
          (e) => e.value.serverErrorCount > 0 || e.value.successRate < 0.995,
        )
        .map((e) => e.key)
        .toList(growable: false);
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) {
      return '--';
    }
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Color _statusColor(BuildContext context, bool healthy) {
    final tokens = StudioTokens.of(context);
    return healthy ? tokens.success : tokens.warning;
  }

  Widget _buildStudioHeader(BuildContext context, AppLocalizations l10n) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.platformStatusTitle,
                    style: studioPaneTitleStyle(context),
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.taskCenterLocalClientPrefs,
                ),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(l10n.platformStatusIntro, style: studioSectionIntroStyle(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioLoadingBody(BuildContext context) {
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: const Padding(
        padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StudioSkeleton(height: 18),
            SizedBox(height: StudioSpacing.sm),
            StudioSkeleton(height: 40),
            SizedBox(height: StudioSpacing.sm),
            StudioSkeleton(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final sliStatus = _sliStatus;
    final metrics = _metrics;
    final endpointCount = metrics?.endpoints.length ?? 0;
    final degradedEndpoints = metrics == null
        ? 0
        : _degradedEndpointNames(metrics).length;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildStudioHeader(context, l10n),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          StudioCollapsibleFilterPanel(
            subtitle: l10n.platformStatusLastRefreshed(
              _lastUpdatedAt == null
                  ? l10n.platformStatusNotRefreshed
                  : _formatUpdatedAt(_lastUpdatedAt),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioFilterRow(
                  wideLayout: StudioFilterWideLayout.toolbarRow,
                  wideBreakpoint: 560,
                  children: <Widget>[
                    StudioDropdownButton<int>(
                      value: _windowMinutes,
                      width: 132,
                      onChanged: _loading
                          ? null
                          : (next) {
                              if (next == null || next == _windowMinutes) {
                                return;
                              }
                              setState(() {
                                _windowMinutes = next;
                              });
                              _refresh();
                            },
                      items: <DropdownMenuItem<int>>[
                        DropdownMenuItem(
                          value: 15,
                          child: Text(l10n.platformStatusWindowMinutes(15)),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: Text(l10n.platformStatusWindowMinutes(60)),
                        ),
                        DropdownMenuItem(
                          value: 180,
                          child: Text(l10n.platformStatusWindowHours(3)),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _refresh,
                      icon: _loading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.platformStatusRefreshAction),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.platformStatusLastRefreshed(
                          _lastUpdatedAt == null
                              ? l10n.platformStatusNotRefreshed
                              : _formatUpdatedAt(_lastUpdatedAt),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Switch(
                      value: _autoRefreshEnabled,
                      onChanged: (value) {
                        setState(() {
                          _autoRefreshEnabled = value;
                        });
                        _startAutoRefreshTimer();
                      },
                    ),
                    Text(l10n.platformStatusAutoRefresh),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: StudioTokens.of(context).danger,
              ),
            ),
          ],
          if (_loading && _health == null && _error == null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            _buildStudioLoadingBody(context),
          ],
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: studioInsetPanelDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
              child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusChip(
                title: l10n.platformStatusChipHealth,
                value: studioPlatformHealthValueLabel(
                  l10n,
                  _health?.status ?? '-',
                ),
                color: _statusColor(context, (_health?.status ?? '') == 'ok'),
              ),
              _StatusChip(
                title: l10n.platformStatusChipReady,
                value: studioPlatformHealthValueLabel(
                  l10n,
                  _ready?.status ?? '-',
                ),
                color: _statusColor(context, (_ready?.status ?? '') == 'ok'),
              ),
              _StatusChip(
                title: l10n.platformStatusChipSli,
                value: sliStatus == null
                    ? '-'
                    : (sliStatus.healthy
                          ? l10n.platformStatusHealthy
                          : l10n.platformStatusDegraded),
                color: _statusColor(context, sliStatus?.healthy == true),
              ),
              _StatusChip(
                title: l10n.platformStatusChipEndpoints,
                value: '$endpointCount',
                color: theme.colorScheme.primary,
              ),
              _StatusChip(
                title: l10n.platformStatusChipDegraded,
                value: '$degradedEndpoints',
                color: _statusColor(context, degradedEndpoints == 0),
              ),
            ],
              ),
            ),
          ),
          if (_version != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            Text(
              l10n.platformStatusVersionLine(
                _version!.service,
                _version!.version,
                _version!.gitSha == null ? '' : ' (${_version!.gitSha})',
              ),
              style: studioHintStyle(context),
            ),
          ],
          if (sliStatus != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            DecoratedBox(
              decoration: studioInsetPanelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.platformStatusSliSnapshot,
                      style: studioPaneTitleStyle(context),
                    ),
                    const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                    ...sliStatus.slis
                        .take(5)
                        .map((sli) => _SliTile(snapshot: sli)),
                  ],
                ),
              ),
            ),
          ],
          if (metrics != null) ...<Widget>[
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            DecoratedBox(
              decoration: studioInsetPanelDecoration(context),
              child: Padding(
                padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.platformStatusHotEndpoints,
                      style: studioPaneTitleStyle(context),
                    ),
                    const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
                    ...metrics.endpoints.values
                        .toList(growable: false)
                        .sorted(
                          (a, b) =>
                              b.totalRequests.compareTo(a.totalRequests),
                        )
                        .take(5)
                        .map((endpoint) => _EndpointTile(endpoint: endpoint)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.inlineGap, vertical: StudioSpacing.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(l10n.platformStatusChipLabel(title, value)),
    );
  }
}

class _SliTile extends StatelessWidget {
  const _SliTile({required this.snapshot});

  final SliSnapshotResponse snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);
    final healthy = snapshot.healthy;
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgSurface.withValues(alpha: 0.92),
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: StudioLayoutSpacing.cardInner - 4,
            vertical: StudioSpacing.xs,
          ),
          leading: Icon(
            healthy ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: healthy ? tokens.success : tokens.warning,
          ),
          title: Text(snapshot.definition.name),
          subtitle: Text(
            l10n.platformStatusSliTileSubtitle(
              snapshot.path,
              snapshot.currentP95LatencyMs.toString(),
              (snapshot.currentSuccessRate * 100).toStringAsFixed(2),
            ),
          ),
          trailing: Text(l10n.platformStatusRequests(snapshot.totalRequests)),
        ),
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({required this.endpoint});

  final EndpointMetricsResponse endpoint;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgSurface.withValues(alpha: 0.92),
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: StudioLayoutSpacing.cardInner - 4,
            vertical: StudioSpacing.xs,
          ),
          title: Text(endpoint.path),
          subtitle: Text(
            l10n.platformStatusEndpointTileSubtitle(
              endpoint.totalRequests,
              (endpoint.successRate * 100).toStringAsFixed(2),
              endpoint.p95LatencyMs.toString(),
            ),
          ),
          trailing: Text(
            l10n.platformStatusServerErrors(endpoint.serverErrorCount),
          ),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  List<T> sorted(int Function(T a, T b) compare) {
    final copy = List<T>.from(this);
    copy.sort(compare);
    return copy;
  }
}
