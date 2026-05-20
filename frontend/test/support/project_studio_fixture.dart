import 'package:flutter/material.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/style_pack_catalog.dart';
import 'package:openflow_app/project_studio/art_step_panel.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:openflow_app/rust_api.dart';

const _fixtureProjectUuid = '550e8400-e29b-41d4-a716-446655440007';
const _fixtureProjectNumericId = 7;

/// Sample catalog for studio/editor widget and golden tests (no HTTP).
Future<StylePackCatalog> fixtureStylePackCatalogLoader(
  String accessToken,
  AppLocalizations l10n,
) async {
  return StylePackCatalog(
    artPacks: <StylePackOption>[
      StylePackOption(
        path: 'art_skills/2D_chinese_guofeng',
        name: l10n.localeName.startsWith('zh') ? '国风二维' : 'Guofeng 2D',
        description: l10n.localeName.startsWith('zh')
            ? '水墨线条与淡雅配色'
            : 'Ink lines with muted palette',
        tag: l10n.projectEditorStylePackTagArt,
      ),
    ],
    storyPacks: <StylePackOption>[
      StylePackOption(
        path: 'story_skills/Family_warmth',
        name: l10n.localeName.startsWith('zh') ? '家庭温情' : 'Family warmth',
        description: l10n.localeName.startsWith('zh')
            ? '温情叙事节奏'
            : 'Warm family narrative pacing',
        tag: l10n.projectEditorStylePackTagStory,
      ),
    ],
  );
}

ProjectRow fixtureArtStepProject({AppLocalizations? l10n}) {
  return ProjectRow(
    id: _fixtureProjectUuid,
    numericId: _fixtureProjectNumericId,
    name: l10n?.localeName.startsWith('zh') == true ? '演示项目' : 'Demo project',
    artStylePack: 'art_skills/2D_chinese_guofeng',
    storyStylePack: 'story_skills/Family_warmth',
    artStyle: l10n?.localeName.startsWith('zh') == true ? '柔和水彩' : 'Soft watercolor',
    projectAccessMode: 'inherited',
    projectAccessRole: 'owner',
  );
}

Widget _placeholderStepBody(StudioStep step, AppLocalizations? l10n) {
  final resolved = l10n;
  final body = resolved == null
      ? 'step-${step.slug}'
      : step == StudioStep.script
      ? resolved.studioStepScriptBody
      : 'step-${step.slug}';
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(body),
    ),
  );
}

Widget _artStepPanelBody({
  required ProjectRow project,
  ValueChanged<ProjectRow>? onProjectUpdated,
}) {
  return ProjectStudioArtStepPanel(
    accessToken: 'token',
    project: project,
    catalogLoader: fixtureStylePackCatalogLoader,
    onProjectUpdated: onProjectUpdated ?? (_) {},
    onOpenProjectSettings: () {},
  );
}

/// Minimal [ProjectStudioHost] on the script step for widget/golden tests.
ProjectStudioHost buildScriptStepStudioHost({
  AppLocalizations? l10n,
  ValueChanged<StudioStep>? onStepChanged,
}) {
  return ProjectStudioHost(
    projectNumericId: _fixtureProjectNumericId,
    projectUuid: _fixtureProjectUuid,
    projectName: l10n?.localeName.startsWith('zh') == true ? '演示项目' : 'Demo project',
    accessToken: 'token',
    initialStep: StudioStep.script,
    completedSteps: 1,
    onExit: () {},
    onStepChanged: onStepChanged ?? (_) {},
    onOpenAgentDrawer: () {},
    onRunHarnessAgent: (_) async {},
    buildStepBody: (step) => _placeholderStepBody(step, l10n),
  );
}

/// [ProjectStudioHost] on the art step with a real [ProjectStudioArtStepPanel].
ProjectStudioHost buildArtStepStudioHost({
  AppLocalizations? l10n,
  ProjectRow? project,
  ValueChanged<ProjectRow>? onProjectUpdated,
  ValueChanged<StudioStep>? onStepChanged,
  StudioStep initialStep = StudioStep.art,
}) {
  final row = project ?? fixtureArtStepProject(l10n: l10n);
  return ProjectStudioHost(
    projectNumericId: _fixtureProjectNumericId,
    projectUuid: row.id,
    projectName: row.name ?? '演示项目',
    accessToken: 'token',
    initialStep: initialStep,
    completedSteps: 2,
    onExit: () {},
    onStepChanged: onStepChanged ?? (_) {},
    onOpenAgentDrawer: () {},
    onRunHarnessAgent: (_) async {},
    buildStepBody: (step) {
      if (step == StudioStep.art) {
        return _artStepPanelBody(
          project: row,
          onProjectUpdated: onProjectUpdated,
        );
      }
      return _placeholderStepBody(step, l10n);
    },
  );
}
