import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class PlatformConfigToggleSetV1 {
  const PlatformConfigToggleSetV1({
    required this.helpHubEnabled,
    required this.qualityDashboardEnabled,
    required this.qualityRefreshControlsEnabled,
    required this.platformStatusEnabled,
    required this.workspaceActivityEnabled,
    required this.benchmarkPaneEnabled,
    required this.jobsPaneEnabled,
  });

  final bool helpHubEnabled;
  final bool qualityDashboardEnabled;
  final bool qualityRefreshControlsEnabled;
  final bool platformStatusEnabled;
  final bool workspaceActivityEnabled;
  final bool benchmarkPaneEnabled;
  final bool jobsPaneEnabled;

  static const defaults = PlatformConfigToggleSetV1(
    helpHubEnabled: true,
    qualityDashboardEnabled: true,
    qualityRefreshControlsEnabled: true,
    platformStatusEnabled: true,
    workspaceActivityEnabled: true,
    benchmarkPaneEnabled: true,
    jobsPaneEnabled: true,
  );

  factory PlatformConfigToggleSetV1.fromJson(Map<String, dynamic> json) {
    return PlatformConfigToggleSetV1(
      helpHubEnabled: json['helpHubEnabled'] as bool? ?? true,
      qualityDashboardEnabled: json['qualityDashboardEnabled'] as bool? ?? true,
      qualityRefreshControlsEnabled:
          json['qualityRefreshControlsEnabled'] as bool? ?? true,
      platformStatusEnabled: json['platformStatusEnabled'] as bool? ?? true,
      workspaceActivityEnabled:
          json['workspaceActivityEnabled'] as bool? ?? true,
      benchmarkPaneEnabled: json['benchmarkPaneEnabled'] as bool? ?? true,
      jobsPaneEnabled: json['jobsPaneEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'helpHubEnabled': helpHubEnabled,
    'qualityDashboardEnabled': qualityDashboardEnabled,
    'qualityRefreshControlsEnabled': qualityRefreshControlsEnabled,
    'platformStatusEnabled': platformStatusEnabled,
    'workspaceActivityEnabled': workspaceActivityEnabled,
    'benchmarkPaneEnabled': benchmarkPaneEnabled,
    'jobsPaneEnabled': jobsPaneEnabled,
  };

  PlatformConfigToggleSetV1 copyWith({
    bool? helpHubEnabled,
    bool? qualityDashboardEnabled,
    bool? qualityRefreshControlsEnabled,
    bool? platformStatusEnabled,
    bool? workspaceActivityEnabled,
    bool? benchmarkPaneEnabled,
    bool? jobsPaneEnabled,
  }) {
    return PlatformConfigToggleSetV1(
      helpHubEnabled: helpHubEnabled ?? this.helpHubEnabled,
      qualityDashboardEnabled:
          qualityDashboardEnabled ?? this.qualityDashboardEnabled,
      qualityRefreshControlsEnabled:
          qualityRefreshControlsEnabled ?? this.qualityRefreshControlsEnabled,
      platformStatusEnabled: platformStatusEnabled ?? this.platformStatusEnabled,
      workspaceActivityEnabled:
          workspaceActivityEnabled ?? this.workspaceActivityEnabled,
      benchmarkPaneEnabled: benchmarkPaneEnabled ?? this.benchmarkPaneEnabled,
      jobsPaneEnabled: jobsPaneEnabled ?? this.jobsPaneEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PlatformConfigToggleSetV1 &&
            other.helpHubEnabled == helpHubEnabled &&
            other.qualityDashboardEnabled == qualityDashboardEnabled &&
            other.qualityRefreshControlsEnabled ==
                qualityRefreshControlsEnabled &&
            other.platformStatusEnabled == platformStatusEnabled &&
            other.workspaceActivityEnabled == workspaceActivityEnabled &&
            other.benchmarkPaneEnabled == benchmarkPaneEnabled &&
            other.jobsPaneEnabled == jobsPaneEnabled);
  }

  @override
  int get hashCode => Object.hash(
    helpHubEnabled,
    qualityDashboardEnabled,
    qualityRefreshControlsEnabled,
    platformStatusEnabled,
    workspaceActivityEnabled,
    benchmarkPaneEnabled,
    jobsPaneEnabled,
  );
}

class PlatformConfigResponseV1 {
  const PlatformConfigResponseV1({
    required this.scope,
    required this.schemaVersion,
    required this.effective,
    required this.planTier,
    required this.planOverride,
    required this.hasPlanOverride,
    required this.userOverride,
    required this.hasUserOverride,
    required this.workspaceOverride,
    required this.hasWorkspaceOverride,
    required this.currentWorkspace,
  });

  final String scope;
  final int schemaVersion;
  final PlatformConfigToggleSetV1 effective;
  final String planTier;
  final PlatformConfigToggleSetV1? planOverride;
  final bool hasPlanOverride;
  final PlatformConfigToggleSetV1 userOverride;
  final bool hasUserOverride;
  final PlatformConfigToggleSetV1? workspaceOverride;
  final bool hasWorkspaceOverride;
  final PlatformConfigWorkspaceContextV1? currentWorkspace;

  factory PlatformConfigResponseV1.fromJson(Map<String, dynamic> json) {
    return PlatformConfigResponseV1(
      scope: json['scope'] as String? ?? 'user',
      schemaVersion: (json['schemaVersion'] as num? ?? 1).toInt(),
      effective: PlatformConfigToggleSetV1.fromJson(
        json['effective'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      planTier: json['planTier'] as String? ?? 'free',
      planOverride: json['planOverride'] is Map<String, dynamic>
          ? PlatformConfigToggleSetV1.fromJson(
              json['planOverride'] as Map<String, dynamic>,
            )
          : null,
      hasPlanOverride: json['hasPlanOverride'] as bool? ?? false,
      userOverride: PlatformConfigToggleSetV1.fromJson(
        json['userOverride'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      hasUserOverride: json['hasUserOverride'] as bool? ?? false,
      workspaceOverride: json['workspaceOverride'] is Map<String, dynamic>
          ? PlatformConfigToggleSetV1.fromJson(
              json['workspaceOverride'] as Map<String, dynamic>,
            )
          : null,
      hasWorkspaceOverride: json['hasWorkspaceOverride'] as bool? ?? false,
      currentWorkspace: json['currentWorkspace'] is Map<String, dynamic>
          ? PlatformConfigWorkspaceContextV1.fromJson(
              json['currentWorkspace'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class PlatformConfigWorkspaceContextV1 {
  const PlatformConfigWorkspaceContextV1({
    required this.id,
    required this.name,
    required this.workspaceType,
    required this.role,
    required this.canManageOverride,
  });

  final String id;
  final String name;
  final String workspaceType;
  final String role;
  final bool canManageOverride;

  factory PlatformConfigWorkspaceContextV1.fromJson(Map<String, dynamic> json) {
    return PlatformConfigWorkspaceContextV1(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      workspaceType: json['workspaceType'] as String? ?? 'personal',
      role: json['role'] as String? ?? 'member',
      canManageOverride: json['canManageOverride'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is PlatformConfigWorkspaceContextV1 &&
            other.id == id &&
            other.name == name &&
            other.workspaceType == workspaceType &&
            other.role == role &&
            other.canManageOverride == canManageOverride);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, workspaceType, role, canManageOverride);
}

Future<PlatformConfigResponseV1> fetchPlatformConfigV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/platform-config');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return PlatformConfigResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<PlatformConfigResponseV1> postPlatformConfigV1(
  String accessToken,
  PlatformConfigToggleSetV1? toggles, {
  String scope = 'user',
  bool reset = false,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/platform-config');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({
          if (toggles != null) 'toggles': toggles.toJson(),
          'scope': scope,
          if (reset) 'reset': true,
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return PlatformConfigResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
