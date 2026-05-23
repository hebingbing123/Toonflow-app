/// Result of applying automated fixes from an audit report.
class FixRunResult {
  final int fixedCount;
  final int skippedCount;
  final int filesModified;
  final List<String> modifiedFiles;
  final List<String> validationFailures;

  const FixRunResult({
    required this.fixedCount,
    required this.skippedCount,
    required this.filesModified,
    this.modifiedFiles = const [],
    this.validationFailures = const [],
  });

  bool get hasValidationFailures => validationFailures.isNotEmpty;
}
