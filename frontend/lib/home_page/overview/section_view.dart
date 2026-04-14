import 'package:flutter/material.dart';

class OverviewSectionViewModel {
  const OverviewSectionViewModel({
    required this.apiBaseUrl,
    required this.loadingHealth,
    required this.loadingHealthRoot,
    required this.loadingPing,
    required this.loadingVersion,
    required this.loadingReady,
    required this.healthBody,
    required this.healthRootBody,
    required this.pingBody,
    required this.versionBody,
    required this.readyBody,
  });

  final String apiBaseUrl;
  final bool loadingHealth;
  final bool loadingHealthRoot;
  final bool loadingPing;
  final bool loadingVersion;
  final bool loadingReady;
  final String? healthBody;
  final String? healthRootBody;
  final String? pingBody;
  final String? versionBody;
  final String? readyBody;
}

class OverviewSectionViewCallbacks {
  const OverviewSectionViewCallbacks({
    required this.onPingHealth,
    required this.onPingHealthRoot,
    required this.onPingPing,
    required this.onPingVersion,
    required this.onPingReady,
  });

  final VoidCallback? onPingHealth;
  final VoidCallback? onPingHealthRoot;
  final VoidCallback? onPingPing;
  final VoidCallback? onPingVersion;
  final VoidCallback? onPingReady;
}

class OverviewSectionView extends StatelessWidget {
  const OverviewSectionView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final OverviewSectionViewModel model;
  final OverviewSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API: ${model.apiBaseUrl}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: model.loadingHealth ? null : callbacks.onPingHealth,
              child: Text(model.loadingHealth ? '请求中…' : 'GET /api/v1/health'),
            ),
            FilledButton.tonal(
              onPressed: model.loadingHealthRoot
                  ? null
                  : callbacks.onPingHealthRoot,
              child: Text(model.loadingHealthRoot ? '请求中…' : 'GET /health'),
            ),
            FilledButton.tonal(
              onPressed: model.loadingPing ? null : callbacks.onPingPing,
              child: Text(model.loadingPing ? '请求中…' : 'GET /api/v1/ping'),
            ),
          ],
        ),
        if (model.healthBody != null) ...[
          const SizedBox(height: 8),
          Text('health (v1): ${model.healthBody}'),
        ],
        if (model.healthRootBody != null) ...[
          const SizedBox(height: 8),
          Text('health (root): ${model.healthRootBody}'),
        ],
        if (model.pingBody != null) ...[
          const SizedBox(height: 8),
          Text('ping: ${model.pingBody}'),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: model.loadingVersion ? null : callbacks.onPingVersion,
          child: Text(model.loadingVersion ? '请求中…' : 'GET /api/v1/version'),
        ),
        if (model.versionBody != null) ...[
          const SizedBox(height: 8),
          Text('version: ${model.versionBody}'),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: model.loadingReady ? null : callbacks.onPingReady,
          child: Text(model.loadingReady ? '请求中…' : 'GET /api/v1/ready'),
        ),
        if (model.readyBody != null) ...[
          const SizedBox(height: 8),
          Text('ready: ${model.readyBody}'),
        ],
      ],
    );
  }
}
