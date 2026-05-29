import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import '../shared_kernel/index.dart';

enum UsageSummaryScope { user, workspace }

/// Usage summary endpoints tied to the authenticated account.
/// `GET /api/v1/usage/summary` — see `usageSummaryV1`.
Future<UsageSummaryResponse> fetchUsageSummary(
  String accessToken, {
  UsageSummaryScope scope = UsageSummaryScope.user,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/usage/summary').replace(
    queryParameters: scope == UsageSummaryScope.workspace
        ? <String, String>{'scope': 'workspace'}
        : null,
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UsageSummaryResponse.fromJson(map);
}
