part of 'section.dart';

class _TaskCenterWorkbenchControllers {
  _TaskCenterWorkbenchControllers({
    required this.pageCtrl,
    required this.limitCtrl,
    required this.stateCtrl,
    required this.taskClassCtrl,
    required this.productionPhaseCtrl,
    required this.projectIdCtrl,
    required this.projectUuidCtrl,
    required this.numericTaskIdCtrl,
    required this.uuidCtrl,
  });

  factory _TaskCenterWorkbenchControllers.create({
    int? initialProjectNumericId,
    String? initialProjectUuid,
    required List<TaskCenterProjectItem> initialProjects,
    required List<JobRow> initialJobs,
  }) {
    final initialSelection = resolveTaskCenterProjectSelection(
      projects: initialProjects,
      projectIdText: initialProjectNumericId?.toString(),
      projectUuid: initialProjectUuid,
    );
    return _TaskCenterWorkbenchControllers(
      pageCtrl: TextEditingController(text: '1'),
      limitCtrl: TextEditingController(text: '10'),
      stateCtrl: TextEditingController(),
      taskClassCtrl: TextEditingController(),
      productionPhaseCtrl: TextEditingController(),
      projectIdCtrl: TextEditingController(
        text:
            initialSelection.projectId?.toString() ??
            (initialProjects.isEmpty
                ? ''
                : initialProjects.first.numericId.toString()),
      ),
      projectUuidCtrl: TextEditingController(
        text:
            initialSelection.projectUuid ??
            (initialProjects.isEmpty ? '' : (initialProjects.first.projectUuid ?? '')),
      ),
      numericTaskIdCtrl: TextEditingController(
        text: initialJobs.isEmpty
            ? ''
            : initialJobs.first.numericTaskId.toString(),
      ),
      uuidCtrl: TextEditingController(
        text: initialJobs.isEmpty ? '' : initialJobs.first.id,
      ),
    );
  }

  final TextEditingController pageCtrl;
  final TextEditingController limitCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController taskClassCtrl;
  final TextEditingController productionPhaseCtrl;
  final TextEditingController projectIdCtrl;
  final TextEditingController projectUuidCtrl;
  final TextEditingController numericTaskIdCtrl;
  final TextEditingController uuidCtrl;

  void dispose() {
    pageCtrl.dispose();
    limitCtrl.dispose();
    stateCtrl.dispose();
    taskClassCtrl.dispose();
    productionPhaseCtrl.dispose();
    projectIdCtrl.dispose();
    projectUuidCtrl.dispose();
    numericTaskIdCtrl.dispose();
    uuidCtrl.dispose();
  }
}
