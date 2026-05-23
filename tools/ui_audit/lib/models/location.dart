import 'package:json_annotation/json_annotation.dart';

part 'location.g.dart';

/// Represents the location of a finding in the codebase
@JsonSerializable()
class Location {
  /// File path relative to project root
  final String file;
  
  /// Line number (1-indexed)
  final int line;
  
  /// Column number (1-indexed)
  final int column;
  
  /// Optional widget path in the widget tree
  /// Example: "Scaffold > Column > Card > Text"
  final String? widgetPath;

  const Location({
    required this.file,
    required this.line,
    required this.column,
    this.widgetPath,
  });

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  Map<String, dynamic> toJson() => _$LocationToJson(this);

  @override
  String toString() {
    final buffer = StringBuffer('$file:$line:$column');
    if (widgetPath != null) {
      buffer.write(' ($widgetPath)');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          file == other.file &&
          line == other.line &&
          column == other.column &&
          widgetPath == other.widgetPath;

  @override
  int get hashCode =>
      file.hashCode ^ line.hashCode ^ column.hashCode ^ widgetPath.hashCode;
}
