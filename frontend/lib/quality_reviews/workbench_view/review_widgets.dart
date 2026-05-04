part of '../workbench_view.dart';

const List<String> _qualityStageOptions = <String>[
  'all',
  'story_skeleton',
  'adaptation_strategy',
  'director_planning',
  'storyboard_table',
  'storyboard_panel',
  'video_prompt',
];

const List<String> _qualityGradeOptions = <String>['all', 'A', 'B', 'C', 'D'];

String _qualityStageLabel(String stage) {
  switch (stage) {
    case 'all':
      return '全部';
    case 'story_skeleton':
      return '故事骨架';
    case 'adaptation_strategy':
      return '改编策略';
    case 'director_planning':
      return '导演规划';
    case 'storyboard_table':
      return '分镜表';
    case 'storyboard_panel':
      return '分镜面板';
    case 'video_prompt':
      return '视频提示词';
    default:
      return stage;
  }
}

Color _qualityGradeColor(BuildContext context, String grade) {
  final scheme = Theme.of(context).colorScheme;
  switch (grade) {
    case 'A':
      return scheme.primaryContainer;
    case 'B':
      return scheme.secondaryContainer;
    case 'C':
      return scheme.tertiaryContainer;
    case 'D':
      return scheme.errorContainer;
    default:
      return scheme.surfaceContainerHighest;
  }
}
