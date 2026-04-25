part of 'section.dart';

const List<String> _flowKeyPresets = <String>[
  'assets',
  'script',
  'scriptPlan',
  'storyboardTable',
  'storyboard',
  'workspaceResult',
];

const List<String> _scriptSubAgentPresets = <String>[
  'run_sub_agent_storySkeleton',
  'run_sub_agent_adaptationStrategy',
  'run_sub_agent_script',
  'run_supervision_agent',
];

const List<String> _scriptDomainToolPresets = <String>[
  'get_planData',
  'get_script_content',
  'get_novel_text',
  'get_novel_events',
];

const List<String> _productionSubAgentPresets = <String>[
  'run_sub_agent_director_plan',
  'run_sub_agent_derive_assets',
  'run_sub_agent_generate_assets',
  'run_sub_agent_production_supervision',
  'run_sub_agent_storyboard_gen',
  'run_sub_agent_storyboard_panel',
  'run_sub_agent_storyboard_table',
];

const List<String> _productionDomainToolPresets = <String>[
  'get_flowData',
  'add_deriveAsset',
  'del_deriveAsset',
  'generate_deriveAsset',
  'generate_storyboard',
];

const List<AgentWorkspacePromptPreset> _scriptPromptPresets =
    <AgentWorkspacePromptPreset>[
      AgentWorkspacePromptPreset(
        label: '剧情骨架',
        prompt:
            '先读取 get_planData 与 get_novel_events，总结当前剧情骨架缺口，再给出下一轮 script 生成建议。',
      ),
      AgentWorkspacePromptPreset(
        label: '章节改编',
        prompt:
            '基于 get_novel_text 与 get_script_content，对当前章节做改编策略建议，输出 3 条可执行脚本改写项。',
      ),
    ];

const List<AgentWorkspacePromptPreset> _productionPromptPresets =
    <AgentWorkspacePromptPreset>[
      AgentWorkspacePromptPreset(
        label: '资产盘点',
        prompt: '先调用 get_flowData key=assets，盘点现有资产状态并给出下一步 production 任务建议。',
      ),
      AgentWorkspacePromptPreset(
        label: '分镜推进',
        prompt:
            '读取 get_flowData key=storyboard，评估当前分镜完成度并给出下一次 generate_storyboard 的执行建议。',
      ),
      AgentWorkspacePromptPreset(
        label: '制作审核',
        prompt:
            '请先读取 get_flowData key=scriptPlan 或 storyboardTable，再调用 production supervision 审核当前制作结果。',
      ),
    ];

bool _isDefaultJsonObject(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty || trimmed == '{}';
}

String _buildScriptToolArgsPresetText({
  required String toolName,
  required String scriptIdText,
}) {
  final scriptId = int.tryParse(scriptIdText.trim());
  final Map<String, dynamic> preset;
  switch (toolName) {
    case 'get_script_content':
      preset = scriptId != null && scriptId > 0
          ? <String, dynamic>{'scriptId': scriptId}
          : <String, dynamic>{'scriptId': 1};
      break;
    case 'get_novel_text':
    case 'get_novel_events':
      preset = <String, dynamic>{'novelId': 1};
      break;
    case 'get_planData':
    default:
      preset = <String, dynamic>{};
      break;
  }
  return jsonEncode(preset);
}

String _buildProductionToolArgsPresetText({
  required String toolName,
  required String scriptIdText,
  required String flowKeyText,
}) {
  final scriptId = int.tryParse(scriptIdText.trim());
  final flowKey = flowKeyText.trim();
  final Map<String, dynamic> preset;
  switch (toolName) {
    case 'get_flowData':
      preset = <String, dynamic>{
        'key': flowKey.isEmpty ? 'assets' : flowKey,
        if (scriptId != null && scriptId > 0) 'scriptId': scriptId,
      };
      break;
    case 'add_deriveAsset':
    case 'del_deriveAsset':
    case 'generate_deriveAsset':
    case 'generate_storyboard':
      preset = <String, dynamic>{
        'ids': <int>[1],
      };
      break;
    default:
      preset = <String, dynamic>{};
      break;
  }
  return jsonEncode(preset);
}
