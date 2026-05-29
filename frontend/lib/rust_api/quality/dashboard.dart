import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core.dart';
import 'models.dart';
import 'stats.dart';

class QualityDashboardTargetStat {
  const QualityDashboardTargetStat({
    required this.scope,
    required this.targetType,
    required this.totalReviews,
    required this.passRatePercent,
    required this.avgOverallScore,
  });

  final String scope;
  final String targetType;
  final int totalReviews;
  final double passRatePercent;
  final double avgOverallScore;

  factory QualityDashboardTargetStat.fromJson(Map<String, dynamic> json) {
    return QualityDashboardTargetStat(
      scope: json['scope'] as String,
      targetType: json['targetType'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num).toDouble(),
      avgOverallScore: (json['avgOverallScore'] as num).toDouble(),
    );
  }
}

class QualityDashboardStagePassRateItem {
  const QualityDashboardStagePassRateItem({
    required this.scope,
    required this.targetType,
    required this.reviewDate,
    required this.totalReviews,
    required this.passRatePercent,
  });

  final String scope;
  final String targetType;
  final DateTime reviewDate;
  final int totalReviews;
  final double passRatePercent;

  factory QualityDashboardStagePassRateItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return QualityDashboardStagePassRateItem(
      scope: json['scope'] as String,
      targetType: json['targetType'] as String,
      reviewDate: DateTime.parse(json['reviewDate'] as String),
      totalReviews: (json['totalReviews'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num).toDouble(),
    );
  }
}

class QualityDashboardStageGradeItem {
  const QualityDashboardStageGradeItem({
    required this.scope,
    required this.stage,
    required this.gradeACount,
    required this.gradeBCount,
    required this.gradeCCount,
    required this.gradeDCount,
    required this.totalCount,
    required this.passRatePercent,
  });

  final String scope;
  final String stage;
  final int gradeACount;
  final int gradeBCount;
  final int gradeCCount;
  final int gradeDCount;
  final int totalCount;
  final double passRatePercent;

  factory QualityDashboardStageGradeItem.fromJson(Map<String, dynamic> json) {
    return QualityDashboardStageGradeItem(
      scope: json['scope'] as String,
      stage: json['stage'] as String,
      gradeACount: (json['gradeACount'] as num).toInt(),
      gradeBCount: (json['gradeBCount'] as num).toInt(),
      gradeCCount: (json['gradeCCount'] as num).toInt(),
      gradeDCount: (json['gradeDCount'] as num).toInt(),
      totalCount: (json['totalCount'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num).toDouble(),
    );
  }
}

class QualityDashboardScopeInsightItem {
  const QualityDashboardScopeInsightItem({
    required this.scope,
    required this.scopeLabel,
    required this.totalReviews,
    required this.badCaseCount,
    required this.passRatePercent,
  });

  final String scope;
  final String scopeLabel;
  final int totalReviews;
  final int badCaseCount;
  final double passRatePercent;

  factory QualityDashboardScopeInsightItem.fromJson(Map<String, dynamic> json) {
    return QualityDashboardScopeInsightItem(
      scope: json['scope'] as String,
      scopeLabel: json['scopeLabel'] as String,
      totalReviews: (json['totalReviews'] as num).toInt(),
      badCaseCount: (json['badCaseCount'] as num).toInt(),
      passRatePercent: (json['passRatePercent'] as num).toDouble(),
    );
  }
}

class QualityDashboardTokenEfficiencyItem {
  const QualityDashboardTokenEfficiencyItem({
    required this.scope,
    required this.targetType,
    required this.sampleCount,
    required this.avgPromptChars,
    required this.avgMemoryStyleChars,
    required this.avgMemoryDeliveryChars,
    required this.memoryAction,
  });

  final String scope;
  final String targetType;
  final int sampleCount;
  final double avgPromptChars;
  final double avgMemoryStyleChars;
  final double avgMemoryDeliveryChars;
  final String memoryAction;

  factory QualityDashboardTokenEfficiencyItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return QualityDashboardTokenEfficiencyItem(
      scope: json['scope'] as String,
      targetType: json['targetType'] as String,
      sampleCount: (json['sampleCount'] as num).toInt(),
      avgPromptChars: (json['avgPromptChars'] as num).toDouble(),
      avgMemoryStyleChars: (json['avgMemoryStyleChars'] as num).toDouble(),
      avgMemoryDeliveryChars: (json['avgMemoryDeliveryChars'] as num)
          .toDouble(),
      memoryAction: json['memoryAction'] as String,
    );
  }
}

class QualityDashboardResponse {
  const QualityDashboardResponse({
    required this.meta,
    required this.stats,
    required this.stagePassRate,
    required this.stageGradeDistribution,
    required this.scopeInsights,
    required this.tokenEfficiency,
    required this.badCaseStats,
  });

  final QualityDashboardMeta meta;
  final List<QualityDashboardTargetStat> stats;
  final List<QualityDashboardStagePassRateItem> stagePassRate;
  final List<QualityDashboardStageGradeItem> stageGradeDistribution;
  final List<QualityDashboardScopeInsightItem> scopeInsights;
  final List<QualityDashboardTokenEfficiencyItem> tokenEfficiency;
  final List<BadCaseStatItem> badCaseStats;

  factory QualityDashboardResponse.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = json[key] as List<dynamic>? ?? const <dynamic>[];
      return raw
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    return QualityDashboardResponse(
      meta: QualityDashboardMeta.fromJson(
        json['meta'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      stats: parseList('stats', QualityDashboardTargetStat.fromJson),
      stagePassRate: parseList(
        'stagePassRate',
        QualityDashboardStagePassRateItem.fromJson,
      ),
      stageGradeDistribution: parseList(
        'stageGradeDistribution',
        QualityDashboardStageGradeItem.fromJson,
      ),
      scopeInsights: parseList(
        'scopeInsights',
        QualityDashboardScopeInsightItem.fromJson,
      ),
      tokenEfficiency: parseList(
        'tokenEfficiency',
        QualityDashboardTokenEfficiencyItem.fromJson,
      ),
      badCaseStats: parseList('badCaseStats', BadCaseStatItem.fromJson),
    );
  }
}

class QualityDashboardMeta {
  const QualityDashboardMeta({
    required this.refreshedAt,
    required this.snapshotRowCount,
    required this.sourceReviewCount,
    required this.sourceUsageCount,
    required this.sourceMaxReviewCreatedAt,
    required this.sourceMaxUsageCreatedAt,
    required this.ageSeconds,
    required this.stale,
    required this.staleReason,
    required this.refreshMode,
  });

  final DateTime? refreshedAt;
  final int snapshotRowCount;
  final int sourceReviewCount;
  final int sourceUsageCount;
  final DateTime? sourceMaxReviewCreatedAt;
  final DateTime? sourceMaxUsageCreatedAt;
  final int? ageSeconds;
  final bool stale;
  final String? staleReason;
  final String refreshMode;

  factory QualityDashboardMeta.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        return null;
      }
      return DateTime.parse(value);
    }

    return QualityDashboardMeta(
      refreshedAt: parseDate('refreshedAt'),
      snapshotRowCount: (json['snapshotRowCount'] as num? ?? 0).toInt(),
      sourceReviewCount: (json['sourceReviewCount'] as num? ?? 0).toInt(),
      sourceUsageCount: (json['sourceUsageCount'] as num? ?? 0).toInt(),
      sourceMaxReviewCreatedAt: parseDate('sourceMaxReviewCreatedAt'),
      sourceMaxUsageCreatedAt: parseDate('sourceMaxUsageCreatedAt'),
      ageSeconds: (json['ageSeconds'] as num?)?.toInt(),
      stale: json['stale'] as bool? ?? true,
      staleReason: json['staleReason'] as String?,
      refreshMode:
          json['refreshMode'] as String? ??
          'materialized_view_concurrent_refresh',
    );
  }
}

class QualityDashboardRefreshResponse {
  const QualityDashboardRefreshResponse({
    required this.refreshedAt,
    required this.rowCount,
    required this.mode,
    required this.performed,
    required this.staleBeforeRefresh,
    required this.sourceReviewCount,
    required this.sourceUsageCount,
    required this.sourceMaxReviewCreatedAt,
    required this.sourceMaxUsageCreatedAt,
  });

  final DateTime refreshedAt;
  final int rowCount;
  final String mode;
  final bool performed;
  final bool staleBeforeRefresh;
  final int sourceReviewCount;
  final int sourceUsageCount;
  final DateTime? sourceMaxReviewCreatedAt;
  final DateTime? sourceMaxUsageCreatedAt;

  factory QualityDashboardRefreshResponse.fromJson(Map<String, dynamic> json) {
    return QualityDashboardRefreshResponse(
      refreshedAt: DateTime.parse(json['refreshedAt'] as String),
      rowCount: (json['rowCount'] as num).toInt(),
      mode: json['mode'] as String,
      performed: json['performed'] as bool? ?? true,
      staleBeforeRefresh: json['staleBeforeRefresh'] as bool? ?? true,
      sourceReviewCount: (json['sourceReviewCount'] as num? ?? 0).toInt(),
      sourceUsageCount: (json['sourceUsageCount'] as num? ?? 0).toInt(),
      sourceMaxReviewCreatedAt: json['sourceMaxReviewCreatedAt'] is String
          ? DateTime.parse(json['sourceMaxReviewCreatedAt'] as String)
          : null,
      sourceMaxUsageCreatedAt: json['sourceMaxUsageCreatedAt'] is String
          ? DateTime.parse(json['sourceMaxUsageCreatedAt'] as String)
          : null,
    );
  }
}

Future<QualityDashboardResponse> fetchQualityDashboard(
  String accessToken, {
  int? projectId,
  int? scriptId,
}) async {
  final query = <String, String>{};
  if (projectId != null) {
    query['projectId'] = '$projectId';
  }
  if (scriptId != null) {
    query['scriptId'] = '$scriptId';
  }
  final res = await http
      .get(
        qualityUri(
          '/api/v1/quality/dashboard',
          queryParameters: query.isEmpty ? null : query,
        ),
        headers: rustApiAuthHeaders(accessToken),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return QualityDashboardResponse.fromJson(map);
}

Future<QualityDashboardRefreshResponse> refreshQualityDashboardReadModel(
  String accessToken, {
  bool onlyIfStale = false,
}) async {
  final uri = qualityUri(
    '/api/v1/quality/dashboard',
    queryParameters: onlyIfStale ? const {'onlyIfStale': 'true'} : null,
  );
  final res = await http
      .post(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 60));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return QualityDashboardRefreshResponse.fromJson(map);
}
