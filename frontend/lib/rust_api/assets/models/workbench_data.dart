part of '../../index.dart';

/// One row in workbench **`POST …/projects/{project_id}/assets/workbench/material-data`** response **`data`**.
class WorkbenchAssetMaterialDataItem {
  const WorkbenchAssetMaterialDataItem({
    required this.id,
    required this.name,
    required this.filePath,
    required this.assetType,
  });

  final int id;
  final String name;
  final String filePath;
  final String assetType;

  factory WorkbenchAssetMaterialDataItem.fromJson(Map<String, dynamic> json) {
    return WorkbenchAssetMaterialDataItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
    );
  }
}

/// One row in workbench **`POST …/projects/{project_id}/assets/workbench/material-data`** response **`video`**.
class WorkbenchAssetMaterialVideoItem {
  const WorkbenchAssetMaterialVideoItem({
    required this.id,
    required this.filePath,
    this.videoTrackId,
  });

  final int id;
  final String filePath;
  final int? videoTrackId;

  factory WorkbenchAssetMaterialVideoItem.fromJson(Map<String, dynamic> json) {
    return WorkbenchAssetMaterialVideoItem(
      id: (json['id'] as num).toInt(),
      filePath: json['filePath'] as String? ?? '',
      videoTrackId: (json['videoTrackId'] as num?)?.toInt(),
    );
  }
}

/// Body of workbench **`POST …/projects/{project_id}/assets/workbench/material-data`** (empty **`{}`**).
class WorkbenchAssetMaterialDataResponse {
  const WorkbenchAssetMaterialDataResponse({
    required this.data,
    required this.video,
  });

  final List<WorkbenchAssetMaterialDataItem> data;
  final List<WorkbenchAssetMaterialVideoItem> video;

  factory WorkbenchAssetMaterialDataResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawData = json['data'] as List<dynamic>? ?? const [];
    final rawVideo = json['video'] as List<dynamic>? ?? const [];
    return WorkbenchAssetMaterialDataResponse(
      data: rawData
          .map(
            (e) => WorkbenchAssetMaterialDataItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      video: rawVideo
          .map(
            (e) => WorkbenchAssetMaterialVideoItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// One row in workbench **`POST …/projects/{project_id}/assets/workbench/batch-generation-data`** response **`data`**.
class WorkbenchAssetBatchGenerationItem {
  const WorkbenchAssetBatchGenerationItem({
    required this.id,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
  });

  final int id;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;

  factory WorkbenchAssetBatchGenerationItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkbenchAssetBatchGenerationItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
      description: json['description'] as String?,
      createTimeMs: (json['createTimeMs'] as num?)?.toInt(),
    );
  }
}

/// Body of workbench **`POST …/projects/{project_id}/assets/workbench/batch-generation-data`**.
class WorkbenchAssetBatchGenerationResponse {
  const WorkbenchAssetBatchGenerationResponse({
    required this.data,
    required this.total,
  });

  final List<WorkbenchAssetBatchGenerationItem> data;
  final int total;

  factory WorkbenchAssetBatchGenerationResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawData = json['data'] as List<dynamic>? ?? const [];
    return WorkbenchAssetBatchGenerationResponse(
      data: rawData
          .map(
            (e) => WorkbenchAssetBatchGenerationItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
