// ignore_for_file: invalid_use_of_protected_member, unused_element

part of 'section.dart';

/// Draft management operations for ShortVideoSpaceSection
/// 
/// Implements:
/// - Save draft to flow_data
/// - Load drafts from flow_data
/// - Restore draft functionality
/// - Draft quantity limit (max 10)
/// 
/// Requirements: 7
extension _ShortVideoSpaceSectionDraftManagementExtension on _ShortVideoSpaceSectionState {
  /// Load drafts and versions from flow_data
  Future<void> _loadDraftsAndVersions() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      // Load flow_data for the first script (or project-level if available)
      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        return;
      }

      final firstScriptId = assembly.scripts.first.scriptNumericId;
      
      Map<String, dynamic> flowData;
      try {
        flowData = await fetchProductionFlowDataV1(
          token,
          projectId: project.numericId,
          episodesId: firstScriptId,
        );
      } on RustApiException {
        flowData = <String, dynamic>{};
      }

      // Extract drafts from flow_data. Version switching is still owned by the
      // standalone version manager widget and is not wired into the section yet.
      final versionsData = flowData['assembly_versions'] as Map<String, dynamic>?;
      if (versionsData != null) {
        final draftsList = versionsData['drafts'] as List<dynamic>? ?? [];
        _assemblyDrafts = draftsList
            .map((d) => AssemblyDraft.fromJson(d as Map<String, dynamic>))
            .toList();
      } else {
        _assemblyDrafts = [];
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _showOperationFeedback(
          '加载草稿和版本失败：$e',
          isSuccess: false,
        );
      }
    }
  }

  /// Build current shot configuration from assembly
  Map<String, dynamic> _buildCurrentShotConfig() {
    final assembly = _shortVideoAssembly;
    if (assembly == null) {
      return {};
    }

    final config = <String, dynamic>{};
    for (final script in assembly.scripts) {
      for (final shot in script.shots) {
        config[shot.storyboardNumericId.toString()] = {
          'enabled': shot.selectedMediaUrl?.isNotEmpty ?? false,
          'video_url': shot.selectedMediaUrl ?? '',
          'duration': shot.duration ?? '',
          'subtitle': shot.subtitleText ?? '',
          'voiceover_audio_url': shot.voiceoverAudioUrl ?? '',
        };
      }
    }
    return config;
  }

  /// Save current editing state as a draft
  /// 
  /// Requirements: 7.2
  Future<void> _handleSaveDraft(String name) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        throw Exception('没有可保存的镜头数据');
      }

      // Check draft limit
      if (_assemblyDrafts.length >= 10) {
        throw Exception('草稿数量已达上限（最多 10 个）');
      }

      final firstScriptId = assembly.scripts.first.scriptNumericId;
      
      // Load existing flow_data
      Map<String, dynamic> flowData;
      try {
        flowData = await fetchProductionFlowDataV1(
          token,
          projectId: project.numericId,
          episodesId: firstScriptId,
        );
      } on RustApiException {
        flowData = <String, dynamic>{};
      }

      // Create new draft
      final newDraft = AssemblyDraft(
        id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        savedAt: DateTime.now(),
        shotCount: assembly.scripts.fold<int>(
          0,
          (sum, script) => sum + script.shots.length,
        ),
        shotConfig: _buildCurrentShotConfig(),
      );

      // Update flow_data with new draft
      final versionsData = flowData['assembly_versions'] as Map<String, dynamic>? ?? {};
      final draftsList = versionsData['drafts'] as List<dynamic>? ?? [];
      
      // Add new draft at the beginning (most recent first)
      draftsList.insert(0, newDraft.toJson());
      
      // Keep only the most recent 10 drafts
      if (draftsList.length > 10) {
        draftsList.removeRange(10, draftsList.length);
      }
      
      versionsData['drafts'] = draftsList;
      flowData['assembly_versions'] = versionsData;

      // Save flow_data
      final code = await postProductionSaveFlowDataV1(
        token,
        projectId: project.numericId,
        episodesId: firstScriptId,
        data: flowData,
      );

      if (code != 200) {
        throw RustApiException('save flow failed', statusCode: code);
      }

      // Reload drafts
      await _loadDraftsAndVersions();

      if (mounted) {
        _showOperationFeedback(
          '草稿 "$name" 保存成功',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showOperationFeedback(
          '保存草稿失败：$e',
          isSuccess: false,
        );
      }
      rethrow;
    }
  }

  /// Restore a draft to current editing state
  /// 
  /// Requirements: 7.5
  Future<void> _handleRestoreDraft(String draftId) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      // Find the draft
      final draft = _assemblyDrafts.firstWhere(
        (d) => d.id == draftId,
        orElse: () => throw Exception('草稿不存在'),
      );

      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        throw Exception('没有可恢复的镜头数据');
      }

      // Apply draft configuration to shots
      final shotConfig = draft.shotConfig;
      for (final script in assembly.scripts) {
        for (final shot in script.shots) {
          final shotId = shot.storyboardNumericId.toString();
          final config = shotConfig[shotId] as Map<String, dynamic>?;
          
          if (config != null) {
            final enabled = config['enabled'] as bool? ?? false;
            final videoUrl = config['video_url'] as String? ?? '';
            
            if (enabled && videoUrl.isNotEmpty) {
              // Enable shot with video URL
              await postWorkbenchSelectVideoV1(
                token,
                projectId: project.numericId,
                scriptId: script.scriptNumericId,
                storyboardId: shot.storyboardNumericId,
                videoUrl: videoUrl,
              );
            } else {
              // Disable shot
              await postWorkbenchDeleteVideoV1(
                token,
                projectId: project.numericId,
                scriptId: script.scriptNumericId,
                storyboardId: shot.storyboardNumericId,
              );
            }
            
            // Update duration if specified
            final duration = config['duration'] as String? ?? '';
            if (duration.isNotEmpty) {
              final durationSeconds = int.tryParse(
                duration.replaceAll(RegExp(r'[^0-9]'), ''),
              );
              if (durationSeconds != null && durationSeconds > 0) {
                await postStoryboardUpdateDurationV1(
                  token,
                  projectId: project.numericId,
                  scriptId: script.scriptNumericId,
                  storyboardId: shot.storyboardNumericId,
                  duration: durationSeconds,
                );
              }
            }
          }
        }
      }

      // Reload project overview
      await _loadProjectOverview();

      if (mounted) {
        _showOperationFeedback(
          '草稿 "${draft.name}" 已恢复',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showOperationFeedback(
          '恢复草稿失败：$e',
          isSuccess: false,
        );
      }
      rethrow;
    }
  }

  /// Delete a draft
  /// 
  /// Requirements: 7
  Future<void> _handleDeleteDraft(String draftId) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        throw Exception('没有可删除的草稿数据');
      }

      final firstScriptId = assembly.scripts.first.scriptNumericId;
      
      // Load existing flow_data
      Map<String, dynamic> flowData;
      try {
        flowData = await fetchProductionFlowDataV1(
          token,
          projectId: project.numericId,
          episodesId: firstScriptId,
        );
      } on RustApiException {
        flowData = <String, dynamic>{};
      }

      // Remove draft from flow_data
      final versionsData = flowData['assembly_versions'] as Map<String, dynamic>? ?? {};
      final draftsList = versionsData['drafts'] as List<dynamic>? ?? [];
      
      draftsList.removeWhere((d) {
        final draft = d as Map<String, dynamic>;
        return draft['id'] == draftId;
      });
      
      versionsData['drafts'] = draftsList;
      flowData['assembly_versions'] = versionsData;

      // Save flow_data
      final code = await postProductionSaveFlowDataV1(
        token,
        projectId: project.numericId,
        episodesId: firstScriptId,
        data: flowData,
      );

      if (code != 200) {
        throw RustApiException('save flow failed', statusCode: code);
      }

      // Reload drafts
      await _loadDraftsAndVersions();

      if (mounted) {
        _showOperationFeedback(
          '草稿已删除',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showOperationFeedback(
          '删除草稿失败：$e',
          isSuccess: false,
        );
      }
      rethrow;
    }
  }

  /// Create a new version (placeholder for future implementation)
  Future<void> _handleCreateVersion(String name) async {
    // TODO: Implement version creation in future tasks
    if (mounted) {
      _showOperationFeedback(
        '版本管理功能将在后续任务中实现',
        isSuccess: false,
      );
    }
  }

  /// Switch to a different version (placeholder for future implementation)
  Future<void> _handleSwitchVersion(String versionId) async {
    // TODO: Implement version switching in future tasks
    if (mounted) {
      _showOperationFeedback(
        '版本管理功能将在后续任务中实现',
        isSuccess: false,
      );
    }
  }

  /// Delete a version (placeholder for future implementation)
  Future<void> _handleDeleteVersion(String versionId) async {
    // TODO: Implement version deletion in future tasks
    if (mounted) {
      _showOperationFeedback(
        '版本管理功能将在后续任务中实现',
        isSuccess: false,
      );
    }
  }
}
