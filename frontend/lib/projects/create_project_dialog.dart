import 'package:flutter/material.dart';
import '../design_system/tokens.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';

Future<Map<String, dynamic>?> showCreateProjectDialog(BuildContext context) {
  final nameController = TextEditingController();
  final introController = TextEditingController();
  final premiseController = TextEditingController();
  final audienceController = TextEditingController();
  final toneController = TextEditingController();
  final hookController = TextEditingController();
  final visualController = TextEditingController();
  final brandNameController = TextEditingController();
  final brandPromiseController = TextEditingController();
  final motifsController = TextEditingController();
  final forbiddenController = TextEditingController();
  final continuityController = TextEditingController();

  return showStudioDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      final l10n = resolveAppLocalizationsForErrors(dialogContext);
      return StudioAlertDialog(
        title: Text(l10n.projectsDialogCreateTitle),
        content: SizedBox(
          width: studioConstrainedDialogWidth(context, maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldName,
                  ),
                ),
                const SizedBox(height: StudioSpacing.sm),
                TextField(
                  controller: introController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldIntro,
                  ),
                ),
                const SizedBox(height: StudioSpacing.sm),
                Text(
                  l10n.projectsDialogSectionBrief,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: premiseController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldPremise,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: audienceController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldTargetAudience,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: toneController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldEmotionalTone,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: hookController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldCoreHook,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: visualController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldVisualDirection,
                  ),
                ),
                const SizedBox(height: StudioSpacing.sm),
                Text(
                  l10n.projectsDialogSectionBrand,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: brandNameController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldBrandName,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: brandPromiseController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldBrandPromise,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: motifsController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldVisualMotifsMultiline,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: forbiddenController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldForbiddenElementsMultiline,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: StudioSpacing.xs),
                TextField(
                  controller: continuityController,
                  decoration: InputDecoration(
                    labelText: l10n.projectsDialogFieldContinuityRulesMultiline,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.notificationsActionCancel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(dialogContext),
            onPressed: () {
              List<String> splitLines(String raw) => raw
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList(growable: false);

              final brief = ProjectBriefDraft(
                premise: premiseController.text.trim(),
                targetAudience: audienceController.text.trim(),
                emotionalTone: toneController.text.trim(),
                coreHook: hookController.text.trim(),
                visualDirection: visualController.text.trim(),
              ).toJsonOrNull();

              final brandBible = BrandBibleDraft(
                brandName: brandNameController.text.trim(),
                brandPromise: brandPromiseController.text.trim(),
                visualMotifs: splitLines(motifsController.text),
                forbiddenElements: splitLines(forbiddenController.text),
                continuityRules: splitLines(continuityController.text),
              ).toJsonOrNull();

              final result = <String, dynamic>{};
              if (nameController.text.trim().isNotEmpty) {
                result['name'] = nameController.text.trim();
              }
              if (introController.text.trim().isNotEmpty) {
                result['intro'] = introController.text.trim();
              }
              if (brief != null) {
                result['projectBrief'] = brief;
              }
              if (brandBible != null) {
                result['brandBible'] = brandBible;
              }
              Navigator.of(dialogContext).pop(result);
            },
            child: Text(l10n.projectsDialogCreateButton),
          ),
        ],
      );
    },
  ).whenComplete(() {
    nameController.dispose();
    introController.dispose();
    premiseController.dispose();
    audienceController.dispose();
    toneController.dispose();
    hookController.dispose();
    visualController.dispose();
    brandNameController.dispose();
    brandPromiseController.dispose();
    motifsController.dispose();
    forbiddenController.dispose();
    continuityController.dispose();
  });
}
