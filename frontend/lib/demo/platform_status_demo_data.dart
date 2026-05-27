import '../rust_api.dart';

/// Preloaded platform status probes for demo mode.
class PlatformStatusDemoSnapshot {
  const PlatformStatusDemoSnapshot({
    required this.health,
    required this.ready,
    required this.version,
  });

  final HealthResponse health;
  final ReadyV1Response ready;
  final VersionResponse version;
}

PlatformStatusDemoSnapshot buildDemoPlatformStatusSnapshot() {
  return const PlatformStatusDemoSnapshot(
    health: HealthResponse(status: 'ok', service: 'openflow-demo'),
    ready: ReadyV1Response(status: 'ready', database: 'ok'),
    version: VersionResponse(
      service: 'openflow-demo',
      version: '2026.05-demo',
      gitSha: 'demo0000',
    ),
  );
}
