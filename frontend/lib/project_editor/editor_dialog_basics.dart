part of '../../home_page.dart';

extension _HomePageProjectEditorDialogBasics on _HomePageState {
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
            padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
            decoration: studioInsetPanelDecoration(ctx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.projectEditorBasicsHomeSectionTitle,
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.projectEditorBasicsHomeReadinessLine(
                    home.readinessScore,
                    home.readinessSummary,
                  ),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: StudioSpacing.xs),
                if (home.onboarding.nextStep != null)
                  Text(
                    l10n.projectEditorBasicsHomeNextStep(
                      home.onboarding.nextStep!,
                    ),
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                const SizedBox(height: StudioSpacing.xs),
                ...studioStaggeredChildren(
                  home.onboarding.checklist.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
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
                  entranceKey: home.onboarding.checklist.length,
                ),
              ],
            ),
          ),
          const SizedBox(height: StudioSpacing.sm),
        ],
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldNameClearLabel,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        TextField(
          controller: introCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldIntroClearLabel,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          l10n.projectEditorBasicsPitchSectionTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: premiseCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldPremise,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: audienceCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldTargetAudience,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: toneCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldEmotionalTone,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: hookCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldCoreHook,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: visualCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldVisualDirection,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          l10n.projectEditorBasicsModelRoutingTitle,
          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StepModelRoutingSection(
          accessToken: token,
          projectId: p.id,
          textModelOptions: dialogState.textModelOptionsRef[0],
          imageModelOptions: dialogState.imageModelOptionsRef[0],
          videoModelOptions: dialogState.videoModelOptionsRef[0],
          onStepsChanged: (steps) {
            dialogState.stepModelsPatchRef[0] = steps;
          },
        ),
        const SizedBox(height: StudioSpacing.xs),
        ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          title: Text(
            l10n.projectEditorBasicsModalityDefaultsTitle,
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: StudioTokens.of(ctx).textSecondary,
            ),
          ),
          subtitle: Text(
            l10n.projectEditorBasicsModalityDefaultsSubtitle,
            style: studioHintStyle(ctx),
          ),
          children: <Widget>[
            _buildProjectModelField(
              l10n: l10n,
              setDialogState: setDialogState,
              controller: textModelCtrl,
              label: l10n.projectEditorBasicsTextModelLabel,
              helper: l10n.projectEditorBasicsTextModelHelper,
              suggestions: dialogState.textModelOptionsRef[0],
            ),
            const SizedBox(height: StudioSpacing.xs),
            _buildProjectModelField(
              l10n: l10n,
              setDialogState: setDialogState,
              controller: multimodalModelCtrl,
              label: l10n.projectEditorBasicsMultimodalModelLabel,
              helper: l10n.projectEditorBasicsMultimodalModelHelper,
              suggestions: dialogState.textModelOptionsRef[0],
            ),
            const SizedBox(height: StudioSpacing.xs),
            _buildProjectModelField(
              l10n: l10n,
              setDialogState: setDialogState,
              controller: imageModelCtrl,
              label: l10n.projectEditorBasicsImageModelLabel,
              suggestions: dialogState.imageModelOptionsRef[0],
            ),
            const SizedBox(height: StudioSpacing.xs),
            _buildProjectModelField(
              l10n: l10n,
              setDialogState: setDialogState,
              controller: videoModelCtrl,
              label: l10n.projectEditorBasicsVideoModelLabel,
              suggestions: dialogState.videoModelOptionsRef[0],
            ),
            const SizedBox(height: StudioSpacing.xs),
            _buildProjectModelField(
              l10n: l10n,
              setDialogState: setDialogState,
              controller: voiceModelCtrl,
              label: l10n.projectEditorBasicsVoiceModelLabel,
              helper: l10n.projectEditorBasicsVoiceModelHelper,
              suggestions: dialogState.textModelOptionsRef[0],
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: voiceProfileCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.projectEditorBasicsVoiceProfileLabel,
                helperText: l10n.projectEditorBasicsVoiceProfileHelper,
              ),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          l10n.projectEditorBasicsBrandSectionTitle,
          style: Theme.of(ctx).textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: brandNameCtrl,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldBrandName,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: brandPromiseCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldBrandPromise,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: visualMotifsCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldVisualMotifsOnePerLine,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: forbiddenCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldForbiddenOnePerLine,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        TextField(
          controller: continuityCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.projectEditorBasicsFieldContinuityRulesOnePerLine,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
        StylePackPickerField(
          label: l10n.projectEditorBasicsLabelArtStylePack,
          options: dialogState.artStylePackOptionsRef[0],
          selectedPath: dialogState.selectedArtStylePackRef[0],
          isArtPack: true,
          onChanged: (value) {
            setDialogState(
              () => dialogState.selectedArtStylePackRef[0] = value,
            );
          },
        ),
        const SizedBox(height: StudioSpacing.sm),
        StylePackPickerField(
          label: l10n.projectEditorBasicsLabelStoryStylePack,
          options: dialogState.storyStylePackOptionsRef[0],
          selectedPath: dialogState.selectedStoryStylePackRef[0],
          isArtPack: false,
          onChanged: (value) {
            setDialogState(
              () => dialogState.selectedStoryStylePackRef[0] = value,
            );
          },
        ),
        const SizedBox(height: StudioSpacing.sm),
        ShortDramaTargetsPanel(
          accessToken: token,
          project: detail.project,
          onSaved: () async {
            if (!mounted) return;
            await _projectsController.loadProjects();
          },
        ),
        const SizedBox(height: StudioSpacing.sm),
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
            style: studioHintStyle(ctx),
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
          const SizedBox(height: StudioSpacing.xs),
          Wrap(
            spacing: StudioSpacing.xs,
            runSpacing: StudioSpacing.xs,
            children: chips
                .map((entry) {
                  final modelId = entry.effectiveModelId;
                  return ActionChip(
                    avatar: normalized == modelId
                        ? const Icon(Icons.check, size: StudioIconSize.xs)
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
