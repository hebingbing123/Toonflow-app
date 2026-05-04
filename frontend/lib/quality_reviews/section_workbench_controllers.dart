part of 'section.dart';

class _QualityReviewsWorkbenchControllers {
  _QualityReviewsWorkbenchControllers({
    required this.projectIdFilterCtrl,
    required this.scriptIdFilterCtrl,
    required this.targetTypeFilterCtrl,
    required this.targetIdFilterCtrl,
    required this.jobIdFilterCtrl,
    required this.stageFilterCtrl,
    required this.gradeFilterCtrl,
    required this.reviewIdCtrl,
    required this.createProjectIdCtrl,
    required this.createScriptIdCtrl,
    required this.createTargetTypeCtrl,
    required this.createTargetIdCtrl,
    required this.createSourceCtrl,
    required this.createScoreCtrl,
    required this.createStageCtrl,
    required this.createGradeCtrl,
    required this.createCommentsCtrl,
    required this.createBadCaseCategoryCtrl,
  });

  factory _QualityReviewsWorkbenchControllers.create() {
    return _QualityReviewsWorkbenchControllers(
      projectIdFilterCtrl: TextEditingController(),
      scriptIdFilterCtrl: TextEditingController(),
      targetTypeFilterCtrl: TextEditingController(),
      targetIdFilterCtrl: TextEditingController(),
      jobIdFilterCtrl: TextEditingController(),
      stageFilterCtrl: TextEditingController(text: 'all'),
      gradeFilterCtrl: TextEditingController(text: 'all'),
      reviewIdCtrl: TextEditingController(),
      createProjectIdCtrl: TextEditingController(),
      createScriptIdCtrl: TextEditingController(),
      createTargetTypeCtrl: TextEditingController(text: 'output'),
      createTargetIdCtrl: TextEditingController(
        text: 'flutter-workbench-${DateTime.now().millisecondsSinceEpoch}',
      ),
      createSourceCtrl: TextEditingController(text: 'manual'),
      createScoreCtrl: TextEditingController(text: '8'),
      createStageCtrl: TextEditingController(text: 'video_prompt'),
      createGradeCtrl: TextEditingController(text: 'B'),
      createCommentsCtrl: TextEditingController(
        text: 'quality workbench review',
      ),
      createBadCaseCategoryCtrl: TextEditingController(),
    );
  }

  final TextEditingController projectIdFilterCtrl;
  final TextEditingController scriptIdFilterCtrl;
  final TextEditingController targetTypeFilterCtrl;
  final TextEditingController targetIdFilterCtrl;
  final TextEditingController jobIdFilterCtrl;
  final TextEditingController stageFilterCtrl;
  final TextEditingController gradeFilterCtrl;
  final TextEditingController reviewIdCtrl;
  final TextEditingController createProjectIdCtrl;
  final TextEditingController createScriptIdCtrl;
  final TextEditingController createTargetTypeCtrl;
  final TextEditingController createTargetIdCtrl;
  final TextEditingController createSourceCtrl;
  final TextEditingController createScoreCtrl;
  final TextEditingController createStageCtrl;
  final TextEditingController createGradeCtrl;
  final TextEditingController createCommentsCtrl;
  final TextEditingController createBadCaseCategoryCtrl;

  void dispose() {
    projectIdFilterCtrl.dispose();
    scriptIdFilterCtrl.dispose();
    targetTypeFilterCtrl.dispose();
    targetIdFilterCtrl.dispose();
    jobIdFilterCtrl.dispose();
    stageFilterCtrl.dispose();
    gradeFilterCtrl.dispose();
    reviewIdCtrl.dispose();
    createProjectIdCtrl.dispose();
    createScriptIdCtrl.dispose();
    createTargetTypeCtrl.dispose();
    createTargetIdCtrl.dispose();
    createSourceCtrl.dispose();
    createScoreCtrl.dispose();
    createStageCtrl.dispose();
    createGradeCtrl.dispose();
    createCommentsCtrl.dispose();
    createBadCaseCategoryCtrl.dispose();
  }
}
