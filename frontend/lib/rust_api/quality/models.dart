import '../../config.dart';

/// Quality review domain models and payload builders.
class QualityReview {
  const QualityReview({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    this.projectId,
    this.scriptId,
    this.jobId,
    required this.targetType,
    this.targetId,
    required this.source,
    this.plotCoherence,
    this.characterConsistency,
    this.dialogueNaturalness,
    this.pacing,
    this.faithfulness,
    this.visualQuality,
    this.overallScore,
    this.passed,
    this.comments,
    this.skillVersion,
    this.modelName,
    this.modelParams,
    this.memoryDeliveryPriorityApplied,
    this.reviewerId,
    this.dimensionScores,
    required this.isBadCase,
    this.badCaseCategory,
    this.stage,
    this.grade,
    this.skillFilePath,
    this.skillVersionHash,
    this.suggestedAction,
  });

  final String id;
  final String createdAt;
  final String updatedAt;
  final String userId;
  final int? projectId;
  final int? scriptId;
  final String? jobId;
  final String targetType;
  final String? targetId;
  final String source;
  final int? plotCoherence;
  final int? characterConsistency;
  final int? dialogueNaturalness;
  final int? pacing;
  final int? faithfulness;
  final int? visualQuality;
  final int? overallScore;
  final bool? passed;
  final String? comments;
  final String? skillVersion;
  final String? modelName;
  final Map<String, dynamic>? modelParams;
  final bool? memoryDeliveryPriorityApplied;
  final String? reviewerId;
  final Map<String, int>? dimensionScores;
  final bool isBadCase;
  final String? badCaseCategory;
  final String? stage;
  final String? grade;
  final String? skillFilePath;
  final String? skillVersionHash;
  final String? suggestedAction;

  factory QualityReview.fromJson(Map<String, dynamic> json) {
    int? asInt(String key) =>
        json[key] == null ? null : (json[key] as num).toInt();

    return QualityReview(
      id: json['id'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      userId: json['userId'] as String,
      projectId: asInt('projectId'),
      scriptId: asInt('scriptId'),
      jobId: json['jobId'] as String?,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String?,
      source: json['source'] as String,
      plotCoherence: asInt('plotCoherence'),
      characterConsistency: asInt('characterConsistency'),
      dialogueNaturalness: asInt('dialogueNaturalness'),
      pacing: asInt('pacing'),
      faithfulness: asInt('faithfulness'),
      visualQuality: asInt('visualQuality'),
      overallScore: asInt('overallScore'),
      passed: json['passed'] as bool?,
      comments: json['comments'] as String?,
      skillVersion: json['skillVersion'] as String?,
      modelName: json['modelName'] as String?,
      modelParams: json['modelParams'] == null
          ? null
          : Map<String, dynamic>.from(json['modelParams'] as Map),
      memoryDeliveryPriorityApplied:
          json['memoryDeliveryPriorityApplied'] as bool?,
      reviewerId: json['reviewerId'] as String?,
      dimensionScores: _readDimensionScores(json['dimensionScores']),
      isBadCase: json['isBadCase'] as bool? ?? false,
      badCaseCategory: json['badCaseCategory'] as String?,
      stage: json['stage'] as String?,
      grade: json['grade'] as String?,
      skillFilePath: json['skillFilePath'] as String?,
      skillVersionHash: json['skillVersionHash'] as String?,
      suggestedAction: json['suggestedAction'] as String?,
    );
  }
}

class CreateQualityReviewBody {
  const CreateQualityReviewBody({
    required this.targetType,
    this.projectId,
    this.scriptId,
    this.jobId,
    this.targetId,
    this.source,
    this.plotCoherence,
    this.characterConsistency,
    this.dialogueNaturalness,
    this.pacing,
    this.faithfulness,
    this.visualQuality,
    this.overallScore,
    this.passed,
    this.comments,
    this.skillVersion,
    this.modelName,
    this.modelParams,
    this.memoryDeliveryPriorityApplied,
    this.dimensionScores,
    this.isBadCase,
    this.badCaseCategory,
    this.stage,
    this.grade,
    this.skillFilePath,
    this.skillVersionHash,
  });

  final int? projectId;
  final int? scriptId;
  final String? jobId;
  final String targetType;
  final String? targetId;
  final String? source;
  final int? plotCoherence;
  final int? characterConsistency;
  final int? dialogueNaturalness;
  final int? pacing;
  final int? faithfulness;
  final int? visualQuality;
  final int? overallScore;
  final bool? passed;
  final String? comments;
  final String? skillVersion;
  final String? modelName;
  final Map<String, dynamic>? modelParams;
  final bool? memoryDeliveryPriorityApplied;
  final Map<String, int>? dimensionScores;
  final bool? isBadCase;
  final String? badCaseCategory;
  final String? stage;
  final String? grade;
  final String? skillFilePath;
  final String? skillVersionHash;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'targetType': targetType};
    void put(String key, Object? value) {
      if (value != null) {
        map[key] = value;
      }
    }

    put('projectId', projectId);
    put('scriptId', scriptId);
    put('jobId', jobId);
    put('targetId', targetId);
    put('source', source);
    put('plotCoherence', plotCoherence);
    put('characterConsistency', characterConsistency);
    put('dialogueNaturalness', dialogueNaturalness);
    put('pacing', pacing);
    put('faithfulness', faithfulness);
    put('visualQuality', visualQuality);
    put('overallScore', overallScore);
    put('passed', passed);
    put('comments', comments);
    put('skillVersion', skillVersion);
    put('modelName', modelName);
    put('modelParams', modelParams);
    put('memoryDeliveryPriorityApplied', memoryDeliveryPriorityApplied);
    put('dimensionScores', dimensionScores);
    put('isBadCase', isBadCase);
    put('badCaseCategory', badCaseCategory);
    put('stage', stage);
    put('grade', grade);
    put('skillFilePath', skillFilePath);
    put('skillVersionHash', skillVersionHash);
    return map;
  }
}

Map<String, int>? _readDimensionScores(Object? value) {
  if (value == null) {
    return null;
  }
  final raw = Map<String, dynamic>.from(value as Map);
  return raw.map((key, value) => MapEntry(key, (value as num).toInt()));
}

Uri qualityUri(String path, {Map<String, String>? queryParameters}) {
  return Uri.parse(
    '$kApiBaseUrl$path',
  ).replace(queryParameters: queryParameters);
}
