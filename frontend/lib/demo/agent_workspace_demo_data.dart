/// Sample agent workspace activity feed for demo mode.
class AgentWorkspaceDemoSnapshot {
  const AgentWorkspaceDemoSnapshot({
    required this.wsLogLines,
    required this.assistantText,
    this.lastToolResultLine,
    this.writebackLine,
    this.suggestedFlowKey,
  });

  final List<String> wsLogLines;
  final String assistantText;
  final String? lastToolResultLine;
  final String? writebackLine;
  final String? suggestedFlowKey;
}

AgentWorkspaceDemoSnapshot buildDemoAgentWorkspaceSnapshot() {
  return const AgentWorkspaceDemoSnapshot(
    wsLogLines: <String>[
      '{"type":"session","status":"connected","mode":"demo"}',
      '{"type":"tool_call","name":"list_scripts","status":"completed"}',
      '{"type":"assistant","content":"已列出 2 个剧本，建议从第 1 集继续分镜。"}',
      '{"type":"tool_call","name":"list_storyboards","status":"completed"}',
      '{"type":"tool_result","summary":"script_count=2, storyboard_ready=4"}',
      '{"type":"tool_call","name":"short_video_assembly_preview","status":"completed"}',
      '{"type":"assistant","content":"装配预览：3 镜已就绪，1 镜待补素材。"}',
    ],
    assistantText:
        '演示助手：项目「春季短剧 · 演示」六步流程数据已载入。'
        '剧本 2 集、分镜 3 镜、装配/发布/质量面板均可浏览；'
        '运行 Agent 仅展示演示反馈，不会写入后端。',
    lastToolResultLine: 'short_video_assembly_preview → 3 shots, export_ready=true',
    writebackLine: '（演示）写回已禁用 — 切换正式登录后可执行真实写回',
    suggestedFlowKey: 'storyboard_batch_v2',
  );
}
