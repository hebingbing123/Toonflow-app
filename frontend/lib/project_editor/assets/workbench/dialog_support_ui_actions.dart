part of 'dialog_support.dart';

class _ProjectAssetsWorkbenchActions extends StatelessWidget {
  const _ProjectAssetsWorkbenchActions({
    required this.localBusy,
    required this.assetsBusy,
    required this.assets,
    required this.scriptList,
    required this.selectedScriptNumericId,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onFilter,
    required this.onLink,
    required this.onUnlink,
    required this.onUploadEditImage,
    required this.onUploadClip,
  });

  final bool localBusy;
  final bool assetsBusy;
  final List<AssetRow> assets;
  final List<ScriptBrief> scriptList;
  final int? selectedScriptNumericId;
  final VoidCallback onCreate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onFilter;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onUploadEditImage;
  final VoidCallback onUploadClip;

  @override
  Widget build(BuildContext context) {
    final canMutateAssets = !(localBusy || assetsBusy || assets.isEmpty);
    final canLinkScripts =
        !(localBusy ||
            assetsBusy ||
            assets.isEmpty ||
            scriptList.isEmpty ||
            selectedScriptNumericId == null);
    final canUploadEditImage = !(localBusy || assetsBusy || scriptList.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: localBusy || assetsBusy ? null : onCreate,
              child: const Text('新建资产'),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onEdit : null,
              child: const Text('编辑资产'),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onDelete : null,
              child: const Text('删除资产'),
            ),
            OutlinedButton(
              onPressed: canMutateAssets ? onFilter : null,
              child: const Text('筛选资产'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: canLinkScripts ? onLink : null,
              child: const Text('关联剧本与资产'),
            ),
            OutlinedButton(
              onPressed: canLinkScripts ? onUnlink : null,
              child: const Text('取消关联'),
            ),
            OutlinedButton(
              onPressed: canUploadEditImage ? onUploadEditImage : null,
              child: const Text('上传编辑图片'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onUploadClip,
              child: const Text('上传 Clip 资产'),
            ),
          ],
        ),
      ],
    );
  }
}

