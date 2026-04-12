part of 'section.dart';

/// Overview section view shell. Keeps probe inputs and callbacks in the section file.
extension _OverviewSectionView on OverviewSection {
  Widget _buildOverviewSectionView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API: $apiBaseUrl', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: loadingHealth ? null : onPingHealth,
              child: Text(loadingHealth ? '请求中…' : 'GET /api/v1/health'),
            ),
            FilledButton.tonal(
              onPressed: loadingHealthRoot ? null : onPingHealthRoot,
              child: Text(loadingHealthRoot ? '请求中…' : 'GET /health'),
            ),
            FilledButton.tonal(
              onPressed: loadingPing ? null : onPingPing,
              child: Text(loadingPing ? '请求中…' : 'GET /api/v1/ping'),
            ),
          ],
        ),
        if (healthBody != null) ...[
          const SizedBox(height: 8),
          Text('health (v1): $healthBody'),
        ],
        if (healthRootBody != null) ...[
          const SizedBox(height: 8),
          Text('health (root): $healthRootBody'),
        ],
        if (pingBody != null) ...[
          const SizedBox(height: 8),
          Text('ping: $pingBody'),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: loadingVersion ? null : onPingVersion,
          child: Text(loadingVersion ? '请求中…' : 'GET /api/v1/version'),
        ),
        if (versionBody != null) ...[
          const SizedBox(height: 8),
          Text('version: $versionBody'),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: loadingReady ? null : onPingReady,
          child: Text(loadingReady ? '请求中…' : 'GET /api/v1/ready'),
        ),
        if (readyBody != null) ...[
          const SizedBox(height: 8),
          Text('ready: $readyBody'),
        ],
      ],
    );
  }
}
