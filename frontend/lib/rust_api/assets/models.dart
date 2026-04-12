part of '../index.dart';

/// Row from **`GET …/projects/{project_id}/assets`** — OpenAPI **`AssetRow`**.
class AssetRow {
  const AssetRow({
    required this.id,
    required this.numericId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
  });

  final String id;
  final int numericId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;

  factory AssetRow.fromJson(Map<String, dynamic> json) {
    return AssetRow(
      id: json['id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Body of **`GET …/assets`** — OpenAPI **`ListAssetsResponse`**.
class ListAssetsResponse {
  const ListAssetsResponse({required this.items, required this.total});

  final List<AssetRow> items;
  final int total;

  factory ListAssetsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetsResponse(
      items: raw
          .map((e) => AssetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One row from workbench **`POST …/projects/{project_id}/assets/workbench/nested`** (including nested children via **`sonAssets`**).
class WorkbenchAssetTreeItem {
  const WorkbenchAssetTreeItem({
    required this.id,
    required this.projectId,
    required this.assetType,
    required this.name,
    this.assetsId,
    this.imageId,
    this.filePath,
    this.state,
    this.errorReason,
    this.src,
    required this.sonAssets,
  });

  final int id;
  final int projectId;
  final String assetType;
  final String name;
  final int? assetsId;
  final int? imageId;
  final String? filePath;
  final String? state;
  final String? errorReason;
  final String? src;
  final List<WorkbenchAssetTreeItem> sonAssets;

  factory WorkbenchAssetTreeItem.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['sonAssets'] as List<dynamic>? ?? const [];
    return WorkbenchAssetTreeItem(
      id: (json['id'] as num).toInt(),
      projectId: (json['projectId'] as num?)?.toInt() ?? 0,
      assetType: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      assetsId: (json['assetsId'] as num?)?.toInt(),
      imageId: (json['imageId'] as num?)?.toInt(),
      filePath: json['filePath'] as String?,
      state: json['state'] as String?,
      errorReason: json['errorReason'] as String?,
      src: json['src'] as String?,
      sonAssets: rawChildren
          .map(
            (e) =>
                WorkbenchAssetTreeItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Body from workbench **`POST …/projects/{project_id}/assets/workbench/nested`**.
class WorkbenchAssetTreeResponse {
  const WorkbenchAssetTreeResponse({
    required this.data,
    required this.total,
  });

  final List<WorkbenchAssetTreeItem> data;
  final int total;

  factory WorkbenchAssetTreeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return WorkbenchAssetTreeResponse(
      data: raw
          .map(
            (e) =>
                WorkbenchAssetTreeItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One **`app_asset_image`** row in **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeHistoryImage`**.
class CornerScapeHistoryImage {
  const CornerScapeHistoryImage({
    required this.id,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.numericImageId,
  });

  final String id;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? numericImageId;

  factory CornerScapeHistoryImage.fromJson(Map<String, dynamic> json) {
    return CornerScapeHistoryImage(
      id: json['id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      numericImageId: (json['numeric_image_id'] as num?)?.toInt(),
    );
  }
}

/// One row from **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeAssetItem`**.
class CornerScapeAssetItem {
  const CornerScapeAssetItem({
    required this.id,
    required this.numericId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
    required this.metadata,
    required this.historyImages,
  });

  final String id;
  final int numericId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;
  final Map<String, dynamic> metadata;
  final List<CornerScapeHistoryImage> historyImages;

  factory CornerScapeAssetItem.fromJson(Map<String, dynamic> json) {
    final histRaw = json['history_images'] as List<dynamic>? ?? const [];
    final hist = histRaw
        .map((e) => CornerScapeHistoryImage.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['metadata'];
    return CornerScapeAssetItem(
      id: json['id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: (json['create_time_ms'] as num?)?.toInt(),
      metadata: meta is Map<String, dynamic> ? meta : <String, dynamic>{},
      historyImages: hist,
    );
  }
}

/// OpenAPI **`AssetImageRow`** — response from **`POST …/assets/{aid}/images`** (and list items share these fields).
class AssetImageRow {
  const AssetImageRow({
    required this.id,
    required this.assetId,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.numericImageId,
    this.selected,
  });

  final String id;
  final String assetId;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? numericImageId;

  /// Present on **`GET …/images`** list items only (`AssetImageListItem`).
  final bool? selected;

  factory AssetImageRow.fromJson(Map<String, dynamic> json) {
    return AssetImageRow(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      numericImageId: (json['numeric_image_id'] as num?)?.toInt(),
      selected: json['selected'] as bool?,
    );
  }
}

/// OpenAPI **`ListAssetImagesResponse`**.
class ListAssetImagesResponse {
  const ListAssetImagesResponse({this.coverNumericImageId, required this.items});

  final int? coverNumericImageId;
  final List<AssetImageRow> items;

  factory ListAssetImagesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetImagesResponse(
      coverNumericImageId: (json['cover_numeric_image_id'] as num?)?.toInt(),
      items: raw
          .map((e) => AssetImageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One item in workbench **`POST …/projects/{project_id}/assets/workbench/image-bundle`** response **`tempAssets`**.
class WorkbenchImageBundleTempAsset {
  const WorkbenchImageBundleTempAsset({
    this.numericImageId,
    required this.imageUuid,
    required this.filePath,
    required this.assetsId,
    required this.assetType,
    this.state,
    required this.selected,
  });

  final int? numericImageId;
  final String imageUuid;
  final String filePath;
  final int assetsId;
  final String assetType;
  final String? state;
  final bool selected;

  factory WorkbenchImageBundleTempAsset.fromJson(Map<String, dynamic> json) {
    return WorkbenchImageBundleTempAsset(
      numericImageId: (json['id'] as num?)?.toInt(),
      imageUuid: json['imageUuid'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      assetsId: (json['assetsId'] as num).toInt(),
      assetType: json['type'] as String? ?? '',
      state: json['state'] as String?,
      selected: json['selected'] as bool? ?? false,
    );
  }
}

/// Body of workbench **`POST …/projects/{project_id}/assets/workbench/image-bundle`**.
class WorkbenchImageBundleResponse {
  const WorkbenchImageBundleResponse({
    required this.id,
    this.imageId,
    required this.tempAssets,
  });

  final int id;
  final int? imageId;
  final List<WorkbenchImageBundleTempAsset> tempAssets;

  factory WorkbenchImageBundleResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['tempAssets'] as List<dynamic>? ?? const [];
    return WorkbenchImageBundleResponse(
      id: (json['id'] as num).toInt(),
      imageId: (json['imageId'] as num?)?.toInt(),
      tempAssets: raw
          .map(
            (e) => WorkbenchImageBundleTempAsset.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// Body of workbench **`POST …/projects/{project_id}/assets/workbench/upload-clip`**.
class WorkbenchAssetUploadClipResponse {
  const WorkbenchAssetUploadClipResponse({required this.message});

  final String message;

  factory WorkbenchAssetUploadClipResponse.fromJson(Map<String, dynamic> json) {
    return WorkbenchAssetUploadClipResponse(
      message: json['message'] as String? ?? '',
    );
  }
}

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

  factory WorkbenchAssetMaterialDataResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] as List<dynamic>? ?? const [];
    final rawVideo = json['video'] as List<dynamic>? ?? const [];
    return WorkbenchAssetMaterialDataResponse(
      data: rawData
          .map(
            (e) =>
                WorkbenchAssetMaterialDataItem.fromJson(e as Map<String, dynamic>),
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

/// One row in workbench **`POST …/projects/{project_id}/assets/workbench/polling-image-assets`** response.
class WorkbenchAssetPollingImageItem {
  const WorkbenchAssetPollingImageItem({
    required this.id,
    this.state,
    this.filePath,
  });

  final int id;
  final String? state;
  final String? filePath;

  factory WorkbenchAssetPollingImageItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkbenchAssetPollingImageItem(
      id: (json['id'] as num).toInt(),
      state: json['state'] as String?,
      filePath: json['filePath'] as String?,
    );
  }
}

/// One row in workbench **`POST …/projects/{project_id}/assets/workbench/polling-prompt-assets`** response.
class WorkbenchAssetPollingPromptItem {
  const WorkbenchAssetPollingPromptItem({
    required this.id,
    required this.name,
    required this.assetType,
    required this.promptState,
  });

  final int id;
  final String name;
  final String assetType;
  final String promptState;

  factory WorkbenchAssetPollingPromptItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkbenchAssetPollingPromptItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
      promptState: json['promptState'] as String? ?? '',
    );
  }
}

/// OpenAPI **`CornerScapeResponse`**.
class CornerScapeResponse {
  const CornerScapeResponse({required this.items});

  final List<CornerScapeAssetItem> items;

  factory CornerScapeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return CornerScapeResponse(
      items: raw
          .map((e) => CornerScapeAssetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
