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

/// OpenAPI **`AssetDataItem`**.
class AssetDataItemV1 {
  const AssetDataItemV1({
    required this.id,
    required this.name,
    required this.type,
    this.describe,
    this.coverNumericImageId,
    this.createdAt,
  });

  final int id;
  final String name;
  final String type;
  final String? describe;
  final int? coverNumericImageId;
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
      coverNumericImageId: json['coverNumericImageId'] == null
          ? null
          : (json['coverNumericImageId'] as num).toInt(),
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
