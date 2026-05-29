import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_icon_button.dart';
import '../design_system/ix/studio_form_keyboard.dart';
import '../design_system/ix/studio_scroll_behavior.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'art_step_checklist_actions.dart';
import 'art_step_readiness_card.dart';
import 'studio_snapshot_bus.dart';

List<String> _splitLines(String raw) => raw
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

/// Art-step scoped sheet: readiness + pitch + brand visual constraints only.
Future<void> showArtStepBriefContextSheet({
  required BuildContext context,
  required String accessToken,
  required ProjectRow project,
  required ProjectHome? home,
  required VoidCallback onOpenFullProjectSettings,
  VoidCallback? onNavigateToScriptStep,
  VoidCallback? onFocusStylePacks,
  String? initialChecklistFocusKey,
}) async {
  await showStudioBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => _ArtStepBriefContextSheet(
      accessToken: accessToken,
      project: project,
      home: home,
      onOpenFullProjectSettings: onOpenFullProjectSettings,
      onNavigateToScriptStep: onNavigateToScriptStep,
      onFocusStylePacks: onFocusStylePacks,
      initialChecklistFocusKey: initialChecklistFocusKey,
    ),
  );
}

class _ArtStepBriefContextSheet extends StatefulWidget {
  const _ArtStepBriefContextSheet({
    required this.accessToken,
    required this.project,
    required this.home,
    required this.onOpenFullProjectSettings,
    this.onNavigateToScriptStep,
    this.onFocusStylePacks,
    this.initialChecklistFocusKey,
  });

  final String accessToken;
  final ProjectRow project;
  final ProjectHome? home;
  final VoidCallback onOpenFullProjectSettings;
  final VoidCallback? onNavigateToScriptStep;
  final VoidCallback? onFocusStylePacks;
  final String? initialChecklistFocusKey;

  @override
  State<_ArtStepBriefContextSheet> createState() =>
      _ArtStepBriefContextSheetState();
}

class _ArtStepBriefContextSheetState extends State<_ArtStepBriefContextSheet> {
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _pitchSectionKey = GlobalKey();
  final GlobalKey _brandSectionKey = GlobalKey();

  late final TextEditingController _premiseCtrl;
  late final TextEditingController _audienceCtrl;
  late final TextEditingController _toneCtrl;
  late final TextEditingController _hookCtrl;
  late final TextEditingController _visualCtrl;
  late final TextEditingController _brandNameCtrl;
  late final TextEditingController _brandPromiseCtrl;
  late final TextEditingController _visualMotifsCtrl;
  late final TextEditingController _forbiddenCtrl;

  late final FocusNode _premiseFocus;
  late final FocusNode _brandPromiseFocus;

  var _saving = false;

  @override
  void initState() {
    super.initState();
    final home = widget.home;
    _premiseCtrl = TextEditingController(text: home?.projectBrief?.premise ?? '');
    _audienceCtrl = TextEditingController(
      text: home?.projectBrief?.targetAudience ?? '',
    );
    _toneCtrl = TextEditingController(
      text: home?.projectBrief?.emotionalTone ?? '',
    );
    _hookCtrl = TextEditingController(text: home?.projectBrief?.coreHook ?? '');
    _visualCtrl = TextEditingController(
      text: home?.projectBrief?.visualDirection ?? '',
    );
    _brandNameCtrl = TextEditingController(text: home?.brandBible?.brandName ?? '');
    _brandPromiseCtrl = TextEditingController(
      text: home?.brandBible?.brandPromise ?? '',
    );
    _visualMotifsCtrl = TextEditingController(
      text: (home?.brandBible?.visualMotifs ?? const <String>[]).join('\n'),
    );
    _forbiddenCtrl = TextEditingController(
      text: (home?.brandBible?.forbiddenElements ?? const <String>[]).join('\n'),
    );
    _premiseFocus = FocusNode();
    _brandPromiseFocus = FocusNode();
    final initialKey = widget.initialChecklistFocusKey;
    if (initialKey != null &&
        (initialKey == ArtStepChecklistKey.brief ||
            initialKey == ArtStepChecklistKey.brandBible)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_onChecklistItemTap(initialKey));
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _premiseCtrl.dispose();
    _audienceCtrl.dispose();
    _toneCtrl.dispose();
    _hookCtrl.dispose();
    _visualCtrl.dispose();
    _brandNameCtrl.dispose();
    _brandPromiseCtrl.dispose();
    _visualMotifsCtrl.dispose();
    _forbiddenCtrl.dispose();
    _premiseFocus.dispose();
    _brandPromiseFocus.dispose();
    super.dispose();
  }

  void _closeSheet() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _scrollToSection(GlobalKey sectionKey, {FocusNode? focus}) async {
    final target = sectionKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    focus?.requestFocus();
  }

  Future<void> _onChecklistItemTap(String key) async {
    switch (key) {
      case ArtStepChecklistKey.brief:
        await _scrollToSection(_pitchSectionKey, focus: _premiseFocus);
        return;
      case ArtStepChecklistKey.brandBible:
        await _scrollToSection(_brandSectionKey, focus: _brandPromiseFocus);
        return;
      case ArtStepChecklistKey.source:
        _closeSheet();
        widget.onNavigateToScriptStep?.call();
        return;
      case ArtStepChecklistKey.styleBible:
        _closeSheet();
        widget.onFocusStylePacks?.call();
        return;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await updateProjectByProjectId(
        widget.accessToken,
        widget.project.id,
        <String, dynamic>{
          'projectBrief': ProjectBriefDraft(
            premise: _premiseCtrl.text,
            targetAudience: _audienceCtrl.text,
            emotionalTone: _toneCtrl.text,
            coreHook: _hookCtrl.text,
            visualDirection: _visualCtrl.text,
          ).toJsonOrNull(),
          'brandBible': BrandBibleDraft(
            brandName: _brandNameCtrl.text,
            brandPromise: _brandPromiseCtrl.text,
            visualMotifs: _splitLines(_visualMotifsCtrl.text),
            forbiddenElements: _splitLines(_forbiddenCtrl.text),
          ).toJsonOrNull(),
        },
      );
      kStudioSnapshotBus.invalidate(StudioSnapshotInvalidation.projectOnboarding);
      if (!mounted) return;
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      if (!rootContext.mounted) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text(l10n.studioArtStepBriefSheetSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeUserVisibleApiErrorResolved(context, e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final home = widget.home;
    final viewport = MediaQuery.sizeOf(context);
    final sheetHeight = viewport.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(StudioSpacing.md, StudioSpacing.radiusComfort, StudioSpacing.radiusComfort, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.studioArtStepBriefSheetTitle,
                      style: studioDialogTitleStyle(context),
                    ),
                  ),
                  StudioIconButton(
                    icon: Icons.close,
                    label: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: _saving ? null : _closeSheet,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
              child: Text(
                l10n.studioArtStepBriefSheetSubtitle,
                style: studioSectionIntroStyle(context),
              ),
            ),
            const SizedBox(height: StudioSpacing.sm),
            Expanded(
              child: StudioScrollbar(
                controller: _scrollCtrl,
                child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(StudioSpacing.md, 0, StudioSpacing.md, StudioSpacing.sm),
                child: StudioFormKeyboardScope(
                  onEnterSubmit: _saving ? null : _save,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (home != null) ...<Widget>[
                      ArtStepReadinessCard(
                        home: home,
                        l10n: l10n,
                        onChecklistItemTap: _onChecklistItemTap,
                      ),
                      const SizedBox(height: StudioSpacing.sm),
                    ],
                    KeyedSubtree(
                      key: _pitchSectionKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            l10n.projectEditorBasicsPitchSectionTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _premiseCtrl,
                            focusNode: _premiseFocus,
                            enabled: !_saving,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l10n.projectEditorBasicsFieldPremise,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _audienceCtrl,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.projectEditorBasicsFieldTargetAudience,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _toneCtrl,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.projectEditorBasicsFieldEmotionalTone,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _hookCtrl,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText: l10n.projectEditorBasicsFieldCoreHook,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _visualCtrl,
                            enabled: !_saving,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.projectEditorBasicsFieldVisualDirection,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.sm),
                    KeyedSubtree(
                      key: _brandSectionKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            l10n.projectEditorBasicsBrandSectionTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _brandNameCtrl,
                            enabled: !_saving,
                            decoration: InputDecoration(
                              labelText: l10n.projectEditorBasicsFieldBrandName,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _brandPromiseCtrl,
                            focusNode: _brandPromiseFocus,
                            enabled: !_saving,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.projectEditorBasicsFieldBrandPromise,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _visualMotifsCtrl,
                            enabled: !_saving,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: l10n
                                  .projectEditorBasicsFieldVisualMotifsOnePerLine,
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          TextField(
                            controller: _forbiddenCtrl,
                            enabled: !_saving,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l10n
                                  .projectEditorBasicsFieldForbiddenOnePerLine,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
              ),
            ),
            const Divider(height: StudioControlSize.dividerThickness),
            Padding(
              padding: const EdgeInsets.fromLTRB(StudioSpacing.md, StudioSpacing.xs, StudioSpacing.md, StudioSpacing.sm),
              child: Wrap(
                spacing: StudioSpacing.xs,
                runSpacing: StudioSpacing.xs,
                alignment: WrapAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                            _closeSheet();
                            widget.onOpenFullProjectSettings();
                          },
                    child: Text(l10n.studioArtStepOpenFullSettings),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _closeSheet,
                    child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
                  ),
                  StudioPrimaryButton(
                    label: _saving
                        ? l10n.projectEditorSavingEllipsis
                        : l10n.studioArtStepBriefSheetSave,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
