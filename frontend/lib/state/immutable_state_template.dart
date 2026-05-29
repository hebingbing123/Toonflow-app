/// Hand-rolled immutable view-model template (8.2 — no Freezed required).
///
/// Copy this pattern per feature; adopt codegen only when a vertical already uses it.
library;

class StudioImmutableStateTemplate {
  const StudioImmutableStateTemplate({
    required this.revision,
    this.label = '',
    this.busy = false,
    this.lastError,
  });

  final int revision;
  final String label;
  final bool busy;
  final Object? lastError;

  StudioImmutableStateTemplate copyWith({
    int? revision,
    String? label,
    bool? busy,
    Object? lastError,
    bool clearError = false,
  }) {
    return StudioImmutableStateTemplate(
      revision: revision ?? this.revision,
      label: label ?? this.label,
      busy: busy ?? this.busy,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StudioImmutableStateTemplate &&
        other.revision == revision &&
        other.label == label &&
        other.busy == busy &&
        other.lastError == lastError;
  }

  @override
  int get hashCode => Object.hash(revision, label, busy, lastError);
}
