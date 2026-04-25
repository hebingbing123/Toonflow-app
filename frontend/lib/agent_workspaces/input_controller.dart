import 'package:flutter/material.dart';

class WorkspaceInputController {
  final TextEditingController projectIdController = TextEditingController(
    text: '1',
  );
  final TextEditingController scriptIdController = TextEditingController(
    text: '1',
  );
  final TextEditingController scriptPromptController = TextEditingController(
    text:
        '先用 get_planData 读取 storySkeleton/adaptationStrategy 的必要片段，再读目标章节事件；只有细节不足时才补正文窗口，最后给出下一轮 script 建议。',
  );
  final TextEditingController scriptDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController
  productionPromptController = TextEditingController(
    text:
        '先调用 get_flowData key=scriptPlan 读取紧凑导演规划，再按需补最小化 assets 或 storyboardTable，上来不要整包读取 production flow。',
  );
  final TextEditingController productionFlowKeyController =
      TextEditingController(text: 'scriptPlan');
  final TextEditingController productionDomainToolController =
      TextEditingController(text: 'get_flowData');
  final TextEditingController productionDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController scriptSubAgentToolController =
      TextEditingController(text: 'run_sub_agent_storySkeleton');
  final TextEditingController productionSubAgentToolController =
      TextEditingController(text: 'run_sub_agent_director_plan');
  final TextEditingController productionSubAgentArgsController =
      TextEditingController(text: '{}');

  void applySuggestedProductionFlowKey(String? flowKey) {
    final normalized = flowKey?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    productionFlowKeyController.text = normalized;
  }

  void dispose() {
    projectIdController.dispose();
    scriptIdController.dispose();
    scriptPromptController.dispose();
    scriptDomainArgsController.dispose();
    productionPromptController.dispose();
    productionFlowKeyController.dispose();
    productionDomainToolController.dispose();
    productionDomainArgsController.dispose();
    scriptSubAgentToolController.dispose();
    productionSubAgentToolController.dispose();
    productionSubAgentArgsController.dispose();
  }
}
