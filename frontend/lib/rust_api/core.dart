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

/// Runs [run] and returns its result; if it throws [RustApiException], returns [fallback] instead.
/// Other errors are not caught.
Future<T> fallbackOnRustApiException<T>(
  Future<T> Function() run,
  T fallback,
) async {
  try {
    return await run();
  } on RustApiException {
    return fallback;
  }
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

/// One storyboard blocked by **`enforce_storyboards_ready_for_generation`** (HTTP 409).
class StoryboardGenerationBlocked {
  const StoryboardGenerationBlocked({
    required this.storyboardNumericId,
    required this.blockingReasons,
  });

  final int storyboardNumericId;
  final List<String> blockingReasons;

  static StoryboardGenerationBlocked? tryParseJson(Map<String, dynamic> json) {
    final id = json['storyboardNumericId'] ?? json['storyboard_numeric_id'];
    if (id is! num) {
      return null;
    }
    final rawReasons =
        json['blockingReasons'] as List<dynamic>? ??
        json['blocking_reasons'] as List<dynamic>? ??
        const <dynamic>[];
    final reasons = rawReasons
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    return StoryboardGenerationBlocked(
      storyboardNumericId: id.toInt(),
      blockingReasons: reasons,
    );
  }
}

class RustApiErrorDetails {
  const RustApiErrorDetails({
    required this.code,
    required this.message,
    this.retryAfterMs,
    this.details,
  });

  final String code;
  final String message;
  final int? retryAfterMs;
  final Map<String, dynamic>? details;

  List<StoryboardGenerationBlocked> get blockedStoryboards {
    final raw = details?['blockedStoryboards'] ?? details?['blocked_storyboards'];
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((e) => StoryboardGenerationBlocked.tryParseJson(
              Map<String, dynamic>.from(e),
            ))
        .whereType<StoryboardGenerationBlocked>()
        .toList(growable: false);
  }

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
      final detailsRaw = decoded['details'];
      return RustApiErrorDetails(
        code: code,
        message: message,
        retryAfterMs: retryAfterMs,
        details: detailsRaw is Map<String, dynamic>
            ? detailsRaw
            : detailsRaw is Map
            ? Map<String, dynamic>.from(detailsRaw)
            : null,
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
