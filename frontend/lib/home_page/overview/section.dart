import 'package:flutter/material.dart';

part 'section_view.dart';

class OverviewSection extends StatelessWidget {
  const OverviewSection({
    super.key,
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
    required this.onPingHealth,
    required this.onPingHealthRoot,
    required this.onPingPing,
    required this.onPingVersion,
    required this.onPingReady,
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
  final VoidCallback onPingHealth;
  final VoidCallback onPingHealthRoot;
  final VoidCallback onPingPing;
  final VoidCallback onPingVersion;
  final VoidCallback onPingReady;

  @override
  Widget build(BuildContext context) {
    return _buildOverviewSectionView(context);
  }
}
