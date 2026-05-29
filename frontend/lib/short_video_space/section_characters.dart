// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

extension _ShortVideoSpaceSectionCharactersExtension
    on _ShortVideoSpaceSectionState {
  Future<void> _loadProjectCharacters() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    setState(() {
      _loadingCharacters = true;
    });
    try {
      final rows = await listProjectCharactersV1(token, project.id);
      if (!mounted) return;
      setState(() {
        _projectCharacters = rows;
        _loadingCharacters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCharacters = false;
        _charactersStatusLine = describeUserVisibleApiErrorResolved(context, e);
      });
    }
  }

  Future<void> _previewProjectCharacterVoice(ProjectCharacterV1 character) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final voice = character.voiceConfig;
    setState(() {
      _charactersStatusLine = l10n.shortVideoCharactersPreviewLoading(character.name);
    });
    try {
      final response = await previewTtsV1(
        token,
        text: l10n.shortVideoCharactersPreviewSampleText,
        projectId: project.id,
        characterId: character.id,
        voiceId: voice['voice'] as String? ?? voice['voiceId'] as String?,
        provider: voice['provider'] as String?,
        emotion: voice['emotion'] as String? ?? voice['style'] as String?,
        speed: (voice['speed'] as num?)?.toDouble(),
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw RustApiException.fromHttpResponse(response);
      }
      setState(() {
        _charactersStatusLine = l10n.shortVideoCharactersPreviewReady(character.name);
      });
      await _characterPreviewPlayer.stop();
      await _characterPreviewPlayer.play(BytesSource(response.bodyBytes));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _charactersStatusLine = l10n.shortVideoCharactersPreviewFailed(
          character.name,
          describeUserVisibleApiErrorResolved(context, e),
        );
      });
    }
  }

  Future<void> _saveCharacterVoiceConfig(
    ProjectCharacterV1 character,
    Map<String, dynamic> voiceConfig,
  ) async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    try {
      final updated = await patchProjectCharacterV1(
        token,
        project.id,
        character.id,
        voiceConfig: voiceConfig,
      );
      if (!mounted) return;
      setState(() {
        _projectCharacters = _projectCharacters
            .map((row) => row.id == updated.id ? updated : row)
            .toList(growable: false);
        _charactersStatusLine = l10n.shortVideoCharactersVoiceSaved(character.name);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _charactersStatusLine = l10n.shortVideoCharactersVoiceSaveFailed(
          character.name,
          describeUserVisibleApiErrorResolved(context, e),
        );
      });
    }
  }

  Widget? _buildProjectCharactersPanel() {
    final project = _selectedProject;
    if (project == null) {
      return null;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.shortVideoCharactersPanelTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                style: studioFormTextButtonIconStyle(context),
                onPressed: _loadingCharacters ? null : _loadProjectCharacters,
                icon: const Icon(Icons.refresh, size: StudioIconSize.sm),
                label: Text(l10n.shortVideoCharactersRefresh),
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
          if (_loadingCharacters)
            Text(
              l10n.shortVideoCharactersLoading,
              style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
            )
          else if (_projectCharacters.isEmpty)
            StudioEmptyState.emptyData(
              title: l10n.shortVideoCharactersEmpty,
              icon: Icons.people_outline,
            )
          else
            ..._projectCharacters.toList().asMap().entries.map((entry) {
              final character = entry.value;
              final voice = character.voiceConfig;
              final provider = (voice['provider'] as String? ?? '').trim();
              final voiceId =
                  (voice['voice'] as String? ?? voice['voiceId'] as String? ?? '')
                      .trim();
              final emotion =
                  (voice['emotion'] as String? ?? voice['style'] as String? ?? '')
                      .trim();
              return studioStaggeredItem(
                entry.key,
                entranceKey: _projectCharacters.length,
                child: Padding(
                padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                child: StudioCard(
                  padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        character.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        l10n.shortVideoCharactersVoiceSummary(
                          provider.isEmpty ? '—' : provider,
                          voiceId.isEmpty ? '—' : voiceId,
                          emotion.isEmpty ? '—' : emotion,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Wrap(
                        spacing: StudioSpacing.xs,
                        runSpacing: StudioSpacing.chromeActionGap,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                unawaited(_previewProjectCharacterVoice(character)),
                            icon: const Icon(Icons.volume_up_outlined, size: StudioIconSize.sm),
                            label: Text(l10n.shortVideoCharactersPreviewVoice),
                          ),
                          OutlinedButton(
                            onPressed: () => unawaited(
                              _editCharacterVoiceDialog(character),
                            ),
                            child: Text(l10n.shortVideoCharactersEditVoice),
                          ),
                          OutlinedButton(
                            onPressed: () => unawaited(
                              _cloneCharacterVoiceDialog(character),
                            ),
                            child: Text(l10n.shortVideoCharactersCloneVoice),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            }),
          if ((_charactersStatusLine ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              _charactersStatusLine!,
              style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Future<void> _editCharacterVoiceDialog(ProjectCharacterV1 character) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final voice = Map<String, dynamic>.from(character.voiceConfig);
    final providerCtrl = TextEditingController(
      text: (voice['provider'] as String? ?? 'openai').trim(),
    );
    final voiceIdCtrl = TextEditingController(
      text: (voice['voice'] as String? ?? voice['voiceId'] as String? ?? 'alloy')
          .trim(),
    );
    final emotionCtrl = TextEditingController(
      text: (voice['emotion'] as String? ?? voice['style'] as String? ?? '')
          .trim(),
    );
    final saved = await showStudioDialog<bool>(
      context: context,
      builder: (ctx) => StudioAlertDialog(
        title: Text(l10n.shortVideoCharactersEditVoiceTitle(character.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: providerCtrl,
              decoration: InputDecoration(
                labelText: l10n.shortVideoCharactersFieldProvider,
              ),
            ),
            TextField(
              controller: voiceIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.shortVideoCharactersFieldVoiceId,
              ),
            ),
            TextField(
              controller: emotionCtrl,
              decoration: InputDecoration(
                labelText: l10n.shortVideoCharactersFieldEmotion,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(ctx),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(MaterialLocalizations.of(ctx).saveButtonLabel),
          ),
        ],
      ),
    );
    if (saved != true) {
      return;
    }
    final next = Map<String, dynamic>.from(voice)
      ..['provider'] = providerCtrl.text.trim()
      ..['voice'] = voiceIdCtrl.text.trim()
      ..['emotion'] = emotionCtrl.text.trim();
    providerCtrl.dispose();
    voiceIdCtrl.dispose();
    emotionCtrl.dispose();
    await _saveCharacterVoiceConfig(character, next);
  }

  Future<void> _cloneCharacterVoiceDialog(ProjectCharacterV1 character) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final nameCtrl = TextEditingController(text: character.name);
    final urlCtrl = TextEditingController();
    final saved = await showStudioDialog<bool>(
      context: context,
      builder: (ctx) => StudioAlertDialog(
        title: Text(l10n.shortVideoCharactersCloneVoiceTitle(character.name)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.shortVideoCharactersCloneDisplayName,
              ),
            ),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: l10n.shortVideoCharactersCloneSampleUrl,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            OutlinedButton(
              onPressed: () {
                urlCtrl.text = 'mock-sample';
              },
              child: Text(l10n.shortVideoCharactersCloneMockSample),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(ctx),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
    if (saved != true) {
      nameCtrl.dispose();
      urlCtrl.dispose();
      return;
    }
    final displayName = nameCtrl.text.trim();
    nameCtrl.dispose();
    final urlHint = urlCtrl.text.trim();
    urlCtrl.dispose();
    if (displayName.isEmpty) {
      return;
    }
    try {
      List<int> bytes;
      if (urlHint == 'mock-sample' || urlHint.isEmpty) {
        bytes = List<int>.generate(512, (i) => i & 0xff);
      } else {
        final uri = Uri.tryParse(urlHint);
        if (uri == null || !uri.hasScheme) {
          throw StateError('invalid url');
        }
        final res = await http.get(uri).timeout(const Duration(seconds: 20));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw RustApiException.fromHttpResponse(res);
        }
        bytes = res.bodyBytes;
      }
      final cloned = await postCloneVoiceV1(
        token,
        projectId: project.id,
        displayName: displayName,
        audioBytes: bytes,
        locale: 'zh-CN',
      );
      if (!mounted) return;
      final voice = Map<String, dynamic>.from(character.voiceConfig)
        ..['cloneVoiceId'] = cloned.customVoiceId
        ..['customVoiceId'] = cloned.customVoiceId
        ..['provider'] = 'openai';
      await _saveCharacterVoiceConfig(character, voice);
      setState(() {
        _charactersStatusLine = l10n.shortVideoCharactersCloneSuccess(
          cloned.customVoiceId,
          cloned.provider,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _charactersStatusLine = l10n.shortVideoCharactersCloneFailed(
          describeUserVisibleApiErrorResolved(context, e),
        );
      });
    }
  }
}
