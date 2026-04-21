part of 'dialog_support.dart';

class _ProjectAssetsWorkbenchLaunchers extends StatelessWidget {
  const _ProjectAssetsWorkbenchLaunchers({
    required this.localBusy,
    required this.assetsBusy,
    required this.onOpenImagesWorkbench,
    required this.onOpenGenerationWorkbench,
    required this.onOpenHistoryWorkbench,
  });

  final bool localBusy;
  final bool assetsBusy;
  final VoidCallback onOpenImagesWorkbench;
  final VoidCallback onOpenGenerationWorkbench;
  final VoidCallback onOpenHistoryWorkbench;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('专项工作台', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '把图片管理、出图链路和历史图查询也统一挂到这里，资产主区只保留一个正式入口。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenImagesWorkbench,
              child: const Text('资产图片工作台'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenGenerationWorkbench,
              child: const Text('资产出图工作台'),
            ),
            OutlinedButton(
              onPressed: localBusy || assetsBusy ? null : onOpenHistoryWorkbench,
              child: const Text('资产历史图工作台'),
            ),
          ],
        ),
      ],
    );
  }
}

