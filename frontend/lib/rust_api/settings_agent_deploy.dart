part of 'index.dart';

/// OpenAPI **`AgentDeployListItem`** — legacy **`o_agentDeploy`** row shape (**camelCase**).
class AgentDeployListItemV1 {
  const AgentDeployListItemV1({
    required this.id,
    required this.model,
    required this.key,
    required this.modelName,
    required this.vendorId,
    required this.desc,
    required this.name,
    required this.disabled,
    required this.icon,
  });

  final int id;
  final String model;
  final String key;
  final String modelName;
  final String? vendorId;
  final String desc;
  final String name;
  final bool disabled;
  final String icon;

  factory AgentDeployListItemV1.fromJson(Map<String, dynamic> json) {
    return AgentDeployListItemV1(
      id: (json['id'] as num).toInt(),
      model: json['model'] as String? ?? '',
      key: json['key'] as String,
      modelName: json['modelName'] as String? ?? '',
      vendorId: json['vendorId'] as String?,
      desc: json['desc'] as String? ?? '',
      name: json['name'] as String? ?? '',
      disabled: json['disabled'] as bool? ?? false,
      icon: json['icon'] as String? ?? '',
    );
  }
}

/// `POST /api/v1/settings/agent-deploy/list` — OpenAPI `postSettingsAgentDeployListV1` (body **`{}`**).
Future<List<AgentDeployListItemV1>> postAgentDeployListV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/agent-deploy/list');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => AgentDeployListItemV1.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/settings/agent-deploy/deploy-model` — OpenAPI `postSettingsAgentDeployModelV1` (**200** with DB, **503** without DB).
Future<int> postSettingsAgentDeployModelV1(
  String accessToken, {
  required int id,
  required String name,
  required String model,
  required String modelName,
  String? vendorId,
  required String desc,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/agent-deploy/deploy-model',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'name': name,
          'model': model,
          'modelName': modelName,
          'vendorId': vendorId,
          'desc': desc,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/agent-deploy/set-key` — OpenAPI `postSettingsAgentDeploySetKeyV1` (always **200** no-op).
Future<int> postSettingsAgentDeploySetKeyV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/agent-deploy/set-key');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
