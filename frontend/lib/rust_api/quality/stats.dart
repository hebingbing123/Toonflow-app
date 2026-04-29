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

class QualityScopeInsightRow {
  const QualityScopeInsightRow({
    required this.scopeLabel,
    required this.projectId,
    required this.scriptId,
    required this.totalReviews,
    required this.autoReviews,
    required this.passedCount,
    required this.badCaseCount,
    required this.passRatePercent,
    required this.avgOverallScore,
    required this.dialogueRiskCount,
    required this.visualRiskCount,
    required this.avgPromptChars,
    required this.avgMemoryChars,
    required this.avgMemoryDeliveryChars,
    required this.deliveryPriorityHitRatePercent,
    required this.memoryRemovedChars,
    required this.memoryRemovedRows,
  });

  final String scopeLabel;
  final int? projectId;
  final int? scriptId;
  final int totalReviews;
  final int autoReviews;
  final int passedCount;
  final int badCaseCount;
  final double passRatePercent;
  final double avgOverallScore;
  final int dialogueRiskCount;
  final int visualRiskCount;
  final double avgPromptChars;
  final double avgMemoryChars;
  final double avgMemoryDeliveryChars;
  final double deliveryPriorityHitRatePercent;
  final int memoryRemovedChars;
  final int memoryRemovedRows;

  factory QualityScopeInsightRow.fromJson(Map<String, dynamic> json) {
    return QualityScopeInsightRow(
      scopeLabel: json['scopeLabel'] as String,
      projectId: (json['projectId'] as num?)?.toInt(),
      scriptId: (json['scriptId'] as num?)?.toInt(),
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      autoReviews: (json['autoReviews'] as num?)?.toInt() ?? 0,
      passedCount: (json['passedCount'] as num?)?.toInt() ?? 0,
      badCaseCount: (json['badCaseCount'] as num?)?.toInt() ?? 0,
      passRatePercent: (json['passRatePercent'] as num?)?.toDouble() ?? 0,
      avgOverallScore: (json['avgOverallScore'] as num?)?.toDouble() ?? 0,
      dialogueRiskCount: (json['dialogueRiskCount'] as num?)?.toInt() ?? 0,
      visualRiskCount: (json['visualRiskCount'] as num?)?.toInt() ?? 0,
      avgPromptChars: (json['avgPromptChars'] as num?)?.toDouble() ?? 0,
      avgMemoryChars: (json['avgMemoryChars'] as num?)?.toDouble() ?? 0,
      avgMemoryDeliveryChars:
          (json['avgMemoryDeliveryChars'] as num?)?.toDouble() ?? 0,
      deliveryPriorityHitRatePercent:
          (json['deliveryPriorityHitRatePercent'] as num?)?.toDouble() ?? 0,
      memoryRemovedChars: (json['memoryRemovedChars'] as num?)?.toInt() ?? 0,
      memoryRemovedRows: (json['memoryRemovedRows'] as num?)?.toInt() ?? 0,
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
    required this.sampleCount,
    required this.avgPromptChars,
    required this.avgNonMemoryPromptChars,
    required this.avgMemoryStyleChars,
    required this.avgMemoryVisualChars,
    required this.avgMemoryDeliveryChars,
    required this.avgMemorySharePercent,
    required this.avgDeliveryMemorySharePercent,
    required this.deliveryPriorityHitRatePercent,
  });

  final String targetType;
  final int sampleCount;
  final double avgPromptChars;
  final double avgNonMemoryPromptChars;
  final double avgMemoryStyleChars;
  final double avgMemoryVisualChars;
  final double avgMemoryDeliveryChars;
  final double avgMemorySharePercent;
  final double avgDeliveryMemorySharePercent;
  final double deliveryPriorityHitRatePercent;

  factory QualityTokenEfficiencyRow.fromJson(Map<String, dynamic> json) {
    return QualityTokenEfficiencyRow(
      targetType: json['targetType'] as String,
      sampleCount: (json['sampleCount'] as num).toInt(),
      avgPromptChars: (json['avgPromptChars'] as num?)?.toDouble() ?? 0,
      avgNonMemoryPromptChars:
          (json['avgNonMemoryPromptChars'] as num?)?.toDouble() ?? 0,
      avgMemoryStyleChars:
          (json['avgMemoryStyleChars'] as num?)?.toDouble() ?? 0,
      avgMemoryVisualChars:
          (json['avgMemoryVisualChars'] as num?)?.toDouble() ?? 0,
      avgMemoryDeliveryChars:
          (json['avgMemoryDeliveryChars'] as num?)?.toDouble() ?? 0,
      avgMemorySharePercent:
          (json['avgMemorySharePercent'] as num?)?.toDouble() ?? 0,
      avgDeliveryMemorySharePercent:
          (json['avgDeliveryMemorySharePercent'] as num?)?.toDouble() ?? 0,
      deliveryPriorityHitRatePercent:
          (json['deliveryPriorityHitRatePercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class QualityTokenEfficiencySampleRow {
  const QualityTokenEfficiencySampleRow({
    required this.createdAt,
    required this.targetType,
    required this.promptChars,
    required this.nonMemoryPromptChars,
    required this.memoryStyleChars,
    required this.memoryVisualChars,
    required this.memoryDeliveryChars,
    required this.memorySharePercent,
    required this.deliveryMemorySharePercent,
    required this.memoryDeliveryPriorityApplied,
  });

  final String createdAt;
  final String targetType;
  final int promptChars;
  final int nonMemoryPromptChars;
  final int memoryStyleChars;
  final int memoryVisualChars;
  final int memoryDeliveryChars;
  final double memorySharePercent;
  final double deliveryMemorySharePercent;
  final bool memoryDeliveryPriorityApplied;

  factory QualityTokenEfficiencySampleRow.fromJson(Map<String, dynamic> json) {
    return QualityTokenEfficiencySampleRow(
      createdAt: json['createdAt'] as String,
      targetType: json['targetType'] as String,
      promptChars: (json['promptChars'] as num?)?.toInt() ?? 0,
      nonMemoryPromptChars:
          (json['nonMemoryPromptChars'] as num?)?.toInt() ?? 0,
      memoryStyleChars: (json['memoryStyleChars'] as num?)?.toInt() ?? 0,
      memoryVisualChars: (json['memoryVisualChars'] as num?)?.toInt() ?? 0,
      memoryDeliveryChars: (json['memoryDeliveryChars'] as num?)?.toInt() ?? 0,
      memorySharePercent: (json['memorySharePercent'] as num?)?.toDouble() ?? 0,
      deliveryMemorySharePercent:
          (json['deliveryMemorySharePercent'] as num?)?.toDouble() ?? 0,
      memoryDeliveryPriorityApplied:
          json['memoryDeliveryPriorityApplied'] == true,
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

Future<List<QualityScopeInsightRow>> fetchQualityScopeInsights(
  String accessToken, {
  int? projectId,
  int? scriptId,
  int? limit,
}) async {
  final query = <String, String>{};
  if (projectId != null) query['projectId'] = '$projectId';
  if (scriptId != null) query['scriptId'] = '$scriptId';
  if (limit != null) query['limit'] = '$limit';
  final res = await http
      .get(
        qualityUri(
          '/api/v1/quality/scope-insights',
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
      .map((e) => QualityScopeInsightRow.fromJson(e as Map<String, dynamic>))
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
  int? limit,
  String? targetType,
  bool? memoryDeliveryPriorityApplied,
}) async {
  final query = <String, String>{};
  if (limit != null) query['limit'] = '$limit';
  if (targetType != null && targetType.isNotEmpty) {
    query['targetType'] = targetType;
  }
  if (memoryDeliveryPriorityApplied != null) {
    query['memoryDeliveryPriorityApplied'] = memoryDeliveryPriorityApplied
        .toString();
  }
  final res = await http
      .get(
        qualityUri(
          '/api/v1/quality/token-efficiency/samples',
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
      .map(
        (e) =>
            QualityTokenEfficiencySampleRow.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}
