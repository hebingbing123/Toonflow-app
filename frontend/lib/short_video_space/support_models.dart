enum ShortVideoNextStepTarget {
  projects,
  scriptWorkspace,
  productionWorkspace,
  tasks,
  quality,
}

class ShortVideoNextStepPlan {
  const ShortVideoNextStepPlan({
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.target,
  });

  final String title;
  final String detail;
  final String buttonLabel;
  final ShortVideoNextStepTarget target;
}
