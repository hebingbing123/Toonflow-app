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

/// `POST /api/v1/settings/agent-deploy/deploy-model` — OpenAPI `postSettingsAgentDeployModelV1` (typically **501**).
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

/// `POST /api/v1/settings/agent-deploy/set-key` — OpenAPI `postSettingsAgentDeploySetKeyV1` (typically **501**).
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

/// `POST /api/v1/settings/vendors/model-test` — OpenAPI `postSettingsVendorModelTestV1`.
/// **200** = **`queued`** **`JobRow`** (**`settings.vendor.model_test`**); **429**/**503** as elsewhere.
Future<int> postSettingsVendorModelTestV1(
  String accessToken, {
  required String modelName,
  required String type,
  required String id,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/model-test');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'modelName': modelName, 'type': type, 'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/update` — OpenAPI `postSettingsVendorsUpdateV1` (typically **501**).
Future<int> postSettingsVendorsUpdateV1(
  String accessToken, {
  required String id,
  Map<String, String>? inputValues,
  List<dynamic> inputs = const [],
  List<dynamic> models = const [],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/update');
  final body = <String, dynamic>{'id': id, 'inputs': inputs, 'models': models};
  if (inputValues != null) {
    body['inputValues'] = inputValues;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/delete` — OpenAPI `postSettingsVendorsDeleteV1` (typically **501**).
Future<int> postSettingsVendorsDeleteV1(
  String accessToken, {
  required String id,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/delete');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/enable` — OpenAPI `postSettingsVendorsEnableV1` (typically **501**).
Future<int> postSettingsVendorsEnableV1(
  String accessToken, {
  required String id,
  required num enable,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/enable');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id, 'enable': enable}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/update-code` — OpenAPI `postSettingsVendorsUpdateCodeV1` (typically **501**).
Future<int> postSettingsVendorsUpdateCodeV1(
  String accessToken, {
  required String id,
  required String tsCode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/update-code');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id, 'tsCode': tsCode}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/code-from-link` — OpenAPI `postSettingsVendorsCodeFromLinkV1` (typically **501**).
Future<int> postSettingsVendorsCodeFromLinkV1(
  String accessToken, {
  required String link,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/code-from-link');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'link': link}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/vendors/add` — OpenAPI `postSettingsVendorsAddV1` (typically **501**).
Future<int> postSettingsVendorsAddV1(
  String accessToken, {
  required String tsCode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/vendors/add');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'tsCode': tsCode}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/danger/delete-all-data` — OpenAPI `postSettingsDangerDeleteAllDataV1` (typically **501**).
Future<int> postSettingsDangerDeleteAllDataV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/danger/delete-all-data');
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

/// `POST /api/v1/settings/danger/clear-database` — OpenAPI `postSettingsDangerClearDatabaseV1` (typically **501**).
Future<int> postSettingsDangerClearDatabaseV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/danger/clear-database');
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

/// OpenAPI **`AboutCheckUpdateResponse`** — legacy desktop **`checkUpdate`** shape (**camelCase**).
class AboutCheckUpdateResponseV1 {
  const AboutCheckUpdateResponseV1({
    required this.needUpdate,
    required this.latestVersion,
    required this.reinstall,
    required this.time,
    this.url,
  });

  final bool needUpdate;
  final String latestVersion;
  final bool reinstall;
  final String time;
  final String? url;

  factory AboutCheckUpdateResponseV1.fromJson(Map<String, dynamic> json) {
    return AboutCheckUpdateResponseV1(
      needUpdate: json['needUpdate'] as bool,
      latestVersion: json['latestVersion'] as String,
      reinstall: json['reinstall'] as bool,
      time: json['time'] as String,
      url: json['url'] as String?,
    );
  }
}

/// `POST /api/v1/settings/about/check-update` — OpenAPI `postAboutCheckUpdateV1`.
Future<AboutCheckUpdateResponseV1> postAboutCheckUpdateV1(
  String accessToken,
  String source,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/about/check-update');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'source': source}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AboutCheckUpdateResponseV1.fromJson(map);
}

/// `POST /api/v1/settings/about/download-app` — OpenAPI `postAboutDownloadAppV1` (typically **501**).
Future<int> postAboutDownloadAppV1(
  String accessToken, {
  required String url,
  required bool reinstall,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/about/download-app');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url, 'reinstall': reinstall}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
