import 'package:json_annotation/json_annotation.dart';

part 'fix_proposal.g.dart';

/// Represents a proposed fix for an audit finding
@JsonSerializable(explicitToJson: true)
class FixProposal {
  /// Unique identifier for this fix proposal
  final String id;
  
  /// ID of the finding this fix addresses
  final String findingId;
  
  /// Type of fix operation
  final FixType fixType;
  
  /// File path where the fix should be applied
  final String filePath;
  
  /// Line number where the fix starts
  final int startLine;
  
  /// Line number where the fix ends
  final int endLine;
  
  /// Original code to be replaced
  final String originalCode;
  
  /// Proposed replacement code
  final String proposedCode;
  
  /// Explanation of what the fix does
  final String explanation;
  
  /// Design system reference used in the fix
  final String? designSystemReference;
  
  /// Confidence level of the fix (0.0 to 1.0)
  final double confidence;
  
  /// Whether this fix has been applied
  final bool applied;
  
  /// Whether this fix passed validation
  final bool? validated;
  
  /// Validation error message if validation failed
  final String? validationError;

  const FixProposal({
    required this.id,
    required this.findingId,
    required this.fixType,
    required this.filePath,
    required this.startLine,
    required this.endLine,
    required this.originalCode,
    required this.proposedCode,
    required this.explanation,
    this.designSystemReference,
    required this.confidence,
    this.applied = false,
    this.validated,
    this.validationError,
  });

  factory FixProposal.fromJson(Map<String, dynamic> json) =>
      _$FixProposalFromJson(json);

  Map<String, dynamic> toJson() => _$FixProposalToJson(this);

  /// Creates a copy with updated fields
  FixProposal copyWith({
    String? id,
    String? findingId,
    FixType? fixType,
    String? filePath,
    int? startLine,
    int? endLine,
    String? originalCode,
    String? proposedCode,
    String? explanation,
    String? designSystemReference,
    double? confidence,
    bool? applied,
    bool? validated,
    String? validationError,
  }) {
    return FixProposal(
      id: id ?? this.id,
      findingId: findingId ?? this.findingId,
      fixType: fixType ?? this.fixType,
      filePath: filePath ?? this.filePath,
      startLine: startLine ?? this.startLine,
      endLine: endLine ?? this.endLine,
      originalCode: originalCode ?? this.originalCode,
      proposedCode: proposedCode ?? this.proposedCode,
      explanation: explanation ?? this.explanation,
      designSystemReference: designSystemReference ?? this.designSystemReference,
      confidence: confidence ?? this.confidence,
      applied: applied ?? this.applied,
      validated: validated ?? this.validated,
      validationError: validationError ?? this.validationError,
    );
  }

  @override
  String toString() {
    return 'FixProposal($id for $findingId: $fixType at $filePath:$startLine-$endLine)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FixProposal &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Types of fix operations
enum FixType {
  /// Replace hardcoded spacing with StudioSpacing constant
  replaceSpacing,
  
  /// Replace hardcoded typography with StudioTypography
  replaceTypography,
  
  /// Replace hardcoded color with StudioTokens color
  replaceColor,
  
  /// Add missing interaction states (hover, pressed, disabled)
  addInteractionStates,
  
  /// Add empty state handling
  addEmptyState,
  
  /// Fix responsive layout issues
  fixResponsive,
  
  /// Replace custom component with design system component
  replaceComponent,
  
  /// Add accessibility labels
  addAccessibilityLabels,
  
  /// Fix color contrast
  fixColorContrast,
  
  /// Add visual feedback (ripple, state changes)
  addVisualFeedback,
  
  /// Fix touch target size
  fixTouchTarget,
  
  /// Other custom fix
  other,
}
