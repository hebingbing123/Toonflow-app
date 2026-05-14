// ignore_for_file: invalid_use_of_protected_member, unused_element

part of 'section.dart';

const int _kMaxAssemblyVersions = 20;

/// Draft + assembly version snapshot management (`flow_data.assembly_versions`).
extension _ShortVideoSpaceSectionDraftManagementExtension
    on _ShortVideoSpaceSectionState {
  /// Load drafts and versions from flow_data
  Future<void> _loadDraftsAndVersions() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        if (mounted) {
          setState(() {
            _assemblyDrafts = const <AssemblyDraft>[];
            _assemblyVersions = const <AssemblyVersion>[];
            _currentAssemblyVersionId = 'default';
          });
        }
        return;
      }

      final firstScriptId = assembly.scripts.first.scriptNumericId;

      final flowData = await fallbackOnRustApiException(
        () => fetchProductionFlowDataV1(
          token,
          projectUuid: project.id,
          episodesId: firstScriptId,
        ),
        <String, dynamic>{},
      );

      final versionsData =
          flowData['assembly_versions'] as Map<String, dynamic>?;
      var nextDrafts = const <AssemblyDraft>[];
      var nextVersions = const <AssemblyVersion>[];
      var nextCurrent = 'default';

      if (versionsData != null) {
        final draftsList = versionsData['drafts'] as List<dynamic>? ?? [];
        nextDrafts = draftsList
            .map((d) => AssemblyDraft.fromJson(d as Map<String, dynamic>))
            .toList();

        final rawVers = versionsData['versions'] as List<dynamic>? ?? [];
        nextVersions = rawVers
            .map((v) => AssemblyVersion.fromJson(v as Map<String, dynamic>))
            .toList();

        final curRaw = versionsData['current_version_id'] as String?;
        if (curRaw != null && curRaw.trim().isNotEmpty) {
          nextCurrent = curRaw.trim();
        } else if (nextVersions.isNotEmpty) {
          nextCurrent = nextVersions.first.id;
        }
      }

      if (mounted) {
        setState(() {
          _assemblyDrafts = nextDrafts;
          _assemblyVersions = nextVersions;
          _currentAssemblyVersionId = nextCurrent;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftLoadFailed(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _persistAssemblyBlockToFlow() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final assembly = _shortVideoAssembly;
    if (token == null ||
        token.isEmpty ||
        project == null ||
        assembly == null ||
        assembly.scripts.isEmpty) {
      return;
    }
    final firstScriptId = assembly.scripts.first.scriptNumericId;
    final flowData = await fallbackOnRustApiException(
      () => fetchProductionFlowDataV1(
        token,
        projectUuid: project.id,
        episodesId: firstScriptId,
      ),
      <String, dynamic>{},
    );
    final versionsData =
        flowData['assembly_versions'] as Map<String, dynamic>? ?? {};
    versionsData['drafts'] = _assemblyDrafts
        .map((d) => d.toJson())
        .toList(growable: false);
    versionsData['versions'] = _assemblyVersions
        .map((v) => v.toJson())
        .toList(growable: false);
    versionsData['current_version_id'] = _currentAssemblyVersionId;
    flowData['assembly_versions'] = versionsData;
    final code = await postProductionSaveFlowDataV1(
      token,
      projectUuid: project.id,
      episodesId: firstScriptId,
      data: flowData,
    );
    if (code != 200) {
      throw RustApiException('save flow failed', statusCode: code);
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

  Future<void> _applyAssemblyShotConfig(Map<String, dynamic> shotConfig) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final assembly = _shortVideoAssembly;
    if (assembly == null || assembly.scripts.isEmpty) {
      throw Exception(
        resolveAppLocalizationsForErrors(context).shortVideoAssemblyDraftNoShotsToApply,
      );
    }

    for (final script in assembly.scripts) {
      for (final shot in script.shots) {
        final shotId = shot.storyboardNumericId.toString();
        final config = shotConfig[shotId] as Map<String, dynamic>?;

        if (config != null) {
          final enabled = config['enabled'] as bool? ?? false;
          final videoUrl = config['video_url'] as String? ?? '';

          if (enabled && videoUrl.isNotEmpty) {
            await postWorkbenchSelectVideoV1(
              token,
              projectUuid: project.id,
              scriptId: script.scriptNumericId,
              storyboardId: shot.storyboardNumericId,
              videoUrl: videoUrl,
            );
          } else {
            await postWorkbenchDeleteVideoV1(
              token,
              projectUuid: project.id,
              scriptId: script.scriptNumericId,
              storyboardId: shot.storyboardNumericId,
            );
          }

          final duration = config['duration'] as String? ?? '';
          if (duration.isNotEmpty) {
            final durationSeconds = int.tryParse(
              duration.replaceAll(RegExp(r'[^0-9]'), ''),
            );
            if (durationSeconds != null && durationSeconds > 0) {
              await postStoryboardUpdateDurationV1(
                token,
                projectUuid: project.id,
                scriptId: script.scriptNumericId,
                storyboardId: shot.storyboardNumericId,
                duration: durationSeconds,
              );
            }
          }
        }
      }
    }
    await _loadProjectOverview();
  }

  /// Save current editing state as a draft
  Future<void> _handleSaveDraft(String name) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      final l10n = resolveAppLocalizationsForErrors(context);
      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        throw Exception(l10n.shortVideoAssemblyDraftNoShotsToSave);
      }

      if (_assemblyDrafts.length >= 10) {
        throw Exception(l10n.shortVideoAssemblyDraftLimitReached(10));
      }

      final firstScriptId = assembly.scripts.first.scriptNumericId;
      final flowData = await fallbackOnRustApiException(
        () => fetchProductionFlowDataV1(
          token,
          projectUuid: project.id,
          episodesId: firstScriptId,
        ),
        <String, dynamic>{},
      );

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

      final versionsData =
          flowData['assembly_versions'] as Map<String, dynamic>? ?? {};
      final draftsList = versionsData['drafts'] as List<dynamic>? ?? [];
      draftsList.insert(0, newDraft.toJson());
      if (draftsList.length > 10) {
        draftsList.removeRange(10, draftsList.length);
      }
      versionsData['drafts'] = draftsList;
      versionsData['versions'] = _assemblyVersions
          .map((v) => v.toJson())
          .toList(growable: false);
      versionsData['current_version_id'] = _currentAssemblyVersionId;
      flowData['assembly_versions'] = versionsData;

      final code = await postProductionSaveFlowDataV1(
        token,
        projectUuid: project.id,
        episodesId: firstScriptId,
        data: flowData,
      );

      if (code != 200) {
        throw RustApiException('save flow failed', statusCode: code);
      }

      await _loadDraftsAndVersions();

      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftSaved(name),
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftSaveFailed(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      }
      rethrow;
    }
  }

  /// Restore a draft to current editing state
  Future<void> _handleRestoreDraft(String draftId) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      final l10n = resolveAppLocalizationsForErrors(context);
      final draft = _assemblyDrafts.firstWhere(
        (d) => d.id == draftId,
        orElse: () => throw Exception(l10n.shortVideoAssemblyDraftNotFound),
      );

      await _applyAssemblyShotConfig(draft.shotConfig);

      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftRestored(draft.name),
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftRestoreFailed(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      }
      rethrow;
    }
  }

  /// Delete a draft
  Future<void> _handleDeleteDraft(String draftId) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }

    try {
      final l10n = resolveAppLocalizationsForErrors(context);
      final assembly = _shortVideoAssembly;
      if (assembly == null || assembly.scripts.isEmpty) {
        throw Exception(l10n.shortVideoAssemblyDraftNoDataToDelete);
      }

      final firstScriptId = assembly.scripts.first.scriptNumericId;
      final flowData = await fallbackOnRustApiException(
        () => fetchProductionFlowDataV1(
          token,
          projectUuid: project.id,
          episodesId: firstScriptId,
        ),
        <String, dynamic>{},
      );

      final versionsData =
          flowData['assembly_versions'] as Map<String, dynamic>? ?? {};
      final draftsList = versionsData['drafts'] as List<dynamic>? ?? [];
      draftsList.removeWhere((d) {
        final draft = d as Map<String, dynamic>;
        return draft['id'] == draftId;
      });
      versionsData['drafts'] = draftsList;
      versionsData['versions'] = _assemblyVersions
          .map((v) => v.toJson())
          .toList(growable: false);
      versionsData['current_version_id'] = _currentAssemblyVersionId;
      flowData['assembly_versions'] = versionsData;

      final code = await postProductionSaveFlowDataV1(
        token,
        projectUuid: project.id,
        episodesId: firstScriptId,
        data: flowData,
      );

      if (code != 200) {
        throw RustApiException('save flow failed', statusCode: code);
      }

      await _loadDraftsAndVersions();

      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftDeleted,
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10n.shortVideoAssemblyDraftDeleteFailed(
            describeUserVisibleApiError(l10n, e),
          ),
          isSuccess: false,
        );
      }
      rethrow;
    }
  }

  Future<void> _handleCreateVersion(String name) async {
    final trimmed = name.trim();
    final l10n = resolveAppLocalizationsForErrors(context);
    if (trimmed.isEmpty) {
      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyVersionNameEmpty,
          isSuccess: false,
        );
      }
      return;
    }
    final assembly = _shortVideoAssembly;
    if (assembly == null || assembly.scripts.isEmpty) {
      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyVersionNoAssembly,
          isSuccess: false,
        );
      }
      return;
    }
    if (_assemblyVersions.length >= _kMaxAssemblyVersions) {
      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyVersionLimitReached(_kMaxAssemblyVersions),
          isSuccess: false,
        );
      }
      return;
    }

    try {
      final shotConfig = _buildCurrentShotConfig();
      final version = AssemblyVersion(
        id: 'ver_${DateTime.now().millisecondsSinceEpoch}',
        name: trimmed,
        createdAt: DateTime.now(),
        shotCount: assembly.scripts.fold<int>(
          0,
          (sum, script) => sum + script.shots.length,
        ),
        shotConfig: shotConfig,
      );
      if (mounted) {
        setState(() {
          _assemblyVersions = <AssemblyVersion>[version, ..._assemblyVersions];
          _currentAssemblyVersionId = version.id;
        });
      }
      await _persistAssemblyBlockToFlow();
      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyVersionCreated(trimmed),
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10nErr.shortVideoAssemblyVersionCreateFailed(
            describeUserVisibleApiError(l10nErr, e),
          ),
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _handleSwitchVersion(String versionId) async {
    final id = versionId.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      final l10n = resolveAppLocalizationsForErrors(context);
      AssemblyVersion? version;
      for (final v in _assemblyVersions) {
        if (v.id == id) {
          version = v;
          break;
        }
      }
      if (version == null) {
        throw Exception(l10n.shortVideoAssemblyVersionNotFound);
      }
      await _applyAssemblyShotConfig(version.shotConfig);
      if (mounted) {
        setState(() {
          _currentAssemblyVersionId = id;
        });
      }
      await _persistAssemblyBlockToFlow();
      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyVersionSwitched(version.name),
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10nErr.shortVideoAssemblyVersionSwitchFailed(
            describeUserVisibleApiError(l10nErr, e),
          ),
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _handleDeleteVersion(String versionId) async {
    final id = versionId.trim();
    if (id.isEmpty) {
      return;
    }
    if (_assemblyVersions.length <= 1) {
      if (mounted) {
        _showOperationFeedback(
          resolveAppLocalizationsForErrors(context).shortVideoAssemblyVersionKeepAtLeastOne,
          isSuccess: false,
        );
      }
      return;
    }

    try {
      final l10n = resolveAppLocalizationsForErrors(context);
      final removedWasCurrent = _currentAssemblyVersionId == id;
      final remaining = _assemblyVersions.where((v) => v.id != id).toList();
      if (remaining.length == _assemblyVersions.length) {
        throw Exception(l10n.shortVideoAssemblyVersionNotFound);
      }
      var newCurrent = _currentAssemblyVersionId;
      if (removedWasCurrent) {
        newCurrent = remaining.first.id;
      }
      if (mounted) {
        setState(() {
          _assemblyVersions = remaining;
          _currentAssemblyVersionId = newCurrent;
        });
      }
      await _persistAssemblyBlockToFlow();

      if (removedWasCurrent) {
        final snap = remaining.firstWhere(
          (v) => v.id == newCurrent,
          orElse: () => remaining.first,
        );
        await _applyAssemblyShotConfig(snap.shotConfig);
      }

      if (mounted) {
        _showOperationFeedback(
          l10n.shortVideoAssemblyVersionDeleted,
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10nErr = resolveAppLocalizationsForErrors(context);
        _showOperationFeedback(
          l10nErr.shortVideoAssemblyVersionDeleteFailed(
            describeUserVisibleApiError(l10nErr, e),
          ),
          isSuccess: false,
        );
      }
    }
  }
}
