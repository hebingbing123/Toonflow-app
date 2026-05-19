import '../rust_api.dart';

/// Picks the default product-scoped project: most recent «继续创作» entry, else first list item.
ProjectRow? resolveDefaultProductScopedProject({
  required List<ProjectRow> projects,
  List<String> recentProjectIds = const <String>[],
}) {
  if (projects.isEmpty) {
    return null;
  }
  if (recentProjectIds.isNotEmpty) {
    final byId = <String, ProjectRow>{for (final project in projects) project.id: project};
    for (final id in recentProjectIds) {
      final match = byId[id];
      if (match != null) {
        return match;
      }
    }
  }
  return projects.first;
}
