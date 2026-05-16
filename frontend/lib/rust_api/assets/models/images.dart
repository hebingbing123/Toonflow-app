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
  const ListAssetImagesResponse({
    this.coverNumericImageId,
    required this.items,
  });

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
