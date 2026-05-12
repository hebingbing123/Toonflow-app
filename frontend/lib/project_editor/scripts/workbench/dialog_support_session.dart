part of 'dialog_support.dart';

class ProjectScriptsWorkbenchSession {
  ProjectScriptsWorkbenchSession({
    required this.l10n,
    required List<ScriptBrief> scriptList,
  }) : filterCtrl = TextEditingController(),
       selectedIdsCtrl = TextEditingController(
         text: encodeNumericIdSelection(
           scriptList.map((script) => script.numericId),
         ),
       ),
       groupSizeCtrl = TextEditingController(text: '3'),
       addCountCtrl = TextEditingController(text: '3'),
       addPrefixCtrl = TextEditingController(
         text: l10n.projectEditorScriptsWorkbenchDefaultNewScriptName,
       ),
       addBodyCtrl = TextEditingController(
         text: l10n.projectEditorScriptsSessionDefaultAddBody,
       ),
       infoLine = scriptList.isEmpty
           ? l10n.projectEditorScriptsSessionInfoNoScripts
           : l10n.projectEditorScriptsSessionInfoLoadedCount(scriptList.length);

  final AppLocalizations l10n;
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
      l10n,
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
