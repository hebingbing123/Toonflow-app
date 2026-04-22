part of 'dialog_support.dart';

class ProjectScriptsWorkbenchSession {
  ProjectScriptsWorkbenchSession({required List<ScriptBrief> scriptList})
    : filterCtrl = TextEditingController(),
      selectedIdsCtrl = TextEditingController(
        text: encodeNumericIdSelection(
          scriptList.map((script) => script.numericId),
        ),
      ),
      groupSizeCtrl = TextEditingController(text: '3'),
      addCountCtrl = TextEditingController(text: '3'),
      addPrefixCtrl = TextEditingController(text: '新剧本'),
      addBodyCtrl = TextEditingController(text: '剧情梗概待补充。'),
      infoLine = scriptList.isEmpty
          ? '当前项目还没有剧本。'
          : '当前已载入 ${scriptList.length} 条剧本，可筛选后批量执行。';

  final TextEditingController filterCtrl;
  final TextEditingController selectedIdsCtrl;
  final TextEditingController groupSizeCtrl;
  final TextEditingController addCountCtrl;
  final TextEditingController addPrefixCtrl;
  final TextEditingController addBodyCtrl;

  bool localBusy = false;
  String infoLine;
  List<ScriptWorkbenchDetailRow> previewRows = <ScriptWorkbenchDetailRow>[];

  Iterable<int> get previewOrLocalIds => previewRows.isNotEmpty
      ? previewRows.map((row) => row.numericId)
      : const <int>[];

  List<int> selectedIds() => parseNumericIdSelection(selectedIdsCtrl.text);

  ScriptBatchWorkbenchDiagnosis diagnosis({
    required List<ScriptBrief> scriptList,
  }) {
    return diagnoseScriptBatchWorkbench(
      selectedIds: selectedIds(),
      scripts: scriptList,
      previewRows: previewRows,
    );
  }

  void syncSelectionFromScripts(List<ScriptBrief> scriptList) {
    if (previewRows.isEmpty) {
      selectedIdsCtrl.text = encodeNumericIdSelection(
        scriptList.map((script) => script.numericId),
      );
    }
  }

  void dispose() {
    filterCtrl.dispose();
    selectedIdsCtrl.dispose();
    groupSizeCtrl.dispose();
    addCountCtrl.dispose();
    addPrefixCtrl.dispose();
    addBodyCtrl.dispose();
  }
}
