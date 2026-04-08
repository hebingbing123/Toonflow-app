part of 'index.dart';

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
