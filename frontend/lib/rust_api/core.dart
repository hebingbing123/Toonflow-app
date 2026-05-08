import 'dart:convert';

import 'package:http/http.dart' as http;

/// Parses **`Retry-After`** as delay seconds (integer form per RFC 9110).
/// HTTP-date form is not parsed here (returns null).
int? parseRetryAfterHeaderSeconds(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

/// Thrown when the Rust API returns a non-2xx or the body cannot be parsed.
class RustApiException implements Exception {
  RustApiException(this.message, {this.statusCode, this.retryAfterMsHint});

  final String message;
  final int? statusCode;

  /// Milliseconds suggested by **`Retry-After`** header on **429** (when JSON body omits `retry_after_ms`).
  final int? retryAfterMsHint;

  factory RustApiException.fromHttpResponse(http.Response res) {
    final hint = res.statusCode == 429
        ? () {
            final sec = parseRetryAfterHeaderSeconds(
              res.headers['retry-after'],
            );
            if (sec == null || sec < 0) return null;
            return sec * 1000;
          }()
        : null;
    return RustApiException(
      res.body,
      statusCode: res.statusCode,
      retryAfterMsHint: hint,
    );
  }

  @override
  String toString() => 'RustApiException($statusCode): $message';
}

/// Treat **2xx** as success; otherwise throws [RustApiException.fromHttpResponse].
void ensureHttpSuccess(http.Response res) {
  if (res.statusCode >= 200 && res.statusCode < 300) {
    return;
  }
  throw RustApiException.fromHttpResponse(res);
}

/// Success only when [res.statusCode] equals [expected] (e.g. **201** create, **204** delete).
void ensureHttpStatus(http.Response res, int expected) {
  if (res.statusCode == expected) {
    return;
  }
  throw RustApiException.fromHttpResponse(res);
}

class RustApiErrorDetails {
  const RustApiErrorDetails({
    required this.code,
    required this.message,
    this.retryAfterMs,
  });

  final String code;
  final String message;
  final int? retryAfterMs;

  static RustApiErrorDetails? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        (!trimmed.startsWith('{') && !trimmed.startsWith('['))) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final code = decoded['code'];
      final message = decoded['message'];
      if (code is! String || message is! String) {
        return null;
      }
      final retryAfterMs = switch (decoded['retry_after_ms']) {
        final num value => value.toInt(),
        _ => null,
      };
      return RustApiErrorDetails(
        code: code,
        message: message,
        retryAfterMs: retryAfterMs,
      );
    } catch (_) {
      return null;
    }
  }
}

class ErrorBody {
  const ErrorBody({
    required this.code,
    required this.message,
    this.retryAfterMs,
  });

  final String code;
  final String message;
  final int? retryAfterMs;

  factory ErrorBody.fromJson(Map<String, dynamic> json) {
    return ErrorBody(
      code: json['code'] as String,
      message: json['message'] as String,
      retryAfterMs: switch (json['retry_after_ms']) {
        final num value => value.toInt(),
        _ => null,
      },
    );
  }
}

String formatRetryAfterMs(int retryAfterMs) {
  if (retryAfterMs <= 0) {
    return '稍后重试';
  }
  final totalSeconds = (retryAfterMs / 1000).ceil();
  if (totalSeconds < 60) {
    return '$totalSeconds 秒后重试';
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes < 60) {
    return seconds == 0 ? '$minutes 分钟后重试' : '$minutes 分 $seconds 秒后重试';
  }
  final hours = minutes ~/ 60;
  final remainMinutes = minutes % 60;
  return remainMinutes == 0 ? '$hours 小时后重试' : '$hours 小时 $remainMinutes 分钟后重试';
}

String formatRustApiException(RustApiException error) {
  final details = RustApiErrorDetails.tryParse(error.message);
  if (details != null) {
    if (error.statusCode == 429 || details.code == 'quota_exceeded') {
      final waitMs = details.retryAfterMs ?? error.retryAfterMsHint;
      final waitText = waitMs == null ? '请稍后重试' : formatRetryAfterMs(waitMs);
      return '配额或频率已用尽，$waitText。';
    }
    return details.message;
  }
  if (error.statusCode == 429) {
    final waitMs = error.retryAfterMsHint;
    final waitText = waitMs == null ? '请稍后重试' : formatRetryAfterMs(waitMs);
    return '请求过于频繁，$waitText。';
  }
  if (error.statusCode == 404) {
    return '未找到对应记录。';
  }
  return error.toString();
}

class JobRow {
  const JobRow({
    required this.numericTaskId,
    required this.id,
    required this.ownerUserId,
    required this.kind,
    required this.status,
    required this.payload,
    this.result,
    this.errorMessage,
    this.errorDetails,
    this.idempotencyKey,
    this.claimedBy,
    required this.createdAt,
    required this.updatedAt,
    this.jobSubKind,
    this.productionPhase,
  });

  final int numericTaskId;
  final String id;
  final String ownerUserId;
  final String kind;
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final String? errorMessage;

  /// Structured worker diagnostics: **`failed`** jobs (e.g. export codes + deep_links), or **`succeeded`**
  /// jobs where provider output did not fully write back (e.g. `production.video_file_writeback` / J4).
  final Map<String, dynamic>? errorDetails;
  final String? idempotencyKey;

  /// Worker label when `running` (`WORKER_ID` on server); mirrors OpenAPI `claimed_by`.
  final String? claimedBy;
  final String createdAt;
  final String updatedAt;

  /// Worker / product sub-type (e.g. `voiceover.tts`); mirrors API `job_sub_kind`.
  final String? jobSubKind;

  /// Production pipeline phase label (e.g. `post_production.narration`).
  final String? productionPhase;

  factory JobRow.fromJson(Map<String, dynamic> json) {
    return JobRow(
      numericTaskId: (json['numeric_task_id'] as num).toInt(),
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      result: json['result'] == null
          ? null
          : Map<String, dynamic>.from(json['result'] as Map),
      errorMessage: json['error_message'] as String?,
      errorDetails: json['error_details'] == null
          ? null
          : Map<String, dynamic>.from(json['error_details'] as Map),
      idempotencyKey: json['idempotency_key'] as String?,
      claimedBy: json['claimed_by'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      jobSubKind: json['job_sub_kind'] as String?,
      productionPhase: json['production_phase'] as String?,
    );
  }
}
