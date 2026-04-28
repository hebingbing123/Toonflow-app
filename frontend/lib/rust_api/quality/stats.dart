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
