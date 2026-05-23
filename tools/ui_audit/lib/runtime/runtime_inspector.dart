import '../models/models.dart';

/// Runtime inspection phase (widget tree, breakpoints).
///
/// Full implementation requires Flutter SDK + `flutter_test`. This MVP returns
/// empty findings when runtime is disabled or unavailable.
abstract class RuntimeInspector {
  Future<RuntimeInspectionResult> inspect(RuntimeInspectionContext context);
}

class RuntimeInspectionContext {
  final String projectPath;
  final List<int> breakpoints;
  final bool captureScreenshots;

  const RuntimeInspectionContext({
    required this.projectPath,
    required this.breakpoints,
    this.captureScreenshots = false,
  });
}

class RuntimeInspectionResult {
  final List<Finding> findings;
  final List<AuditError> errors;
  final int? widgetsInspected;

  const RuntimeInspectionResult({
    this.findings = const [],
    this.errors = const [],
    this.widgetsInspected,
  });
}

/// Placeholder when Flutter UI library is unavailable (plain `dart run`).
class NoOpRuntimeInspector implements RuntimeInspector {
  @override
  Future<RuntimeInspectionResult> inspect(RuntimeInspectionContext context) async {
    return RuntimeInspectionResult(
      errors: [
        AuditError(
          phase: 'runtime_inspection',
          file: context.projectPath,
          message:
              'Runtime inspection requires Flutter SDK; use `flutter run` or pass --static-only',
        ),
      ],
    );
  }
}
