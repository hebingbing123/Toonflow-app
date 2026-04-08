part of 'index.dart';

class QualityStatsRow {
  const QualityStatsRow({
    required this.targetType,
    required this.totalReviews,
    required this.passedCount,
    required this.failedCount,
    required this.badCaseCount,
    required this.passRatePercent,
    required this.avgOverallScore,
  });

  final String targetType;
  final int totalReviews;
  final int passedCount;
  final int failedCount;
  final int badCaseCount;
  final double passRatePercent;
  final double avgOverallScore;

  factory QualityStatsRow.fromJson(Map<String, dynamic> json) {
    return QualityStatsRow(
      targetType: json['targetType'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      passedCount: (json['passedCount'] as num).toInt(),
      failedCount: (json['failedCount'] as num).toInt(),
      badCaseCount: (json['badCaseCount'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num).toDouble(),
      avgOverallScore: (json['avgOverallScore'] as num).toDouble(),
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
  });

  final String targetType;
  final String reviewDate;
  final int totalReviews;
  final int passedCount;
  final int badCaseCount;
  final double? passRatePercent;
  final double? avgScore;

  factory StagePassRateRow.fromJson(Map<String, dynamic> json) {
    return StagePassRateRow(
      targetType: json['targetType'] as String,
      reviewDate: json['reviewDate'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      passedCount: (json['passedCount'] as num).toInt(),
      badCaseCount: (json['badCaseCount'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num?)?.toDouble(),
      avgScore: (json['avgScore'] as num?)?.toDouble(),
    );
  }
}

Future<List<QualityStatsRow>> fetchQualityStats(String accessToken) async {
  final res = await http
      .get(
        _qualityUri('/api/v1/quality/stats'),
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
        _qualityUri('/api/v1/quality/stage-pass-rate'),
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
