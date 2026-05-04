part of 'section.dart';

class _TaskCenterWorkbenchControllers {
  _TaskCenterWorkbenchControllers({
    required this.pageCtrl,
    required this.limitCtrl,
    required this.stateCtrl,
    required this.taskClassCtrl,
    required this.projectIdCtrl,
    required this.numericTaskIdCtrl,
    required this.uuidCtrl,
  });

  factory _TaskCenterWorkbenchControllers.create({
    int? initialProjectNumericId,
    required List<TaskCenterProjectItem> initialProjects,
    required List<JobRow> initialJobs,
  }) {
    return _TaskCenterWorkbenchControllers(
      pageCtrl: TextEditingController(text: '1'),
      limitCtrl: TextEditingController(text: '10'),
      stateCtrl: TextEditingController(),
      taskClassCtrl: TextEditingController(),
      projectIdCtrl: TextEditingController(
        text:
            initialProjectNumericId?.toString() ??
            (initialProjects.isEmpty
                ? ''
                : initialProjects.first.numericId.toString()),
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
  final TextEditingController projectIdCtrl;
  final TextEditingController numericTaskIdCtrl;
  final TextEditingController uuidCtrl;

  void dispose() {
    pageCtrl.dispose();
    limitCtrl.dispose();
    stateCtrl.dispose();
    taskClassCtrl.dispose();
    projectIdCtrl.dispose();
    numericTaskIdCtrl.dispose();
    uuidCtrl.dispose();
  }
}
