import 'package:json_annotation/json_annotation.dart';

part 'before_after.g.dart';

/// Represents before and after code examples for a recommended fix
@JsonSerializable()
class BeforeAfter {
  /// Code snippet before the fix
  final String before;
  
  /// Code snippet after the fix
  final String after;

  const BeforeAfter({
    required this.before,
    required this.after,
  });

  factory BeforeAfter.fromJson(Map<String, dynamic> json) =>
      _$BeforeAfterFromJson(json);

  Map<String, dynamic> toJson() => _$BeforeAfterToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeforeAfter &&
          runtimeType == other.runtimeType &&
          before == other.before &&
          after == other.after;

  @override
  int get hashCode => before.hashCode ^ after.hashCode;
}
