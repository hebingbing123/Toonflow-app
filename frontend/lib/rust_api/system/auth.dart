import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Authenticated identity and developer-tool preference endpoints.
/// `GET /api/v1/me` — Bearer; see `meV1` / OpenAPI `MeResponse`.
class MeResponse {
  const MeResponse({
    required this.sub,
    this.email,
    required this.planTier,
    this.billingCurrency,
    this.billingProvider,
    this.subscriptionStatus,
    this.subscriptionCurrentPeriodEndAt,
    this.dailyJobQuota,
    this.jobsToday,
    this.currentWorkspace,
  });

  final String sub;
  final String? email;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;
  final String? subscriptionStatus;
  final DateTime? subscriptionCurrentPeriodEndAt;
  final int? dailyJobQuota;
  final int? jobsToday;
  final WorkspaceSummary? currentWorkspace;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      subscriptionCurrentPeriodEndAt: json['subscription_current_period_end_at'] != null
          ? DateTime.parse(json['subscription_current_period_end_at'] as String)
          : null,
      dailyJobQuota: (json['daily_job_quota'] as num?)?.toInt(),
      jobsToday: (json['jobs_today'] as num?)?.toInt(),
      currentWorkspace: json['current_workspace'] is Map<String, dynamic>
          ? WorkspaceSummary.fromJson(
              json['current_workspace'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

/// User billing summary for `/me` v2 response (nested under `user` field).
class UserBillingSummary {
  const UserBillingSummary({
    required this.sub,
    this.email,
    required this.planTier,
    this.billingCurrency,
    this.billingProvider,
    this.subscriptionStatus,
    this.subscriptionCurrentPeriodEndAt,
    this.dailyJobQuota,
    this.jobsToday,
  });

  final String sub;
  final String? email;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;
  final String? subscriptionStatus;
  final DateTime? subscriptionCurrentPeriodEndAt;
  final int? dailyJobQuota;
  final int? jobsToday;

  factory UserBillingSummary.fromJson(Map<String, dynamic> json) {
    return UserBillingSummary(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
      subscriptionStatus: json['subscription_status'] as String?,
      subscriptionCurrentPeriodEndAt: json['subscription_current_period_end_at'] != null
          ? DateTime.parse(json['subscription_current_period_end_at'] as String)
          : null,
      dailyJobQuota: (json['daily_job_quota'] as num?)?.toInt(),
      jobsToday: (json['jobs_today'] as num?)?.toInt(),
    );
  }
}

/// Workspace billing summary for `/me` v2 response.
/// Present when `billing_scope = "workspace"` and user has a current workspace.
class WorkspaceBillingSummary {
  const WorkspaceBillingSummary({
    required this.workspaceId,
    required this.workspaceType,
    required this.planTier,
    this.billingCurrency,
    this.billingProvider,
    this.dailyJobQuota,
    this.jobsToday,
  });

  final String workspaceId;
  final String workspaceType;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;
  final int? dailyJobQuota;
  final int? jobsToday;

  factory WorkspaceBillingSummary.fromJson(Map<String, dynamic> json) {
    return WorkspaceBillingSummary(
      workspaceId: json['workspace_id'] as String,
      workspaceType: json['workspace_type'] as String,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
      dailyJobQuota: (json['daily_job_quota'] as num?)?.toInt(),
      jobsToday: (json['jobs_today'] as num?)?.toInt(),
    );
  }
}

/// `/me` v2 response with nested billing context (Task 6.1).
/// Accessed via `GET /api/v1/me?v=2`.
class MeV2Response {
  const MeV2Response({
    required this.billingScope,
    required this.user,
    this.currentWorkspaceBilling,
    this.memoryConfig,
    this.currentWorkspace,
  });

  /// Effective billing scope for current session: "user" | "workspace"
  final String billingScope;
  /// User billing summary (always present).
  final UserBillingSummary user;
  /// Workspace billing summary (present when billing_scope = "workspace").
  final WorkspaceBillingSummary? currentWorkspaceBilling;
  /// User memory/RAG configuration.
  final Map<String, dynamic>? memoryConfig;
  /// Current workspace summary (always present when DB connected).
  final WorkspaceSummary? currentWorkspace;

  factory MeV2Response.fromJson(Map<String, dynamic> json) {
    return MeV2Response(
      billingScope: json['billing_scope'] as String,
      user: UserBillingSummary.fromJson(json['user'] as Map<String, dynamic>),
      currentWorkspaceBilling: json['current_workspace_billing'] is Map<String, dynamic>
          ? WorkspaceBillingSummary.fromJson(
              json['current_workspace_billing'] as Map<String, dynamic>,
            )
          : null,
      memoryConfig: json['memory_config'] is Map<String, dynamic>
          ? json['memory_config'] as Map<String, dynamic>
          : null,
      currentWorkspace: json['current_workspace'] is Map<String, dynamic>
          ? WorkspaceSummary.fromJson(
              json['current_workspace'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class WorkspaceSummary {
  const WorkspaceSummary({
    required this.id,
    required this.name,
    required this.workspaceType,
  });

  final String id;
  final String name;
  final String workspaceType;

  factory WorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return WorkspaceSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      workspaceType: json['workspace_type'] as String,
    );
  }
}

class PatchCurrentWorkspaceBody {
  const PatchCurrentWorkspaceBody({required this.workspaceId});

  final String workspaceId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'workspace_id': workspaceId,
  };
}

Future<MeResponse> fetchMeV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 5));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MeResponse.fromJson(map);
}

/// Fetch `/me` v2 response with nested billing context.
/// Accessed via `GET /api/v1/me?v=2` (Task 6.1).
Future<MeV2Response> fetchMeV2(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me?v=2');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 5));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MeV2Response.fromJson(map);
}

Future<WorkspaceSummary> patchCurrentWorkspaceV1(
  String accessToken,
  PatchCurrentWorkspaceBody body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me/current-workspace');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceSummary.fromJson(map);
}

/// OpenAPI **`SwitchAiDevToolResponse`** — prior **`getSwitchAiDevTool`**.
class SwitchAiDevToolV1 {
  const SwitchAiDevToolV1({required this.value});

  final String value;

  factory SwitchAiDevToolV1.fromJson(Map<String, dynamic> json) {
    return SwitchAiDevToolV1(value: json['value'] as String);
  }
}

/// `GET /api/v1/settings/dev/switch-ai-tool` — OpenAPI `getSwitchAiDevToolV1`.
Future<SwitchAiDevToolV1> fetchSwitchAiDevToolV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/dev/switch-ai-tool');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SwitchAiDevToolV1.fromJson(map);
}

/// `PUT /api/v1/settings/dev/switch-ai-tool` — OpenAPI `putSwitchAiDevToolV1`.
Future<SwitchAiDevToolV1> putSwitchAiDevToolV1(
  String accessToken,
  String value,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/dev/switch-ai-tool');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'value': value}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SwitchAiDevToolV1.fromJson(map);
}
