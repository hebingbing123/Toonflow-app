import 'package:flutter/material.dart';

import '../../../design_system/components/studio_text_styles.dart';
import '../../../rust_api.dart';

/// Renders collapsed asset probe actions for project editor diagnostics.
class ProjectAssetsCompatibilityPanel extends StatelessWidget {
  const ProjectAssetsCompatibilityPanel({
    super.key,
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.projectEditorAssetsCompatibilityPanelTitle),
      subtitle: Text(
        l10n.projectEditorAssetsCompatibilityPanelSubtitle,
        style: studioHintStyle(ctx),
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
