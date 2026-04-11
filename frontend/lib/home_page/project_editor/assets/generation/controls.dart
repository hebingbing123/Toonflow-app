part of '../../../../home_page.dart';

/// Groups the top filter and input controls for the asset generation workbench.
class _AssetGenerationControlsPanel extends StatelessWidget {
  const _AssetGenerationControlsPanel({
    required this.busy,
    required this.scriptList,
    required this.visibleAssets,
    required this.typeSelections,
    required this.selectedScriptLegacyId,
    required this.selectedType,
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
  final List<AssetRow> visibleAssets;
  final Map<String, List<int>> typeSelections;
  final int selectedScriptLegacyId;
  final String selectedType;
  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController batchNameCtrl;
  final TextEditingController batchLimitCtrl;
  final ValueChanged<int> onScriptChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onImageUrlChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedScriptLegacyId,
                decoration: const InputDecoration(
                  labelText: '生成使用的剧本',
                  helperText: '批量出图会把所选资产投给这个剧本上下文',
                ),
                items: scriptList
                    .map(
                      (script) => DropdownMenuItem<int>(
                        value: script.legacyId,
                        child: Text(
                          '#${script.legacyId} ${script.name ?? ""}',
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
              child: DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: '资产类型筛选',
                  helperText: '同时影响 production 摘要读取和可见选择集',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('（全部类型）'),
                  ),
                  ...typeSelections.keys.map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) => onTypeChanged(value ?? ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(labelText: '模型（可选）'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: resolutionCtrl,
                decoration: const InputDecoration(labelText: '分辨率（可选）'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: batchNameCtrl,
                decoration: const InputDecoration(labelText: '批量候选名称过滤（可选）'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: batchLimitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '候选 limit'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: imageUrlCtrl,
          onChanged: onImageUrlChanged,
          decoration: const InputDecoration(
            labelText: '更新封面 URL（单选时可用）',
            helperText: '用于 production/assets/update-assets-url',
          ),
        ),
      ],
    );
  }
}
