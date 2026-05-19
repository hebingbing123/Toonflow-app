import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../project_studio/grid_storyboard_panel.dart';
import '../rust_api.dart';
import 'grid_storyboard_dialog.dart';
import 'storyboard_frame_image.dart';

typedef StoryboardShotEditorCallback =
    Future<void> Function({
      required int scriptNumericId,
      required int storyboardNumericId,
    });

/// Full-screen storyboard studio: shot list, preview, properties, grid generate.
class StoryboardStudioPage extends StatefulWidget {
  const StoryboardStudioPage({
    super.key,
    required this.projectNumericId,
    required this.projectUuid,
    required this.accessToken,
    required this.onOpenProductionWorkspace,
    this.onOpenShotEditor,
    this.initialScriptNumericId,
    this.debugScripts,
    this.debugShots,
  });

  final int projectNumericId;
  final String projectUuid;
  final String accessToken;
  final VoidCallback onOpenProductionWorkspace;
  final StoryboardShotEditorCallback? onOpenShotEditor;
  final int? initialScriptNumericId;
  final List<ScriptWorkbenchDetailRow>? debugScripts;
  final List<ProductionStoryboardItemV1>? debugShots;

  @override
  State<StoryboardStudioPage> createState() => _StoryboardStudioPageState();
}

class _StoryboardStudioPageState extends State<StoryboardStudioPage> {
  var _loadingScripts = true;
  var _loadingShots = false;
  var _gridBusy = false;
  var _savingPrompt = false;
  Object? _loadError;
  List<ScriptWorkbenchDetailRow> _scripts = <ScriptWorkbenchDetailRow>[];
  List<ProductionStoryboardItemV1> _shots = <ProductionStoryboardItemV1>[];
  int? _scriptNumericId;
  int? _selectedShotId;
  String? _dataVersion;
  Timer? _pollTimer;
  final _promptCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final debugScripts = widget.debugScripts;
    final debugShots = widget.debugShots;
    if (debugScripts != null && debugShots != null) {
      _scripts = debugScripts;
      _shots = debugShots;
      _scriptNumericId =
          widget.initialScriptNumericId ?? debugScripts.first.numericId;
      _selectedShotId = debugShots.isNotEmpty ? debugShots.first.id : null;
      _loadingScripts = false;
      _loadingShots = false;
      _syncEditorsForShot(_findShot(_selectedShotId));
    } else {
      unawaited(_loadScripts());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _promptCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScripts() async {
    setState(() {
      _loadingScripts = true;
      _loadError = null;
    });
    try {
      final scripts = await postScriptsGetScriptApiByProjectId(
        widget.accessToken,
        widget.projectUuid,
      );
      if (!mounted) return;
      final initial =
          widget.initialScriptNumericId ??
          (scripts.isNotEmpty ? scripts.first.numericId : null);
      setState(() {
        _scripts = scripts;
        _scriptNumericId = initial;
        _loadingScripts = false;
      });
      if (initial != null) {
        await _loadShots();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingScripts = false;
      });
    }
  }

  Future<void> _loadShots({bool silent = false}) async {
    final scriptId = _scriptNumericId;
    if (scriptId == null) return;
    if (!silent) {
      setState(() {
        _loadingShots = true;
        _loadError = null;
      });
    }
    try {
      final response = await postProductionGetStoryboardDataV1(
        widget.accessToken,
        projectUuid: widget.projectUuid,
        scriptId: scriptId,
        clientDataVersion: _dataVersion,
      );
      if (!mounted) return;
      if (response.unchanged) {
        setState(() => _loadingShots = false);
        return;
      }
      final shots = List<ProductionStoryboardItemV1>.from(response.data)
        ..sort((a, b) {
          final ai = a.sbIndex ?? a.id;
          final bi = b.sbIndex ?? b.id;
          return ai.compareTo(bi);
        });
      final selectedStillExists = shots.any((s) => s.id == _selectedShotId);
      final nextSelected = selectedStillExists
          ? _selectedShotId
          : (shots.isNotEmpty ? shots.first.id : null);
      setState(() {
        _shots = shots;
        _dataVersion = response.dataVersion ?? _dataVersion;
        _selectedShotId = nextSelected;
        _loadingShots = false;
      });
      _syncEditorsForShot(_findShot(nextSelected));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadingShots = false;
      });
    }
  }

  ProductionStoryboardItemV1? _findShot(int? id) {
    if (id == null) return null;
    for (final shot in _shots) {
      if (shot.id == id) return shot;
    }
    return null;
  }

  void _syncEditorsForShot(ProductionStoryboardItemV1? shot) {
    _promptCtrl.text = shot?.prompt?.trim() ?? '';
    _durationCtrl.text = shot?.duration?.trim() ?? '';
  }

  void _selectShot(ProductionStoryboardItemV1 shot) {
    setState(() => _selectedShotId = shot.id);
    _syncEditorsForShot(shot);
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_loadShots(silent: true));
    });
  }

  Future<void> _runGridGenerate() async {
    final l10n = AppLocalizations.of(context)!;
    final scriptId = _scriptNumericId;
    if (scriptId == null || _shots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.studioStoryboardStudioNoShots)),
      );
      return;
    }

    final dims = _suggestGrid(_shots.length);
    final config = await showGridStoryboardDialog(
      context: context,
      shotCount: _shots.length,
      initialRows: dims.$1,
      initialCols: dims.$2,
    );
    if (config == null || !mounted) return;

    setState(() => _gridBusy = true);
    try {
      await postStoryboardGridGenerateAndAssignV1(
        widget.accessToken,
        projectUuid: widget.projectUuid,
        scriptId: scriptId,
        rows: config.rows,
        cols: config.cols,
        storyboardIds: _shots.map((s) => s.id).toList(),
        basePrompt: config.basePrompt,
      );
      if (!mounted) return;
      _dataVersion = null;
      _schedulePoll();
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.studioGridStoryboardEnqueued)),
      );
      await _loadShots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.studioGridStoryboardFailed(
              describeUserVisibleApiError(l10n, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _gridBusy = false);
    }
  }

  (int, int) _suggestGrid(int count) {
    if (count <= 1) return (1, 1);
    if (count == 2) return (1, 2);
    if (count <= 4) return (2, 2);
    if (count <= 6) return (2, 3);
    if (count <= 9) return (3, 3);
    return (3, 4);
  }

  Future<void> _savePrompt() async {
    final l10n = AppLocalizations.of(context)!;
    final scriptId = _scriptNumericId;
    final shot = _findShot(_selectedShotId);
    if (scriptId == null || shot == null) return;

    setState(() => _savingPrompt = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final durationRaw = _durationCtrl.text.trim();
      final duration = durationRaw.isEmpty ? null : int.tryParse(durationRaw);
      await postStoryboardEditInfoV1(
        widget.accessToken,
        projectUuid: widget.projectUuid,
        scriptId: scriptId,
        storyboardId: shot.id,
        prompt: _promptCtrl.text.trim(),
        duration: duration,
      );
      if (!mounted) return;
      _dataVersion = null;
      await _loadShots(silent: true);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.studioStoryboardStudioSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            describeUserVisibleApiError(l10n, e),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingPrompt = false);
    }
  }

  Future<void> _openShotEditor() async {
    final scriptId = _scriptNumericId;
    final shotId = _selectedShotId;
    if (scriptId == null || shotId == null) return;
    final open = widget.onOpenShotEditor;
    if (open == null) {
      widget.onOpenProductionWorkspace();
      return;
    }
    await open(scriptNumericId: scriptId, storyboardNumericId: shotId);
    if (mounted) {
      _dataVersion = null;
      await _loadShots(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final selected = _findShot(_selectedShotId);

    return Scaffold(
      backgroundColor: tokens.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/projects/${widget.projectNumericId}/script');
            }
          },
        ),
        title: Text(
          l10n.studioStoryboardStudioTitle,
          style: studioProjectTitleStyle(context),
        ),
        actions: <Widget>[
          if (_scripts.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButton<int>(
                value: _scriptNumericId,
                items: _scripts
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: s.numericId,
                        child: Text(
                          s.name?.trim().isNotEmpty == true
                              ? s.name!.trim()
                              : l10n.studioEpisodeConsoleTitle(s.numericId),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loadingShots
                    ? null
                    : (value) async {
                        setState(() {
                          _scriptNumericId = value;
                          _selectedShotId = null;
                          _shots = <ProductionStoryboardItemV1>[];
                          _dataVersion = null;
                        });
                        await _loadShots();
                      },
              ),
            ),
          TextButton(
            onPressed: widget.onOpenProductionWorkspace,
            child: Text(l10n.studioStepOpenProduction),
          ),
        ],
      ),
      body: _loadingScripts
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null && _shots.isEmpty
          ? Center(
              child: StudioApiErrorCallout(
                error: _loadError!,
                onRetry: _loadScripts,
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 240,
                  child: ColoredBox(
                    color: tokens.bgInset,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Text(
                            l10n.studioStoryboardShotList,
                            style: studioPaneTitleStyle(context),
                          ),
                        ),
                        if (_loadingShots)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_shots.isEmpty)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  l10n.studioStoryboardStudioNoShots,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _shots.length,
                              itemBuilder: (context, index) {
                                final shot = _shots[index];
                                final labelIndex = shot.sbIndex ?? (index + 1);
                                final selectedTile = shot.id == _selectedShotId;
                                final hasFrame =
                                    (shot.url?.trim().isNotEmpty ?? false);
                                return ListTile(
                                  dense: true,
                                  selected: selectedTile,
                                  leading: Icon(
                                    hasFrame
                                        ? Icons.image_outlined
                                        : Icons.image_not_supported_outlined,
                                    size: 18,
                                    color: hasFrame
                                        ? tokens.accent
                                        : tokens.textMuted,
                                  ),
                                  title: Text(
                                    l10n.studioStoryboardShotLabel(labelIndex),
                                  ),
                                  subtitle: Text(
                                    shot.state?.trim().isNotEmpty == true
                                        ? shot.state!.trim()
                                        : l10n.scriptEditorStoryboardsStateFallback,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectShot(shot),
                                  onLongPress: _openShotEditor,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: selected == null
                            ? Center(
                                child: Text(
                                  l10n.studioStoryboardStudioSelectShot,
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    StoryboardFrameImage(
                                      accessToken: widget.accessToken,
                                      projectUuid: widget.projectUuid,
                                      scriptNumericId: _scriptNumericId!,
                                      storyboardNumericId: selected.id,
                                      imageUrl: selected.url,
                                      height: 360,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      selected.prompt?.trim().isNotEmpty == true
                                          ? selected.prompt!.trim()
                                          : l10n.studioStoryboardStudioEmptyPrompt,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: <Widget>[
                                        StudioPrimaryButton(
                                          label: l10n.studioStepOpenProduction,
                                          onPressed: widget.onOpenProductionWorkspace,
                                        ),
                                        if (widget.onOpenShotEditor != null)
                                          OutlinedButton(
                                            onPressed: _openShotEditor,
                                            child: Text(
                                              l10n.studioStoryboardStudioOpenEditor,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridStoryboardPanel(
                          busy: _gridBusy,
                          onGenerateGrid: _runGridGenerate,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: ColoredBox(
                    color: tokens.bgSurface,
                    child: selected == null
                        ? ListView(
                            padding: const EdgeInsets.all(16),
                            children: <Widget>[
                              Text(
                                l10n.studioStoryboardProperties,
                                style: studioPaneTitleStyle(context),
                              ),
                              const SizedBox(height: 12),
                              Text(l10n.studioStoryboardPropertiesHint),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: <Widget>[
                              Text(
                                l10n.studioStoryboardProperties,
                                style: studioPaneTitleStyle(context),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _promptCtrl,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: l10n.storyboardEditorPromptLabelClearEmpty,
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _durationCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.shortVideoBatchDurationLabel,
                                ),
                              ),
                              const SizedBox(height: 16),
                              StudioPrimaryButton(
                                label: l10n.studioStoryboardStudioSaveProperties,
                                onPressed: _savingPrompt ? null : _savePrompt,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
