part of 'production.dart';

class BatchGenerateAssetsImageResponseV1 {
  const BatchGenerateAssetsImageResponseV1({
    required this.enqueued,
    required this.total,
  });

  final List<JobRow> enqueued;
  final int total;

  factory BatchGenerateAssetsImageResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['enqueued'] as List<dynamic>? ?? const [];
    return BatchGenerateAssetsImageResponseV1(
      enqueued: raw
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/assets/batch-generate-assets-image` — OpenAPI `postAssetsBatchGenerateAssetsImageV1`.
Future<BatchGenerateAssetsImageResponseV1>
postProductionAssetsBatchGenerateAssetsImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> assetIds,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/batch-generate-assets-image',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'assetIds': assetIds,
  };
  if (model != null) body['model'] = model;
  if (resolution != null) body['resolution'] = resolution;
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchGenerateAssetsImageResponseV1.fromJson(map);
}

/// OpenAPI **`DeleteAssetsDerivativeResponse`**.
class DeleteAssetsDerivativeResponseV1 {
  const DeleteAssetsDerivativeResponseV1({
    required this.deleted,
    required this.assetIds,
  });

  final int deleted;
  final List<int> assetIds;

  factory DeleteAssetsDerivativeResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['assetIds'] as List<dynamic>? ?? const [];
    return DeleteAssetsDerivativeResponseV1(
      deleted: (json['deleted'] as num).toInt(),
      assetIds: raw.map((e) => (e as num).toInt()).toList(),
    );
  }
}

/// `POST /api/v1/production/assets/delete-assets-derivative` — OpenAPI `postAssetsDeleteAssetsDerivativeV1`.
Future<DeleteAssetsDerivativeResponseV1>
postProductionAssetsDeleteAssetsDerivativeV1(
  String accessToken, {
  required int projectId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/delete-assets-derivative',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'assetIds': assetIds}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteAssetsDerivativeResponseV1.fromJson(map);
}

/// OpenAPI **`AssetDataItem`**.
class AssetDataItemV1 {
  const AssetDataItemV1({
    required this.id,
    required this.name,
    required this.type,
    this.describe,
    this.coverLegacyImageId,
    this.createdAt,
  });

  final int id;
  final String name;
  final String type;
  final String? describe;
  final int? coverLegacyImageId;
  final DateTime? createdAt;

  factory AssetDataItemV1.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    final raw = json['createdAt'];
    if (raw is String) parsed = DateTime.tryParse(raw);
    return AssetDataItemV1(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      describe: json['describe'] as String?,
      coverLegacyImageId: json['coverLegacyImageId'] == null
          ? null
          : (json['coverLegacyImageId'] as num).toInt(),
      createdAt: parsed,
    );
  }
}

/// OpenAPI **`AssetsDataResponse`**.
class AssetsDataResponseV1 {
  const AssetsDataResponseV1({required this.assets, required this.total});

  final List<AssetDataItemV1> assets;
  final int total;

  factory AssetsDataResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['assets'] as List<dynamic>? ?? const [];
    return AssetsDataResponseV1(
      assets: raw
          .map((e) => AssetDataItemV1.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/assets/get-assets-data` — OpenAPI `postAssetsGetAssetsDataV1`.
Future<AssetsDataResponseV1> postProductionAssetsGetAssetsDataV1(
  String accessToken, {
  required int projectId,
  String? assetType,
  int limit = 50,
  int offset = 0,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/get-assets-data',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'limit': limit,
    'offset': offset,
  };
  if (assetType != null) body['assetType'] = assetType;
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetsDataResponseV1.fromJson(map);
}

/// OpenAPI **`AssetImageStatus`**.
class AssetImageStatusV1 {
  const AssetImageStatusV1({
    required this.assetId,
    required this.imageCount,
    this.latestState,
  });

  final int assetId;
  final int imageCount;
  final String? latestState;

  factory AssetImageStatusV1.fromJson(Map<String, dynamic> json) {
    return AssetImageStatusV1(
      assetId: (json['assetId'] as num).toInt(),
      imageCount: (json['imageCount'] as num).toInt(),
      latestState: json['latestState'] as String?,
    );
  }
}

/// OpenAPI **`AssetsPollingImageResponse`**.
class AssetsPollingImageResponseV1 {
  const AssetsPollingImageResponseV1({required this.statuses});

  final List<AssetImageStatusV1> statuses;

  factory AssetsPollingImageResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['statuses'] as List<dynamic>? ?? const [];
    return AssetsPollingImageResponseV1(
      statuses: raw
          .map((e) => AssetImageStatusV1.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// `POST /api/v1/production/assets/polling-image` — OpenAPI `postAssetsPollingImageV1`.
Future<AssetsPollingImageResponseV1> postProductionAssetsPollingImageV1(
  String accessToken, {
  required int projectId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/assets/polling-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'assetIds': assetIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetsPollingImageResponseV1.fromJson(map);
}

/// OpenAPI **`UpdateAssetsUrlResponse`**.
class UpdateAssetsUrlResponseV1 {
  const UpdateAssetsUrlResponseV1({
    required this.assetId,
    required this.imageUrl,
    required this.message,
  });

  final int assetId;
  final String imageUrl;
  final String message;

  factory UpdateAssetsUrlResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateAssetsUrlResponseV1(
      assetId: (json['assetId'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/assets/update-assets-url` — OpenAPI `postAssetsUpdateAssetsUrlV1`.
Future<UpdateAssetsUrlResponseV1> postProductionAssetsUpdateAssetsUrlV1(
  String accessToken, {
  required int projectId,
  required int assetId,
  required String imageUrl,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/update-assets-url',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'assetId': assetId,
          'imageUrl': imageUrl,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UpdateAssetsUrlResponseV1.fromJson(map);
}
