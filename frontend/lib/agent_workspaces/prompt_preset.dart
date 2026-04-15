/// Shared prompt preset descriptor used by script and production workspaces.
class AgentWorkspacePromptPreset {
  const AgentWorkspacePromptPreset({required this.label, required this.prompt});

  final String label;
  final String prompt;
}
