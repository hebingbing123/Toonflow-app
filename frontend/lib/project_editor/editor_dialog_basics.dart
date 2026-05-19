import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
part of '../../home_page.dart';

extension _HomePageProjectEditorDialogBasics on _HomePageState {
  Widget _buildStylePackPickerField({
    required BuildContext ctx,
    required String label,
    required List<_StylePackOption> options,
    required String? selectedPath,
    required ValueChanged<String?> onChanged,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    _StylePackOption? selected;
    for (final option in options) {
      if (option.path == selectedPath) {
        selected = option;
        break;
      }
    }
    final hasSelectedOutsideList =
        selectedPath != null && selected == null && selectedPath.isNotEmpty;
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(l10n.projectEditorBasicsStylePackPickerNone),
      ),
      ...options.map(
        (option) => DropdownMenuItem<String>(
          value: option.path,
          child: Text(
            l10n.projectEditorBasicsStylePackOptionDisplay(
              option.name,
              option.tag,
            ),
          ),
        ),
      ),
      if (hasSelectedOutsideList)
        DropdownMenuItem<String>(
          value: selectedPath,
          child: Text(
            l10n.projectEditorBasicsStylePackPickerCurrentConfigRow(
              selectedPath,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioDropdownButtonFormField<String>(
          initialValue: selectedPath ?? '',
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: items,
          onChanged: (value) =>
              onChanged((value == null || value.isEmpty) ? null : value),
        ),
        const SizedBox(height: 4),
        Text(
          selected?.description ??
              (hasSelectedOutsideList
                  ? l10n.projectEditorBasicsStylePackFootnoteLegacy
                  : l10n.projectEditorBasicsStylePackFootnoteNone),
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectEditorBasicsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required TextEditingController premiseCtrl,
    required TextEditingController audienceCtrl,
    required TextEditingController toneCtrl,
    required TextEditingController hookCtrl,
    required TextEditingController visualCtrl,
    required TextEditingController textModelCtrl,
    required TextEditingController multimodalModelCtrl,
    required TextEditingController imageModelCtrl,
    required TextEditingController videoModelCtrl,
    required TextEditingController voiceModelCtrl,
    required TextEditingController voiceProfileCtrl,
    required TextEditingController brandNameCtrl,
    required TextEditingController brandPromiseCtrl,
    required TextEditingController visualMotifsCtrl,
    required TextEditingController forbiddenCtrl,
    required TextEditingController continuityCtrl,
    required _ProjectEditorDialogState dialogState,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    final home = dialogState.homeRef[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (home != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(ctx).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(
                ctx,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.projectEditorBasicsHomeSectionTitle,
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.projectEditorBasicsHomeReadinessLine(
                    home.readinessScore,
                    home.readinessSummary,
                  ),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                if (home.onboarding.nextStep != null)
                  Text(
                    l10n.projectEditorBasicsHomeNextStep(
                      home.onboarding.nextStep!,
                    ),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                ...home.onboarding.checklist.map(
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
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldNameClearLabel,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: introCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldIntroClearLabel,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.projectEditorBasicsPitchSectionTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: premiseCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldPremise,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: audienceCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldTargetAudience,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: toneCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldEmotionalTone,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: hookCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldCoreHook,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: visualCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldVisualDirection,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.projectEditorBasicsModelRoutingTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _buildProjectModelField(
          l10n: l10n,
          setDialogState: setDialogState,
          controller: textModelCtrl,
          label: l10n.projectEditorBasicsTextModelLabel,
          helper: l10n.projectEditorBasicsTextModelHelper,
          suggestions: dialogState.textModelOptionsRef[0],
        ),
        const SizedBox(height: 8),
        _buildProjectModelField(
          l10n: l10n,
          setDialogState: setDialogState,
          controller: multimodalModelCtrl,
          label: l10n.projectEditorBasicsMultimodalModelLabel,
          helper: l10n.projectEditorBasicsMultimodalModelHelper,
          suggestions: dialogState.textModelOptionsRef[0],
        ),
        const SizedBox(height: 8),
        _buildProjectModelField(
          l10n: l10n,
          setDialogState: setDialogState,
          controller: imageModelCtrl,
          label: l10n.projectEditorBasicsImageModelLabel,
          suggestions: dialogState.imageModelOptionsRef[0],
        ),
        const SizedBox(height: 8),
        _buildProjectModelField(
          l10n: l10n,
          setDialogState: setDialogState,
          controller: videoModelCtrl,
          label: l10n.projectEditorBasicsVideoModelLabel,
          suggestions: dialogState.videoModelOptionsRef[0],
        ),
        const SizedBox(height: 8),
        _buildProjectModelField(
          l10n: l10n,
          setDialogState: setDialogState,
          controller: voiceModelCtrl,
          label: l10n.projectEditorBasicsVoiceModelLabel,
          helper: l10n.projectEditorBasicsVoiceModelHelper,
          suggestions: dialogState.textModelOptionsRef[0],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: voiceProfileCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsVoiceProfileLabel,
            helperText: l10n.projectEditorBasicsVoiceProfileHelper,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.projectEditorBasicsBrandSectionTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: brandNameCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldBrandName,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: brandPromiseCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldBrandPromise,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: visualMotifsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldVisualMotifsOnePerLine,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: forbiddenCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldForbiddenOnePerLine,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: continuityCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldContinuityRulesOnePerLine,
          ),
        ),
        const SizedBox(height: 12),
        _buildStylePackPickerField(
          ctx: ctx,
          label: l10n.projectEditorBasicsLabelArtStylePack,
          options: dialogState.artStylePackOptionsRef[0],
          selectedPath: dialogState.selectedArtStylePackRef[0],
          onChanged: (value) {
            setDialogState(
              () => dialogState.selectedArtStylePackRef[0] = value,
            );
          },
        ),
        const SizedBox(height: 12),
        _buildStylePackPickerField(
          ctx: ctx,
          label: l10n.projectEditorBasicsLabelStoryStylePack,
          options: dialogState.storyStylePackOptionsRef[0],
          selectedPath: dialogState.selectedStoryStylePackRef[0],
          onChanged: (value) {
            setDialogState(
              () => dialogState.selectedStoryStylePackRef[0] = value,
            );
          },
        ),
        const SizedBox(height: 16),
        ShortDramaTargetsPanel(
          accessToken: token,
          project: detail.project,
          onSaved: () async {
            if (!mounted) return;
            await _projectsController.loadProjects();
          },
        ),
        const SizedBox(height: 12),
        if (dialogState.statsRef[0] != null)
          Text(
            l10n.projectEditorBasicsStatsLine(
              dialogState.statsRef[0]!.scriptCount,
              dialogState.statsRef[0]!.storyboardCount,
              dialogState.statsRef[0]!.novelCount,
              dialogState.statsRef[0]!.roleCount,
              dialogState.statsRef[0]!.videoCount,
            ),
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            l10n.projectEditorBasicsStatsNotLoaded,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
      ],
    );
  }

  Widget _buildProjectModelField({
    required AppLocalizations l10n,
    required StateSetter setDialogState,
    required TextEditingController controller,
    required String label,
    String? helper,
    List<ModelListEntry> suggestions = const <ModelListEntry>[],
  }) {
    final normalized = controller.text.trim();
    final chips = suggestions
        .where((entry) => entry.effectiveModelId.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper ?? l10n.projectEditorBasicsModelCatalogHelper,
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((entry) {
                  final modelId = entry.effectiveModelId;
                  return ActionChip(
                    avatar: normalized == modelId
                        ? const Icon(Icons.check, size: 16)
                        : null,
                    label: Text(entry.label),
                    onPressed: () {
                      controller.text = modelId;
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                      setDialogState(() {});
                    },
                  );
                })
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}
