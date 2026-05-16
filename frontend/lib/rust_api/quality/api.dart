import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core.dart';
import 'index.dart';

/// Quality review REST queries and mutations.
Future<List<QualityReview>> fetchQualityReviews(
  String accessToken, {
  int? projectId,
  int? scriptId,
  String? targetType,
  String? targetId,
  String? jobId,
  String? source,
  bool? isBadCase,
  bool? memoryDeliveryPriorityApplied,
  String? stage,
  String? grade,
  String? suggestedAction,
  int? limit,
  int? offset,
}) async {
  final query = <String, String>{};
  if (projectId != null) {
    query['projectId'] = '$projectId';
  }
  if (scriptId != null) {
    query['scriptId'] = '$scriptId';
  }
  if (targetType != null && targetType.isNotEmpty) {
    query['targetType'] = targetType;
  }
  if (targetId != null && targetId.isNotEmpty) {
    query['targetId'] = targetId;
  }
  if (jobId != null && jobId.isNotEmpty) {
    query['jobId'] = jobId;
  }
  if (source != null && source.isNotEmpty) {
    query['source'] = source;
  }
  if (isBadCase != null) {
    query['isBadCase'] = isBadCase.toString();
  }
  if (memoryDeliveryPriorityApplied != null) {
    query['memoryDeliveryPriorityApplied'] = memoryDeliveryPriorityApplied
        .toString();
  }
  if (stage != null && stage.isNotEmpty) {
    query['stage'] = stage;
  }
  if (grade != null && grade.isNotEmpty) {
    query['grade'] = grade;
  }
  if (suggestedAction != null && suggestedAction.isNotEmpty) {
    query['suggestedAction'] = suggestedAction;
  }
  if (limit != null) {
    query['limit'] = '$limit';
  }
  if (offset != null) {
    query['offset'] = '$offset';
  }

  final res = await http
      .get(
        qualityUri(
          '/api/v1/quality/reviews',
          queryParameters: query.isEmpty ? null : query,
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
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
        qualityUri('/api/v1/quality/reviews'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return QualityReview.fromJson(map);
}

Future<QualityReview> fetchQualityReviewById(
  String accessToken,
  String reviewId,
) async {
  final res = await http
      .get(
        qualityUri('/api/v1/quality/reviews/$reviewId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return QualityReview.fromJson(map);
}
