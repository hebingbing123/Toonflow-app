part of 'support.dart';

class ScriptWorkspaceRecipe {
  const ScriptWorkspaceRecipe({
    required this.title,
    required this.detail,
    this.domainTool,
    this.subAgentTool,
    this.prompt,
    this.args,
  });

  final String title;
  final String detail;
  final String? domainTool;
  final String? subAgentTool;
  final String? prompt;
  final Map<String, dynamic>? args;
}

class ScriptWorkspaceStage {
  const ScriptWorkspaceStage({
    required this.title,
    required this.statusLabel,
    required this.detail,
    this.domainTool,
    this.subAgentTool,
    this.prompt,
    this.args,
  });

  final String title;
  final String statusLabel;
  final String detail;
  final String? domainTool;
  final String? subAgentTool;
  final String? prompt;
  final Map<String, dynamic>? args;
}

class ScriptWorkspaceArgumentSuggestion {
  const ScriptWorkspaceArgumentSuggestion({
    required this.label,
    required this.payload,
  });

  final String label;
  final Map<String, dynamic> payload;
}

class ScriptWorkspaceReview {
  const ScriptWorkspaceReview({
    required this.target,
    required this.grade,
    required this.severeCount,
    required this.mediumCount,
    required this.minorCount,
    required this.nextAction,
    required this.summary,
  });

  final String target;
  final String grade;
  final int severeCount;
  final int mediumCount;
  final int minorCount;
  final String nextAction;
  final String summary;
}
