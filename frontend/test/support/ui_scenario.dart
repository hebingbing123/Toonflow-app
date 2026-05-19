/// Inventory scenario identifiers for UI golden and smoke tests.
enum UiScenarioPane {
  login,
  projects,
  tasks,
  quality,
  jobs,
  notifications,
  shortVideo,
  search,
  studioScript,
  studioArt,
  studioAssets,
  studioStoryboard,
  studioVideo,
  studioDeliver,
}

enum UiDataState { defaultState, empty, error, stale }

class UiScenario {
  const UiScenario({
    required this.id,
    required this.pane,
    this.dataState = UiDataState.defaultState,
    this.viewportWidth = 1440,
    this.viewportHeight = 960,
  });

  final String id;
  final UiScenarioPane pane;
  final UiDataState dataState;
  final double viewportWidth;
  final double viewportHeight;
}

/// Wave-1 scenarios bound in [docs/plans/ui-surface-inventory.md].
const List<UiScenario> kUiGalleryWave1 = <UiScenario>[
  UiScenario(id: 'login_default', pane: UiScenarioPane.login),
  UiScenario(id: 'projects_default', pane: UiScenarioPane.projects),
  UiScenario(
    id: 'quality_default',
    pane: UiScenarioPane.quality,
  ),
  UiScenario(
    id: 'quality_stale',
    pane: UiScenarioPane.quality,
    dataState: UiDataState.stale,
  ),
  UiScenario(id: 'tasks_default', pane: UiScenarioPane.tasks),
  UiScenario(
    id: 'tasks_empty',
    pane: UiScenarioPane.tasks,
    dataState: UiDataState.empty,
  ),
  UiScenario(id: 'jobs_default', pane: UiScenarioPane.jobs),
  UiScenario(
    id: 'projects_empty',
    pane: UiScenarioPane.projects,
    dataState: UiDataState.empty,
  ),
  UiScenario(
    id: 'quality_empty',
    pane: UiScenarioPane.quality,
    dataState: UiDataState.empty,
  ),
  UiScenario(id: 'notifications_studio', pane: UiScenarioPane.notifications),
  UiScenario(id: 'short_video_overview', pane: UiScenarioPane.shortVideo),
  UiScenario(
    id: 'search_empty',
    pane: UiScenarioPane.search,
    dataState: UiDataState.empty,
  ),
  UiScenario(id: 'studio_step_script', pane: UiScenarioPane.studioScript),
  UiScenario(id: 'storyboard_studio', pane: UiScenarioPane.studioStoryboard),
  UiScenario(id: 'episode_console', pane: UiScenarioPane.studioDeliver),
];
