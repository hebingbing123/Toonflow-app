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
    this.currentWorkspace,
  });

  final String sub;
  final String? email;
  final String planTier;
  final String? billingCurrency;
  final String? billingProvider;
  final WorkspaceSummary? currentWorkspace;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      sub: json['sub'] as String,
      email: json['email'] as String?,
      planTier: json['plan_tier'] as String,
      billingCurrency: json['billing_currency'] as String?,
      billingProvider: json['billing_provider'] as String?,
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

Future<MeResponse> fetchMeV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/me');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 5));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MeResponse.fromJson(map);
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SwitchAiDevToolV1.fromJson(map);
}
