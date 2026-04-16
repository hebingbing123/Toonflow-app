import 'package:flutter/material.dart';

class WorkspaceInputController {
  final TextEditingController projectIdController = TextEditingController(
    text: '1',
  );
  final TextEditingController scriptIdController = TextEditingController(
    text: '1',
  );
  final TextEditingController scriptPromptController = TextEditingController(
    text: '先读取 get_planData 与 get_novel_events，总结当前剧情骨架缺口，再给出下一轮 script 生成建议。',
  );
  final TextEditingController scriptDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController productionPromptController =
      TextEditingController(
        text: '先调用 get_flowData key=assets，然后总结当前资产与可执行的下一步 production 操作。',
      );
  final TextEditingController productionFlowKeyController =
      TextEditingController(text: 'assets');
  final TextEditingController productionDomainToolController =
      TextEditingController(text: 'get_flowData');
  final TextEditingController productionDomainArgsController =
      TextEditingController(text: '{}');
  final TextEditingController scriptSubAgentToolController =
      TextEditingController(text: 'run_sub_agent_storySkeleton');
  final TextEditingController productionSubAgentToolController =
      TextEditingController(text: 'run_sub_agent_director_plan');

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
  }
}
