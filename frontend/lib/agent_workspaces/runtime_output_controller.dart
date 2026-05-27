import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'workspace_scope_utils.dart';

class WorkspaceOutputController extends ChangeNotifier {
  WorkspaceOutputController({AppLocalizations? Function()? l10nProvider})
    : _l10nProvider = l10nProvider;

  final AppLocalizations? Function()? _l10nProvider;

  AppLocalizations get _l10nResolved =>
      _l10nProvider?.call() ?? lookupAppLocalizations(const Locale('en'));

  String _assistantText = '';
  String? _lastToolResultLine;
  String? _lastToolName;
  Object? _lastToolResultData;
  Map<String, dynamic>? _lastToolArguments;
  String? _suggestedFlowKey;
  String? _scriptWritebackCandidate;
  Map<String, dynamic>? _scriptPlanWritebackCandidate;
  int? _scriptPlanRowId;
  String? _scriptWritebackSource;
  String? _writebackLine;
  String? _pendingToolName;
  Map<String, dynamic>? _pendingToolArguments;

  String get assistantText => _assistantText;
  String? get lastToolResultLine => _lastToolResultLine;
  String? get lastToolName => _lastToolName;
  Object? get lastToolResultData => _lastToolResultData;
  Map<String, dynamic>? get lastToolArguments => _lastToolArguments;
  String? get suggestedFlowKey => _suggestedFlowKey;
  String? get scriptWritebackCandidate => _scriptWritebackCandidate;
  Map<String, dynamic>? get scriptPlanWritebackCandidate =>
      _scriptPlanWritebackCandidate;
  int? get scriptPlanRowId => _scriptPlanRowId;
  String? get scriptWritebackSource => _scriptWritebackSource;
  String? get writebackLine => _writebackLine;

  void reset() {
    _assistantText = '';
    _lastToolResultLine = null;
    _lastToolName = null;
    _lastToolResultData = null;
    _lastToolArguments = null;
    _suggestedFlowKey = null;
    _scriptWritebackCandidate = null;
    _scriptPlanWritebackCandidate = null;
    _scriptPlanRowId = null;
    _scriptWritebackSource = null;
    _writebackLine = null;
    _pendingToolName = null;
    _pendingToolArguments = null;
    notifyListeners();
  }

  void applyDemoPreview({
    required String assistantText,
    String? lastToolResultLine,
    String? writebackLine,
    String? suggestedFlowKey,
  }) {
    _assistantText = assistantText;
    _lastToolResultLine = lastToolResultLine;
    _writebackLine = writebackLine;
    _suggestedFlowKey = suggestedFlowKey;
    notifyListeners();
  }

  void clearWritebackLine() {
    if (_writebackLine == null) {
      return;
    }
    _writebackLine = null;
    notifyListeners();
  }

  void setWritebackLine(String? value) {
    if (_writebackLine == value) {
      return;
    }
    _writebackLine = value;
    notifyListeners();
  }

  void markAgentStarted() {
    _assistantText = '';
    _scriptWritebackCandidate = null;
    _scriptPlanWritebackCandidate = null;
    _scriptPlanRowId = null;
    _scriptWritebackSource = null;
    _writebackLine = null;
    notifyListeners();
  }

  void appendAssistantText(String append) {
    if (append.isEmpty) {
      return;
    }
    _assistantText = _trimWorkspaceText('$_assistantText$append');
    notifyListeners();
  }

  void recordToolInvocation(String name, Map<String, dynamic> arguments) {
    _pendingToolName = name;
    _pendingToolArguments = Map<String, dynamic>.from(arguments);
  }

  void recordToolResult(String name, Object? result, {String? currentFlowKey}) {
    _lastToolName = name;
    _lastToolResultData = result;
    Map<String, dynamic>? invocationArguments;
    if (_pendingToolName == name && _pendingToolArguments != null) {
      invocationArguments = Map<String, dynamic>.from(_pendingToolArguments!);
      _lastToolArguments = invocationArguments;
    } else {
      _lastToolArguments = null;
    }
    _pendingToolName = null;
    _pendingToolArguments = null;
    _suggestedFlowKey = _suggestFlowKeyFromToolName(
      name,
      currentFlowKey: currentFlowKey,
      invocationArguments: invocationArguments,
    );
    if (name == 'get_script_content') {
      final content = _extractScriptContentFromToolResult(result);
      if (content != null && content.isNotEmpty) {
        _scriptWritebackCandidate = _trimWorkspaceText(content);
        _scriptWritebackSource =
            'tool:get_script_content (${content.length} chars)';
      } else {
        _scriptWritebackCandidate = null;
        _scriptWritebackSource = null;
      }
    }
    if (name == 'run_sub_agent_script') {
      final content = _extractSubAgentResultText(result);
      if (content != null && content.isNotEmpty) {
        _scriptWritebackCandidate = _trimWorkspaceText(content);
        _scriptWritebackSource =
            'tool:run_sub_agent_script (${content.length} chars)';
      } else {
        _scriptWritebackCandidate = null;
        _scriptWritebackSource = null;
      }
    }
    if (name == 'get_planData') {
      _scriptPlanWritebackCandidate = _extractScriptPlanDataFromToolResult(
        result,
      );
      _scriptPlanRowId = _extractScriptPlanRowIdFromToolResult(result);
      if (_scriptPlanWritebackCandidate == null) {
        _scriptPlanRowId = null;
      }
    }
    final encoded = jsonEncode(result);
    final summary = encoded.length > 320
        ? '${encoded.substring(0, 320)}...'
        : encoded;
    _lastToolResultLine = '$name => $summary';
    notifyListeners();
  }

  void markCancelled() {
    _writebackLine = _l10nResolved.agentWorkspaceHarnessRunCancelledHint;
    notifyListeners();
  }

  String _trimWorkspaceText(String text) {
    const maxChars = 40000;
    if (text.length <= maxChars) {
      return text;
    }
    return text.substring(text.length - maxChars);
  }

  String? _extractScriptContentFromToolResult(Object? result) {
    if (result is Map<String, dynamic>) {
      final content = result['content'];
      if (content is String) {
        return content.trim();
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractScriptPlanDataFromToolResult(Object? result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final normalizedData = _extractNormalizedScriptPlanData(result);
    if (normalizedData == null) {
      return null;
    }
    final planId = _extractScriptPlanRowIdFromToolResult(result);
    final normalized = <String, dynamic>{'data': normalizedData};
    if (planId != null) {
      normalized['planId'] = planId;
    }
    return normalized;
  }

  int? _extractScriptPlanRowIdFromToolResult(Object? result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final rawData = result['data'];
    final nestedData = rawData is Map<String, dynamic> ? rawData : null;
    return toPositiveIntValue(result['planId']) ??
        toPositiveIntValue(nestedData?['id']);
  }

  Map<String, dynamic>? _extractNormalizedScriptPlanData(
    Map<String, dynamic> result,
  ) {
    final rawData = result['data'];
    Map<String, dynamic>? candidate;
    if (rawData is Map<String, dynamic>) {
      final nested = rawData['data'];
      if (nested is Map<String, dynamic>) {
        candidate = nested;
      } else {
        candidate = rawData;
      }
    }
    if (candidate == null) {
      return null;
    }
    final storySkeleton =
        (candidate['storySkeleton'] as String?) ??
        (candidate['story_skeleton'] as String?);
    final adaptationStrategy =
        (candidate['adaptationStrategy'] as String?) ??
        (candidate['adaptation_strategy'] as String?);
    final normalized = <String, dynamic>{};
    if (storySkeleton != null) {
      normalized['storySkeleton'] = storySkeleton;
    }
    if (adaptationStrategy != null) {
      normalized['adaptationStrategy'] = adaptationStrategy;
    }
    if (candidate.containsKey('script')) {
      normalized['script'] = candidate['script'];
    }
    return normalized;
  }

  String? _extractSubAgentResultText(Object? result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final text = result['result'];
    if (text is String) {
      return text.trim();
    }
    return null;
  }

  String? _suggestFlowKeyFromToolName(
    String name, {
    String? currentFlowKey,
    Map<String, dynamic>? invocationArguments,
  }) {
    switch (name) {
      case 'get_flowData':
        final invocationKey = invocationArguments?['key'];
        if (invocationKey is String) {
          final normalized = invocationKey.trim();
          if (normalized.isNotEmpty) return normalized;
        }
        final key = currentFlowKey?.trim();
        if (key != null && key.isNotEmpty) return key;
        return 'workspaceResult';
      case 'add_deriveAsset':
      case 'del_deriveAsset':
      case 'generate_deriveAsset':
      case 'run_sub_agent_derive_assets':
      case 'run_sub_agent_generate_assets':
        return 'assets';
      case 'generate_storyboard':
      case 'run_sub_agent_storyboard_gen':
      case 'run_sub_agent_storyboard_panel':
        return 'storyboard';
      case 'run_sub_agent_storyboard_table':
        return 'storyboardTable';
      case 'run_sub_agent_director_plan':
        return 'scriptPlan';
      default:
        return 'workspaceResult';
    }
  }
}
