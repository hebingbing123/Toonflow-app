part of '../../../home_page.dart';

/// Renders the collapsed compatibility actions that keep legacy asset entry points available.
class _ProjectAssetsCompatibilityPanel extends StatelessWidget {
  const _ProjectAssetsCompatibilityPanel({
    required this.ctx,
    required this.setDialogState,
    required this.token,
    required this.project,
    required this.scriptList,
    required this.assetsRef,
    required this.assetsFilterScriptNumericId,
    required this.assetsLoading,
    required this.assetsScriptFilterLoading,
    required this.assetsBusy,
    required this.reloadAssetsAndStats,
    required this.buildImagesSection,
    required this.buildPrimaryActions,
    required this.buildRelationActions,
    required this.buildQueryActions,
  });

  final BuildContext ctx;
  final StateSetter setDialogState;
  final String token;
  final ProjectRow project;
  final List<ScriptBrief> scriptList;
  final List<ListAssetsResponse?> assetsRef;
  final List<int?> assetsFilterScriptNumericId;
  final List<bool> assetsLoading;
  final List<bool> assetsScriptFilterLoading;
  final List<bool> assetsBusy;
  final Future<void> Function() reloadAssetsAndStats;
  final Widget Function() buildImagesSection;
  final List<Widget> Function() buildPrimaryActions;
  final List<Widget> Function() buildRelationActions;
  final List<Widget> Function() buildQueryActions;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('兼容性检查'),
      subtitle: Text(
        '保留旧资产轮询、历史图片和 workbench 形检查入口，默认折叠',
        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
          color: Theme.of(ctx).colorScheme.outline,
        ),
      ),
      children: [
        buildImagesSection(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            ...buildPrimaryActions(),
            ...buildRelationActions(),
            ...buildQueryActions(),
          ],
        ),
      ],
    );
  }
}
