import 'dart:convert';

import 'package:flutter/material.dart';

class WorkspaceOutputController extends ChangeNotifier {
  String _assistantText = '';
  String? _lastToolResultLine;
  String? _lastToolName;
  Object? _lastToolResultData;
  String? _suggestedFlowKey;
  String? _scriptWritebackCandidate;
  Map<String, dynamic>? _scriptPlanWritebackCandidate;
  int? _scriptPlanRowId;
  String? _scriptWritebackSource;
  String? _writebackLine;

  String get assistantText => _assistantText;
  String? get lastToolResultLine => _lastToolResultLine;
  String? get lastToolName => _lastToolName;
  Object? get lastToolResultData => _lastToolResultData;
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
    _suggestedFlowKey = null;
    _scriptWritebackCandidate = null;
    _scriptPlanWritebackCandidate = null;
    _scriptPlanRowId = null;
    _scriptWritebackSource = null;
    _writebackLine = null;
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

  void recordToolResult(String name, Object? result, {String? currentFlowKey}) {
    _lastToolName = name;
    _lastToolResultData = result;
    _suggestedFlowKey = _suggestFlowKeyFromToolName(
      name,
      currentFlowKey: currentFlowKey,
    );
    if (name == 'get_script_content') {
      final content = _extractScriptContentFromToolResult(result);
      if (content != null && content.isNotEmpty) {
        _scriptWritebackCandidate = _trimWorkspaceText(content);
        _scriptWritebackSource =
            'tool:get_script_content (${content.length} chars)';
      }
    }
    if (name == 'run_sub_agent_script') {
      final content = _extractSubAgentResultText(result);
      if (content != null && content.isNotEmpty) {
        _scriptWritebackCandidate = _trimWorkspaceText(content);
        _scriptWritebackSource =
            'tool:run_sub_agent_script (${content.length} chars)';
      }
    }
    if (name == 'get_planData') {
      _scriptPlanWritebackCandidate = _extractScriptPlanDataFromToolResult(
        result,
      );
      _scriptPlanRowId = _extractScriptPlanRowIdFromToolResult(result);
    }
    final encoded = jsonEncode(result);
    final summary = encoded.length > 320
        ? '${encoded.substring(0, 320)}...'
        : encoded;
    _lastToolResultLine = '$name => $summary';
    notifyListeners();
  }

  void markCancelled() {
    _writebackLine = '当前运行已取消，可检查日志后决定是否写回。';
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
    if (result is Map<String, dynamic>) {
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        return result;
      }
    }
    return null;
  }

  int? _extractScriptPlanRowIdFromToolResult(Object? result) {
    if (result is! Map<String, dynamic>) {
      return null;
    }
    final raw = result['planId'];
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return null;
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

  String? _suggestFlowKeyFromToolName(String name, {String? currentFlowKey}) {
    switch (name) {
      case 'get_flowData':
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
