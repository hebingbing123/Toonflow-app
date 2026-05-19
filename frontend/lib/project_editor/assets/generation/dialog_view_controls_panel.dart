import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
part of 'dialog_view.dart';

class _AssetGenerationControlsPanel extends StatelessWidget {
  const _AssetGenerationControlsPanel({
    required this.busy,
    required this.scriptList,
    required this.typeSelections,
    required this.selectedScriptNumericId,
    required this.selectedType,
    required this.accessToken,
    required this.batchAssetCount,
    required this.onBatchEstimateChanged,
    required this.modelCtrl,
    required this.resolutionCtrl,
    required this.imageUrlCtrl,
    required this.batchNameCtrl,
    required this.batchLimitCtrl,
    required this.onScriptChanged,
    required this.onTypeChanged,
    required this.onImageUrlChanged,
  });

  final bool busy;
  final List<ScriptBrief> scriptList;
  final Map<String, List<int>> typeSelections;
  final int selectedScriptNumericId;
  final String selectedType;
  final String accessToken;
  final int batchAssetCount;
  final ValueChanged<BillingEstimateResponse?> onBatchEstimateChanged;
  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController batchNameCtrl;
  final TextEditingController batchLimitCtrl;
  final ValueChanged<int> onScriptChanged;
  final ValueChanged<String> onImageUrlChanged;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StudioDropdownButtonFormField<int>(
                initialValue: selectedScriptNumericId,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorAssetGenWorkbenchScriptLabel,
                  helperText: l10n.projectEditorAssetGenWorkbenchScriptHelper,
                ),
                items: scriptList
                    .map(
                      (script) => DropdownMenuItem<int>(
                        value: script.numericId,
                        child: Text(
                          '#${script.numericId} ${script.name ?? ""}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: busy
                    ? null
                    : (value) {
                        if (value == null) return;
                        onScriptChanged(value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StudioDropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorAssetGenWorkbenchAssetTypeLabel,
                  helperText: l10n.projectEditorAssetGenWorkbenchAssetTypeHelper,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(l10n.projectEditorAssetGenWorkbenchAssetTypeAll),
                  ),
                  ...typeSelections.keys.map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(projectEditorAssetTypeLabel(l10n, type)),
                    ),
                  ),
                ],
                onChanged: busy ? null : (value) => onTypeChanged(value ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StudioModelCostControls(
          accessToken: accessToken,
          taskKind: 'asset_image_batch',
          typeFilter: 'image',
          quantity: batchAssetCount,
          modelValueController: modelCtrl,
          enabled: !busy,
          onEstimateChanged: onBatchEstimateChanged,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: resolutionCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorAssetGenWorkbenchResolutionOptionalLabel,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: batchNameCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorAssetGenWorkbenchBatchNameFilterOptionalLabel,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: batchLimitCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorAssetGenWorkbenchBatchLimitLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: imageUrlCtrl,
          onChanged: onImageUrlChanged,
          decoration: InputDecoration(
            labelText: l10n.projectEditorAssetGenWorkbenchCoverUrlLabel,
            helperText: l10n.projectEditorAssetGenWorkbenchCoverUrlHelper,
          ),
        ),
      ],
    );
  }
}

