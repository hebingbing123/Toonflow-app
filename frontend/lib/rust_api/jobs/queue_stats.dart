import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Q2 方案 B：`GET /api/v1/jobs/queue/stats`（须 header **`X-Toonflow-Internal-Token`** = 服务端 **`TOONFLOW_INTERNAL_OPS_TOKEN`**）。
Future<JobQueueStatsV1> fetchJobQueueStatsV1({
  required String internalOpsToken,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/jobs/queue/stats');
  final res = await http
      .get(uri, headers: {'x-toonflow-internal-token': internalOpsToken.trim()})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobQueueStatsV1.fromJson(map);
}

class JobQueueStatsV1 {
  JobQueueStatsV1({
    required this.pending,
    required this.pendingClaimable,
    required this.running,
    required this.dead,
    required this.failedLast24h,
    required this.oldestClaimableQueuedAgeSecs,
    required this.pendingByKind,
  });

  final int pending;
  final int pendingClaimable;
  final int running;
  final int dead;
  final int failedLast24h;
  final int? oldestClaimableQueuedAgeSecs;
  final Map<String, dynamic> pendingByKind;

  factory JobQueueStatsV1.fromJson(Map<String, dynamic> json) {
    final rawKind = json['pending_by_kind'];
    final kindMap = rawKind is Map<String, dynamic>
        ? rawKind
        : <String, dynamic>{};
    return JobQueueStatsV1(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      pendingClaimable: (json['pending_claimable'] as num?)?.toInt() ?? 0,
      running: (json['running'] as num?)?.toInt() ?? 0,
      dead: (json['dead'] as num?)?.toInt() ?? 0,
      failedLast24h: (json['failed_last_24h'] as num?)?.toInt() ?? 0,
      oldestClaimableQueuedAgeSecs:
          (json['oldest_claimable_queued_age_secs'] as num?)?.toInt(),
      pendingByKind: kindMap,
    );
  }
}
