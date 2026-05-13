import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'support_models.dart';
import 'view.dart';

bool shortVideoHasVisualStyleSignal(ProjectRow? project) {
  if (project == null) {
    return false;
  }
  return (project.artStyle ?? '').trim().isNotEmpty ||
      (project.artStylePack ?? '').trim().isNotEmpty;
}

bool shortVideoHasDirectionSignal(ProjectRow? project) {
  if (project == null) {
    return false;
  }
  return (project.directorManual ?? '').trim().isNotEmpty ||
      (project.storyStylePack ?? '').trim().isNotEmpty;
}

String? shortVideoVisualStyleLabel(ProjectRow? project) {
  if (project == null) {
    return null;
  }
  final pack = (project.artStylePack ?? '').trim();
  if (pack.isNotEmpty) {
    return '风格包 $pack';
  }
  final style = (project.artStyle ?? '').trim();
  if (style.isNotEmpty) {
    return '画风 $style';
  }
  return null;
}

String? shortVideoDirectionLabel(ProjectRow? project) {
  if (project == null) {
    return null;
  }
  final pack = (project.storyStylePack ?? '').trim();
  if (pack.isNotEmpty) {
    return '故事包 $pack';
  }
  final manual = (project.directorManual ?? '').trim();
  if (manual.isNotEmpty) {
    return '手册 $manual';
  }
  return null;
}

String shortVideoModeLabelL10n(AppLocalizations l10n, ShortVideoMode mode) {
  return mode == ShortVideoMode.animated
      ? l10n.shortVideoSpaceModeTitleAnimated
      : l10n.shortVideoSpaceModeTitleLive;
}

String shortVideoVideoRatioLabelL10n(AppLocalizations l10n, String ratio) {
  switch (ratio) {
    case '16:9':
      return l10n.shortVideoSpaceAspectRatioLandscape169;
    case '1:1':
      return l10n.shortVideoSpaceAspectRatioSquare11;
    default:
      return l10n.shortVideoSpaceAspectRatioPortrait916;
  }
}

String shortVideoProjectReadinessSummary(ProjectStats? stats) {
  if (stats == null) {
    return '读取项目统计后，会在这里提示你更适合先去脚本还是制作。';
  }
  if (stats.scriptCount <= 0) {
    return '当前项目还没有剧本，建议先去脚本工作区生成第一版。';
  }
  if (stats.storyboardCount <= 0) {
    return '已有剧本但还缺分镜，建议先继续脚本/分镜规划，再进入制作。';
  }
  if (stats.roleCount <= 0) {
    return '已有脚本和分镜，但角色资产还少，建议先补角色与参考素材。';
  }
  return '脚本、分镜和角色资产都已有基础，可以直接进入制作工作区继续出图和出片。';
}

String shortVideoSpaceOverviewSummary({
  required bool loadingProjectOverview,
  required ProjectRow? project,
  required ProjectStats? projectStats,
  required TaskCenterGetTaskApiResult? recentProjectTasks,
  required QualityScopeInsightRow? qualityScopeInsight,
}) {
  if (loadingProjectOverview) {
    return '正在汇总当前项目的脚本、任务和质检状态…';
  }
  if (project == null) {
    return '先选一个项目，Space 才能把当前模式、任务和质检线索收成同一张概览。';
  }
  final taskCount = recentProjectTasks?.total ?? 0;
  final runningCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'running',
  );
  final failedCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'failed',
  );
  if (projectStats == null) {
    return '项目已选中，但概览还没读到。可以先刷新项目或直接进入脚本工作区。';
  }
  if (failedCount > 0) {
    return '这个项目最近有 $failedCount 个失败任务，建议先去任务中心定位失败点，再继续出图或出片。';
  }
  if (runningCount > 0) {
    return '当前还有 $runningCount 个任务在处理中，适合先去任务中心盯进度，同时准备下一轮脚本或素材。';
  }
  if ((qualityScopeInsight?.badCaseCount ?? 0) > 0) {
    return '这个项目已有 ${qualityScopeInsight!.badCaseCount} 条坏例记录，建议先看质量评审再决定是改脚本还是重做分镜。';
  }
  if (taskCount <= 0) {
    return shortVideoProjectReadinessSummary(projectStats);
  }
  return '当前项目最近已有 $taskCount 条任务记录，基础链路已经跑起来了，可以继续推进脚本、制作或质检复核。';
}

int shortVideoCountTasksByStatus(
  TaskCenterGetTaskApiResult? tasks,
  String status,
) {
  final rows = tasks?.data ?? const <JobRow>[];
  return rows.where((row) => row.status == status).length;
}

ShortVideoNextStepPlan buildShortVideoNextStepPlan({
  required bool isAnimated,
  required ProjectRow? project,
  required ProjectStats? stats,
  required TaskCenterGetTaskApiResult? recentProjectTasks,
  required QualityScopeInsightRow? qualityScopeInsight,
  required int sceneAssetCount,
  required int clipAssetCount,
}) {
  final failedCount = shortVideoCountTasksByStatus(
    recentProjectTasks,
    'failed',
  );
  if (project == null) {
    return const ShortVideoNextStepPlan(
      title: '先选一个短剧项目',
      detail: '选中项目后，Space 才能把模式、任务、质检和工作区上下文收成同一条主链路。',
      buttonLabel: '先去项目区',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (failedCount > 0) {
    return const ShortVideoNextStepPlan(
      title: '先处理失败任务',
      detail: '最近已有失败任务，先去任务中心确认是脚本、素材、出图还是出片环节卡住。',
      buttonLabel: '打开任务中心',
      target: ShortVideoNextStepTarget.tasks,
    );
  }
  if ((qualityScopeInsight?.badCaseCount ?? 0) > 0) {
    return ShortVideoNextStepPlan(
      title: '先看坏例和质检反馈',
      detail: isAnimated
          ? '当前更适合先看角色一致性、画面连续性和镜头节奏的坏例，再决定返工脚本还是分镜。'
          : '当前更适合先看表演自然度、场景真实感和口播镜头质感的坏例，再决定返工脚本还是镜头。',
      buttonLabel: '打开质量评审',
      target: ShortVideoNextStepTarget.quality,
    );
  }
  if (isAnimated && !shortVideoHasVisualStyleSignal(project)) {
    return const ShortVideoNextStepPlan(
      title: '先收口画风与视觉风格',
      detail: '动漫模式先把画风、视觉手册或风格包收口，后面的角色一致性和出图连续性会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && sceneAssetCount <= 0) {
    return const ShortVideoNextStepPlan(
      title: '先补真人场景参考',
      detail: '真人模式先补场景参考，后面的人物走位、真实空间感和镜头衔接会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && clipAssetCount <= 0) {
    return const ShortVideoNextStepPlan(
      title: '先补真人镜头参考',
      detail: '真人模式更依赖 clip / 镜头参考。先补镜头素材，后面的人物表演、景别和口播质感会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (!isAnimated && !shortVideoHasDirectionSignal(project)) {
    return const ShortVideoNextStepPlan(
      title: '先收口表演与口播手册',
      detail: '真人模式最好先把口播语气、表演节奏和导演手册收口，后面的配音和镜头演绎会更稳。',
      buttonLabel: '打开项目区补准备项',
      target: ShortVideoNextStepTarget.projects,
    );
  }
  if (stats == null || stats.scriptCount <= 0) {
    return ShortVideoNextStepPlan(
      title: '先生成第一版剧本',
      detail: isAnimated
          ? '先在脚本工作区把动漫短剧的情绪节奏、角色关系和章节改编跑起来。'
          : '先在脚本工作区把真人短剧的对白自然度、口播感和场景调度跑起来。',
      buttonLabel: '打开脚本工作区',
      target: ShortVideoNextStepTarget.scriptWorkspace,
    );
  }
  if (stats.storyboardCount <= 0) {
    return const ShortVideoNextStepPlan(
      title: '先补分镜和镜头结构',
      detail: '剧本已经有了，但还没拆到分镜层；下一步适合继续脚本/分镜规划，再进制作。',
      buttonLabel: '打开脚本工作区',
      target: ShortVideoNextStepTarget.scriptWorkspace,
    );
  }
  if (stats.roleCount <= 0) {
    return ShortVideoNextStepPlan(
      title: isAnimated ? '先补角色与画风资产' : '先补真人参考与角色设定',
      detail: isAnimated
          ? '分镜已经起步，但角色资产偏少，先补角色、画风和参考图会更稳。'
          : '分镜已经起步，但真人参考、角色设定和镜头参考还不够，先补这些会更稳。',
      buttonLabel: '打开制作工作区',
      target: ShortVideoNextStepTarget.productionWorkspace,
    );
  }
  return ShortVideoNextStepPlan(
    title: '可以直接推进制作与出片',
    detail: isAnimated
        ? '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区出图、出片和复核。'
        : '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区推进真人镜头、视频生成和复核。',
    buttonLabel: '打开制作工作区',
    target: ShortVideoNextStepTarget.productionWorkspace,
  );
}
