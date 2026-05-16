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

  factory WorkbenchAssetPollingImageItem.fromJson(Map<String, dynamic> json) {
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

  factory WorkbenchAssetPollingPromptItem.fromJson(Map<String, dynamic> json) {
    return WorkbenchAssetPollingPromptItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      assetType: json['type'] as String? ?? '',
      promptState: json['promptState'] as String? ?? '',
    );
  }
}
