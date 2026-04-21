part of 'workbench_support.dart';

class _AssetImageMutationRequestPlan {
  const _AssetImageMutationRequestPlan({
    required this.successSummary,
    required this.failureSummary,
    required this.recommendedAction,
    required this.fallbackDetail,
  });

  final String successSummary;
  final String failureSummary;
  final AssetImagesWorkbenchRecommendedAction recommendedAction;
  final String fallbackDetail;
}

class _SelectedAssetImageMutationPlan {
  const _SelectedAssetImageMutationPlan({
    required this.missingSelectionNotice,
    required this.requestPlan,
    required this.request,
  });

  final String missingSelectionNotice;
  final _AssetImageMutationRequestPlan requestPlan;
  final Future<void> Function(AssetImageRow image) request;
}

class _AssetImageMutationPlan {
  const _AssetImageMutationPlan({
    required this.requestPlan,
    required this.request,
  });

  final _AssetImageMutationRequestPlan requestPlan;
  final Future<void> Function() request;
}

const _createAssetImageRequestPlan = _AssetImageMutationRequestPlan(
  successSummary: '已新增资产图片。',
  failureSummary: '新增资产图片失败。',
  recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
  fallbackDetail: '建议检查 file_path、state 或 sort_index 后重试。',
);

const _patchAssetImageRequestPlan = _AssetImageMutationRequestPlan(
  successSummary: '已更新当前图片。',
  failureSummary: '更新当前图片失败。',
  recommendedAction: AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
  fallbackDetail: '建议先重新读取预览，确认当前图片后再修改。',
);

const _deleteAssetImageRequestPlan = _AssetImageMutationRequestPlan(
  successSummary: '已删除当前图片。',
  failureSummary: '删除当前图片失败。',
  recommendedAction: AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
  fallbackDetail: '建议先刷新图片列表，确认当前选择后再删除。',
);

