import 'dart:convert';

/// Thrown when the Rust API returns a non-2xx or the body cannot be parsed.
class RustApiException implements Exception {
  RustApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'RustApiException($statusCode): $message';
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
      final waitText = details.retryAfterMs == null
          ? '请稍后重试'
          : formatRetryAfterMs(details.retryAfterMs!);
      return '配额或频率已用尽，$waitText。';
    }
    return details.message;
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
  });

  final int numericTaskId;
  final String id;
  final String ownerUserId;
  final String kind;
  final String status;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? result;
  final String? errorMessage;
  /// Structured worker diagnostics when **`status`** is **`failed`** (e.g. **`video.export`** codes + deep_links).
  final Map<String, dynamic>? errorDetails;
  final String? idempotencyKey;

  /// Worker label when `running` (`WORKER_ID` on server); mirrors OpenAPI `claimed_by`.
  final String? claimedBy;
  final String createdAt;
  final String updatedAt;

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
    );
  }
}
