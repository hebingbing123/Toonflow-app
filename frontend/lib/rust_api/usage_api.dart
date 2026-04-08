part of 'index.dart';

/// `GET /api/v1/usage/summary` — see `usageSummaryV1`.
Future<UsageSummaryResponse> fetchUsageSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/usage/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UsageSummaryResponse.fromJson(map);
}
