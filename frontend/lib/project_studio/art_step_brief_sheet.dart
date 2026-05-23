import 'package:flutter/material.dart';

import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

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
}) async {
  final l10n = AppLocalizations.of(context)!;
  final premiseCtrl = TextEditingController(text: home?.projectBrief?.premise ?? '');
  final audienceCtrl =
      TextEditingController(text: home?.projectBrief?.targetAudience ?? '');
  final toneCtrl =
      TextEditingController(text: home?.projectBrief?.emotionalTone ?? '');
  final hookCtrl = TextEditingController(text: home?.projectBrief?.coreHook ?? '');
  final visualCtrl =
      TextEditingController(text: home?.projectBrief?.visualDirection ?? '');
  final brandNameCtrl =
      TextEditingController(text: home?.brandBible?.brandName ?? '');
  final brandPromiseCtrl =
      TextEditingController(text: home?.brandBible?.brandPromise ?? '');
  final visualMotifsCtrl = TextEditingController(
    text: (home?.brandBible?.visualMotifs ?? const <String>[]).join('\n'),
  );
  final forbiddenCtrl = TextEditingController(
    text: (home?.brandBible?.forbiddenElements ?? const <String>[]).join('\n'),
  );

  try {
    await showStudioBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        var saving = false;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final viewport = MediaQuery.sizeOf(sheetCtx);
            final sheetHeight = viewport.height * 0.88;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom,
              ),
              child: SizedBox(
                height: sheetHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              l10n.studioArtStepBriefSheetTitle,
                              style: studioDialogTitleStyle(sheetCtx),
                            ),
                          ),
                          IconButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetCtx).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.studioArtStepBriefSheetSubtitle,
                        style: studioSectionIntroStyle(sheetCtx),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (home != null) ...<Widget>[
                              _ReadinessBlock(home: home, l10n: l10n),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              l10n.projectEditorBasicsPitchSectionTitle,
                              style: Theme.of(sheetCtx).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: premiseCtrl,
                              enabled: !saving,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: l10n.projectEditorBasicsFieldPremise,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: audienceCtrl,
                              enabled: !saving,
                              decoration: InputDecoration(
                                labelText:
                                    l10n.projectEditorBasicsFieldTargetAudience,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: toneCtrl,
                              enabled: !saving,
                              decoration: InputDecoration(
                                labelText:
                                    l10n.projectEditorBasicsFieldEmotionalTone,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: hookCtrl,
                              enabled: !saving,
                              decoration: InputDecoration(
                                labelText: l10n.projectEditorBasicsFieldCoreHook,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: visualCtrl,
                              enabled: !saving,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText:
                                    l10n.projectEditorBasicsFieldVisualDirection,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.projectEditorBasicsBrandSectionTitle,
                              style: Theme.of(sheetCtx).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: brandNameCtrl,
                              enabled: !saving,
                              decoration: InputDecoration(
                                labelText: l10n.projectEditorBasicsFieldBrandName,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: brandPromiseCtrl,
                              enabled: !saving,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText:
                                    l10n.projectEditorBasicsFieldBrandPromise,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: visualMotifsCtrl,
                              enabled: !saving,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: l10n
                                    .projectEditorBasicsFieldVisualMotifsOnePerLine,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: forbiddenCtrl,
                              enabled: !saving,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: l10n
                                    .projectEditorBasicsFieldForbiddenOnePerLine,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: <Widget>[
                          TextButton(
                            onPressed: saving
                                ? null
                                : () {
                                    Navigator.of(sheetCtx).pop();
                                    onOpenFullProjectSettings();
                                  },
                            child: Text(l10n.studioArtStepOpenFullSettings),
                          ),
                          TextButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetCtx).pop(),
                            child: Text(
                              l10n.projectEditorScriptsWorkbenchDialogClose,
                            ),
                          ),
                          StudioPrimaryButton(
                            label: saving
                                ? l10n.projectEditorSavingEllipsis
                                : l10n.studioArtStepBriefSheetSave,
                            onPressed: saving
                                ? null
                                : () async {
                                    setSheetState(() => saving = true);
                                    try {
                                      await updateProjectByProjectId(
                                        accessToken,
                                        project.id,
                                        <String, dynamic>{
                                          'projectBrief': ProjectBriefDraft(
                                            premise: premiseCtrl.text,
                                            targetAudience: audienceCtrl.text,
                                            emotionalTone: toneCtrl.text,
                                            coreHook: hookCtrl.text,
                                            visualDirection: visualCtrl.text,
                                          ).toJsonOrNull(),
                                          'brandBible': BrandBibleDraft(
                                            brandName: brandNameCtrl.text,
                                            brandPromise: brandPromiseCtrl.text,
                                            visualMotifs: _splitLines(
                                              visualMotifsCtrl.text,
                                            ),
                                            forbiddenElements: _splitLines(
                                              forbiddenCtrl.text,
                                            ),
                                          ).toJsonOrNull(),
                                        },
                                      );
                                      if (!sheetCtx.mounted) return;
                                      Navigator.of(sheetCtx).pop();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.studioArtStepBriefSheetSaved,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!sheetCtx.mounted) return;
                                      setSheetState(() => saving = false);
                                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            describeUserVisibleApiErrorResolved(
                                              sheetCtx,
                                              e,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    premiseCtrl.dispose();
    audienceCtrl.dispose();
    toneCtrl.dispose();
    hookCtrl.dispose();
    visualCtrl.dispose();
    brandNameCtrl.dispose();
    brandPromiseCtrl.dispose();
    visualMotifsCtrl.dispose();
    forbiddenCtrl.dispose();
  }
}

class _ReadinessBlock extends StatelessWidget {
  const _ReadinessBlock({required this.home, required this.l10n});

  final ProjectHome home;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: studioRecessedPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.projectEditorBasicsHomeSectionTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.projectEditorBasicsHomeReadinessLine(
                home.readinessScore,
                home.readinessSummary,
              ),
            ),
            if (home.onboarding.nextStep != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l10n.projectEditorBasicsHomeNextStep(home.onboarding.nextStep!),
                style: studioHintStyle(context),
              ),
            ],
            const SizedBox(height: 8),
            ...home.onboarding.checklist.take(4).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item.done
                      ? l10n.projectEditorBasicsHomeChecklistItemDone(
                          item.label,
                        )
                      : l10n.projectEditorBasicsHomeChecklistItemTodo(
                          item.label,
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
