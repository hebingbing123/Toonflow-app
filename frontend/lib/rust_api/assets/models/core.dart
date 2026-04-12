part of '../../index.dart';

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
            (e) => WorkbenchAssetTreeItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// Body from workbench **`POST …/projects/{project_id}/assets/workbench/nested`**.
class WorkbenchAssetTreeResponse {
  const WorkbenchAssetTreeResponse({required this.data, required this.total});

  final List<WorkbenchAssetTreeItem> data;
  final int total;

  factory WorkbenchAssetTreeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return WorkbenchAssetTreeResponse(
      data: raw
          .map(
            (e) => WorkbenchAssetTreeItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}
