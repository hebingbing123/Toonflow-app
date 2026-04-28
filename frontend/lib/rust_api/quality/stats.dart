import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core.dart';
import 'models.dart';

/// Quality review aggregate statistics and trend queries.
class QualityStatsRow {
  const QualityStatsRow({
    required this.targetType,
    required this.totalReviews,
    required this.passedCount,
    required this.failedCount,
    required this.badCaseCount,
    required this.passRatePercent,
    required this.avgOverallScore,
    required this.deliveryPriorityTotalReviews,
    required this.deliveryPriorityPassedCount,
    required this.deliveryPriorityBadCaseCount,
    required this.deliveryPriorityPassRatePercent,
    required this.nonDeliveryPriorityTotalReviews,
    required this.nonDeliveryPriorityPassedCount,
    required this.nonDeliveryPriorityBadCaseCount,
    required this.nonDeliveryPriorityPassRatePercent,
  });

  final String targetType;
  final int totalReviews;
  final int passedCount;
  final int failedCount;
  final int badCaseCount;
  final double passRatePercent;
  final double avgOverallScore;
  final int deliveryPriorityTotalReviews;
  final int deliveryPriorityPassedCount;
  final int deliveryPriorityBadCaseCount;
  final double deliveryPriorityPassRatePercent;
  final int nonDeliveryPriorityTotalReviews;
  final int nonDeliveryPriorityPassedCount;
  final int nonDeliveryPriorityBadCaseCount;
  final double nonDeliveryPriorityPassRatePercent;

  factory QualityStatsRow.fromJson(Map<String, dynamic> json) {
    return QualityStatsRow(
      targetType: json['targetType'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      passedCount: (json['passedCount'] as num).toInt(),
      failedCount: (json['failedCount'] as num).toInt(),
      badCaseCount: (json['badCaseCount'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num).toDouble(),
      avgOverallScore: (json['avgOverallScore'] as num).toDouble(),
      deliveryPriorityTotalReviews:
          (json['deliveryPriorityTotalReviews'] as num?)?.toInt() ?? 0,
      deliveryPriorityPassedCount:
          (json['deliveryPriorityPassedCount'] as num?)?.toInt() ?? 0,
      deliveryPriorityBadCaseCount:
          (json['deliveryPriorityBadCaseCount'] as num?)?.toInt() ?? 0,
      deliveryPriorityPassRatePercent:
          (json['deliveryPriorityPassRatePercent'] as num?)?.toDouble() ?? 0,
      nonDeliveryPriorityTotalReviews:
          (json['nonDeliveryPriorityTotalReviews'] as num?)?.toInt() ?? 0,
      nonDeliveryPriorityPassedCount:
          (json['nonDeliveryPriorityPassedCount'] as num?)?.toInt() ?? 0,
      nonDeliveryPriorityBadCaseCount:
          (json['nonDeliveryPriorityBadCaseCount'] as num?)?.toInt() ?? 0,
      nonDeliveryPriorityPassRatePercent:
          (json['nonDeliveryPriorityPassRatePercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StagePassRateRow {
  const StagePassRateRow({
    required this.targetType,
    required this.reviewDate,
    required this.totalReviews,
    required this.passedCount,
    required this.badCaseCount,
    this.passRatePercent,
    this.avgScore,
    required this.deliveryPriorityTotalReviews,
    required this.deliveryPriorityPassedCount,
    required this.deliveryPriorityBadCaseCount,
    required this.deliveryPriorityPassRatePercent,
    required this.nonDeliveryPriorityTotalReviews,
    required this.nonDeliveryPriorityPassedCount,
    required this.nonDeliveryPriorityBadCaseCount,
    required this.nonDeliveryPriorityPassRatePercent,
  });

  final String targetType;
  final String reviewDate;
  final int totalReviews;
  final int passedCount;
  final int badCaseCount;
  final double? passRatePercent;
  final double? avgScore;
  final int deliveryPriorityTotalReviews;
  final int deliveryPriorityPassedCount;
  final int deliveryPriorityBadCaseCount;
  final double deliveryPriorityPassRatePercent;
  final int nonDeliveryPriorityTotalReviews;
  final int nonDeliveryPriorityPassedCount;
  final int nonDeliveryPriorityBadCaseCount;
  final double nonDeliveryPriorityPassRatePercent;

  factory StagePassRateRow.fromJson(Map<String, dynamic> json) {
    return StagePassRateRow(
      targetType: json['targetType'] as String,
      reviewDate: json['reviewDate'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      passedCount: (json['passedCount'] as num).toInt(),
      badCaseCount: (json['badCaseCount'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num?)?.toDouble(),
      avgScore: (json['avgScore'] as num?)?.toDouble(),
      deliveryPriorityTotalReviews:
          (json['deliveryPriorityTotalReviews'] as num?)?.toInt() ?? 0,
      deliveryPriorityPassedCount:
          (json['deliveryPriorityPassedCount'] as num?)?.toInt() ?? 0,
      deliveryPriorityBadCaseCount:
          (json['deliveryPriorityBadCaseCount'] as num?)?.toInt() ?? 0,
      deliveryPriorityPassRatePercent:
          (json['deliveryPriorityPassRatePercent'] as num?)?.toDouble() ?? 0,
      nonDeliveryPriorityTotalReviews:
          (json['nonDeliveryPriorityTotalReviews'] as num?)?.toInt() ?? 0,
      nonDeliveryPriorityPassedCount:
          (json['nonDeliveryPriorityPassedCount'] as num?)?.toInt() ?? 0,
      nonDeliveryPriorityBadCaseCount:
          (json['nonDeliveryPriorityBadCaseCount'] as num?)?.toInt() ?? 0,
      nonDeliveryPriorityPassRatePercent:
          (json['nonDeliveryPriorityPassRatePercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class QualityTokenEfficiencyRow {
  const QualityTokenEfficiencyRow({
    required this.targetType,
    required this.totalReviews,
    required this.linkedLlmReviewCount,
    required this.avgOverallScore,
    required this.avgPromptChars,
    required this.avgMemoryDeliveryChars,
    required this.avgMemoryVisualChars,
    required this.avgMemoryScriptScopeChars,
    required this.avgMemoryProjectScopeChars,
    required this.avgMemoryMixedScopeChars,
    required this.avgLinkedTotalTokens,
    required this.avgPromptCharsPerScorePoint,
    required this.avgLinkedTokensPerScorePoint,
    required this.deliveryPriorityAvgPromptCharsPerScorePoint,
    required this.deliveryPriorityAvgLinkedTokensPerScorePoint,
    required this.nonDeliveryPriorityAvgPromptCharsPerScorePoint,
    required this.nonDeliveryPriorityAvgLinkedTokensPerScorePoint,
  });

  final String targetType;
  final int totalReviews;
  final int linkedLlmReviewCount;
  final double avgOverallScore;
  final double avgPromptChars;
  final double avgMemoryDeliveryChars;
  final double avgMemoryVisualChars;
  final double avgMemoryScriptScopeChars;
  final double avgMemoryProjectScopeChars;
  final double avgMemoryMixedScopeChars;
  final double avgLinkedTotalTokens;
  final double avgPromptCharsPerScorePoint;
  final double avgLinkedTokensPerScorePoint;
  final double deliveryPriorityAvgPromptCharsPerScorePoint;
  final double deliveryPriorityAvgLinkedTokensPerScorePoint;
  final double nonDeliveryPriorityAvgPromptCharsPerScorePoint;
  final double nonDeliveryPriorityAvgLinkedTokensPerScorePoint;

  factory QualityTokenEfficiencyRow.fromJson(Map<String, dynamic> json) {
    return QualityTokenEfficiencyRow(
      targetType: json['targetType'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      linkedLlmReviewCount:
          (json['linkedLlmReviewCount'] as num?)?.toInt() ?? 0,
      avgOverallScore: (json['avgOverallScore'] as num?)?.toDouble() ?? 0,
      avgPromptChars: (json['avgPromptChars'] as num?)?.toDouble() ?? 0,
      avgMemoryDeliveryChars:
          (json['avgMemoryDeliveryChars'] as num?)?.toDouble() ?? 0,
      avgMemoryVisualChars:
          (json['avgMemoryVisualChars'] as num?)?.toDouble() ?? 0,
      avgMemoryScriptScopeChars:
          (json['avgMemoryScriptScopeChars'] as num?)?.toDouble() ?? 0,
      avgMemoryProjectScopeChars:
          (json['avgMemoryProjectScopeChars'] as num?)?.toDouble() ?? 0,
      avgMemoryMixedScopeChars:
          (json['avgMemoryMixedScopeChars'] as num?)?.toDouble() ?? 0,
      avgLinkedTotalTokens:
          (json['avgLinkedTotalTokens'] as num?)?.toDouble() ?? 0,
      avgPromptCharsPerScorePoint:
          (json['avgPromptCharsPerScorePoint'] as num?)?.toDouble() ?? 0,
      avgLinkedTokensPerScorePoint:
          (json['avgLinkedTokensPerScorePoint'] as num?)?.toDouble() ?? 0,
      deliveryPriorityAvgPromptCharsPerScorePoint:
          (json['deliveryPriorityAvgPromptCharsPerScorePoint'] as num?)
              ?.toDouble() ??
          0,
      deliveryPriorityAvgLinkedTokensPerScorePoint:
          (json['deliveryPriorityAvgLinkedTokensPerScorePoint'] as num?)
              ?.toDouble() ??
          0,
      nonDeliveryPriorityAvgPromptCharsPerScorePoint:
          (json['nonDeliveryPriorityAvgPromptCharsPerScorePoint'] as num?)
              ?.toDouble() ??
          0,
      nonDeliveryPriorityAvgLinkedTokensPerScorePoint:
          (json['nonDeliveryPriorityAvgLinkedTokensPerScorePoint'] as num?)
              ?.toDouble() ??
          0,
    );
  }
}

class QualityTokenEfficiencySampleRow {
  const QualityTokenEfficiencySampleRow({
    required this.reviewId,
    required this.createdAt,
    required this.projectId,
    required this.scriptId,
    required this.jobId,
    required this.targetType,
    required this.targetId,
    required this.source,
    required this.overallScore,
    required this.passed,
    required this.isBadCase,
    required this.memoryDeliveryPriorityApplied,
    required this.promptChars,
    required this.linkedTotalTokens,
    required this.memoryDeliveryChars,
    required this.memoryVisualChars,
    required this.memoryScriptScopeChars,
    required this.memoryProjectScopeChars,
    required this.memoryMixedScopeChars,
    required this.promptCharsPerScorePoint,
    required this.linkedTokensPerScorePoint,
    required this.dominantMemoryScope,
    required this.recommendedAction,
    required this.recommendedActionReason,
  });

  final String reviewId;
  final String createdAt;
  final int? projectId;
  final int? scriptId;
  final String? jobId;
  final String targetType;
  final String? targetId;
  final String source;
  final int? overallScore;
  final bool? passed;
  final bool isBadCase;
  final bool? memoryDeliveryPriorityApplied;
  final double promptChars;
  final double linkedTotalTokens;
  final double memoryDeliveryChars;
  final double memoryVisualChars;
  final double memoryScriptScopeChars;
  final double memoryProjectScopeChars;
  final double memoryMixedScopeChars;
  final double promptCharsPerScorePoint;
  final double linkedTokensPerScorePoint;
  final String dominantMemoryScope;
  final String recommendedAction;
  final String recommendedActionReason;

  factory QualityTokenEfficiencySampleRow.fromJson(Map<String, dynamic> json) {
    return QualityTokenEfficiencySampleRow(
      reviewId: json['reviewId'] as String,
      createdAt: json['createdAt'] as String,
      projectId: (json['projectId'] as num?)?.toInt(),
      scriptId: (json['scriptId'] as num?)?.toInt(),
      jobId: json['jobId'] as String?,
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String?,
      source: json['source'] as String,
      overallScore: (json['overallScore'] as num?)?.toInt(),
      passed: json['passed'] as bool?,
      isBadCase: json['isBadCase'] as bool? ?? false,
      memoryDeliveryPriorityApplied:
          json['memoryDeliveryPriorityApplied'] as bool?,
      promptChars: (json['promptChars'] as num?)?.toDouble() ?? 0,
      linkedTotalTokens: (json['linkedTotalTokens'] as num?)?.toDouble() ?? 0,
      memoryDeliveryChars:
          (json['memoryDeliveryChars'] as num?)?.toDouble() ?? 0,
      memoryVisualChars: (json['memoryVisualChars'] as num?)?.toDouble() ?? 0,
      memoryScriptScopeChars:
          (json['memoryScriptScopeChars'] as num?)?.toDouble() ?? 0,
      memoryProjectScopeChars:
          (json['memoryProjectScopeChars'] as num?)?.toDouble() ?? 0,
      memoryMixedScopeChars:
          (json['memoryMixedScopeChars'] as num?)?.toDouble() ?? 0,
      promptCharsPerScorePoint:
          (json['promptCharsPerScorePoint'] as num?)?.toDouble() ?? 0,
      linkedTokensPerScorePoint:
          (json['linkedTokensPerScorePoint'] as num?)?.toDouble() ?? 0,
      dominantMemoryScope: json['dominantMemoryScope'] as String? ?? 'none',
      recommendedAction: json['recommendedAction'] as String? ?? 'tighten_core_prompt',
      recommendedActionReason:
          json['recommendedActionReason'] as String? ?? '',
    );
  }
}

Future<List<QualityStatsRow>> fetchQualityStats(String accessToken) async {
  final res = await http
      .get(
        qualityUri('/api/v1/quality/stats'),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => QualityStatsRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<StagePassRateRow>> fetchQualityStagePassRate(
  String accessToken,
) async {
  final res = await http
      .get(
        qualityUri('/api/v1/quality/stage-pass-rate'),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => StagePassRateRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<QualityTokenEfficiencyRow>> fetchQualityTokenEfficiency(
  String accessToken,
) async {
  final res = await http
      .get(
        qualityUri('/api/v1/quality/token-efficiency'),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => QualityTokenEfficiencyRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<QualityTokenEfficiencySampleRow>>
fetchQualityTokenEfficiencySamples(
  String accessToken, {
  String? targetType,
  int limit = 8,
}) async {
  final query = <String, String>{
    'limit': limit.toString(),
    if (targetType != null && targetType.trim().isNotEmpty)
      'targetType': targetType.trim(),
  };
  final res = await http
      .get(
        qualityUri(
          '/api/v1/quality/token-efficiency/samples',
          queryParameters: query,
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map(
        (e) =>
            QualityTokenEfficiencySampleRow.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}
