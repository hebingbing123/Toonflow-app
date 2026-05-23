import '../models/models.dart';

/// Base class for static code analyzers
abstract class StaticAnalyzer {
  /// Analyzes the given file and returns findings
  Future<List<Finding>> analyze(String filePath);
  
  /// Returns the category this analyzer handles
  FindingCategory get category;
}
