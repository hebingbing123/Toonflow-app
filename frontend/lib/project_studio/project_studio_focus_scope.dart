import 'package:flutter/widgets.dart';

/// Live script intake counts for the project-studio focus subtitle.
class ProjectStudioFocusState extends ChangeNotifier {
  int? scriptNovelCount;
  int? scriptScriptCount;

  void updateScriptContentCounts({
    required int novelCount,
    required int scriptCount,
  }) {
    if (scriptNovelCount == novelCount && scriptScriptCount == scriptCount) {
      return;
    }
    scriptNovelCount = novelCount;
    scriptScriptCount = scriptCount;
    notifyListeners();
  }
}

/// Lets step bodies (e.g. script intake) update the shell focus subtitle.
class ProjectStudioFocusScope extends InheritedNotifier<ProjectStudioFocusState> {
  const ProjectStudioFocusScope({
    super.key,
    required ProjectStudioFocusState state,
    required super.child,
  }) : super(notifier: state);

  static ProjectStudioFocusScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ProjectStudioFocusScope>();
  }

  static void reportScriptContentCounts(
    BuildContext context, {
    required int novelCount,
    required int scriptCount,
  }) {
    maybeOf(context)?.notifier?.updateScriptContentCounts(
      novelCount: novelCount,
      scriptCount: scriptCount,
    );
  }
}
