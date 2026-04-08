part of 'index.dart';

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
    this.reviewerId,
    required this.isBadCase,
    this.badCaseCategory,
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
  final String? reviewerId;
  final bool isBadCase;
  final String? badCaseCategory;

  factory QualityReview.fromJson(Map<String, dynamic> json) {
    int? asInt(String key) => json[key] == null ? null : (json[key] as num).toInt();

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
      reviewerId: json['reviewerId'] as String?,
      isBadCase: json['isBadCase'] as bool? ?? false,
      badCaseCategory: json['badCaseCategory'] as String?,
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
    this.isBadCase,
    this.badCaseCategory,
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
  final bool? isBadCase;
  final String? badCaseCategory;

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
    put('isBadCase', isBadCase);
    put('badCaseCategory', badCaseCategory);
    return map;
  }
}

Uri _qualityUri(
  String path, {
  Map<String, String>? queryParameters,
}) {
  return Uri.parse('$kApiBaseUrl$path').replace(queryParameters: queryParameters);
}

Future<List<QualityReview>> fetchQualityReviews(
  String accessToken, {
  String? targetType,
  String? targetId,
  String? jobId,
  bool? isBadCase,
  int? limit,
  int? offset,
}) async {
  final query = <String, String>{};
  if (targetType != null && targetType.isNotEmpty) {
    query['targetType'] = targetType;
  }
  if (targetId != null && targetId.isNotEmpty) {
    query['targetId'] = targetId;
  }
  if (jobId != null && jobId.isNotEmpty) {
    query['jobId'] = jobId;
  }
  if (isBadCase != null) {
    query['isBadCase'] = isBadCase.toString();
  }
  if (limit != null) {
    query['limit'] = '$limit';
  }
  if (offset != null) {
    query['offset'] = '$offset';
  }

  final res = await http
      .get(
        _qualityUri(
          '/api/v1/quality/reviews',
          queryParameters: query.isEmpty ? null : query,
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => QualityReview.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<QualityReview> createQualityReview(
  String accessToken,
  CreateQualityReviewBody body,
) async {
  final res = await http
      .post(
        _qualityUri('/api/v1/quality/reviews'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return QualityReview.fromJson(map);
}

Future<QualityReview> fetchQualityReviewById(
  String accessToken,
  String reviewId,
) async {
  final res = await http
      .get(
        _qualityUri('/api/v1/quality/reviews/$reviewId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return QualityReview.fromJson(map);
}
