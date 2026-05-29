import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../l10n/app_localizations.dart';
import '../../config.dart';
import '../core.dart';

/// Search result type enumeration
enum ResultType {
  project,
  script,
  asset,
  novel,
  novelEvent;

  /// API / JSON wire value (`result_type` query repeats or body).
  String get wireName {
    switch (this) {
      case ResultType.novelEvent:
        return 'novel_event';
      default:
        return name;
    }
  }

  String toJson() => wireName;

  static ResultType fromJson(String value) {
    switch (value) {
      case 'novel_event':
        return ResultType.novelEvent;
      default:
        return ResultType.values.firstWhere(
          (e) => e.name == value,
          orElse: () => throw ArgumentError('Invalid ResultType: $value'),
        );
    }
  }
}

/// Single search result item
class SearchResult {
  const SearchResult({
    required this.id,
    required this.resultType,
    required this.title,
    required this.snippet,
    required this.rank,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  final String id;
  final ResultType resultType;
  final String title;
  final String snippet; // Contains <mark> tags for highlighting
  final double rank;
  final String createdAt;
  final String updatedAt;
  final Map<String, dynamic>? metadata;

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'] as String,
      resultType: ResultType.fromJson(json['result_type'] as String),
      title: json['title'] as String,
      snippet: json['snippet'] as String,
      rank: (json['rank'] as num).toDouble(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'result_type': resultType.toJson(),
      'title': title,
      'snippet': snippet,
      'rank': rank,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Search response containing results and pagination info
class SearchResponse {
  const SearchResponse({
    required this.results,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<SearchResult> results;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>;
    return SearchResponse(
      results: resultsList
          .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'results': results.map((e) => e.toJson()).toList(),
      'total': total,
      'page': page,
      'page_size': pageSize,
      'has_more': hasMore,
    };
  }
}

/// Search history entry
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.query,
    required this.resultCount,
    required this.searchedAt,
  });

  final String id;
  final String query;
  final int resultCount;
  final String searchedAt;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      query: json['query'] as String,
      resultCount: (json['result_count'] as num).toInt(),
      searchedAt: json['searched_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query': query,
      'result_count': resultCount,
      'searched_at': searchedAt,
    };
  }
}

/// Search history response
class HistoryResponse {
  const HistoryResponse({required this.history});

  final List<HistoryEntry> history;

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final historyList = json['history'] as List<dynamic>;
    return HistoryResponse(
      history: historyList
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'history': history.map((e) => e.toJson()).toList(),
    };
  }
}

/// `GET /api/v1/search` — Execute global search across projects, scripts, and assets.
///
/// [query]: Search keyword (required, 2-200 characters)
/// [resultTypes]: Optional filter by result types (project, script, asset)
/// [page]: Page number (default 1)
/// [pageSize]: Results per page (default 20, max 100)
/// [timeFrom]: Optional time range start filter
/// [timeTo]: Optional time range end filter
/// [cancellationToken]: Optional token to cancel the request
///
/// Returns [SearchResponse] with results and pagination info.
/// Throws [RustApiException] on error (400/403/500).
Future<SearchResponse> search(
  String accessToken, {
  required AppLocalizations l10n,
  required String query,
  List<ResultType>? resultTypes,
  int? page,
  int? pageSize,
  DateTime? timeFrom,
  DateTime? timeTo,
  CancellationToken? cancellationToken,
}) async {
  // Validate query length
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty || trimmedQuery.length < 2) {
    throw RustApiException(
      l10n.rustApiClientSearchQueryTooShort,
      statusCode: 400,
    );
  }
  if (trimmedQuery.length > 200) {
    throw RustApiException(
      l10n.rustApiClientSearchQueryTooLong,
      statusCode: 400,
    );
  }

  final queryParts = <String>[
    'q=${Uri.encodeQueryComponent(trimmedQuery)}',
  ];

  if (resultTypes != null && resultTypes.isNotEmpty) {
    // 重复 `type=` 键，便于 Axum / serde 将 `Vec<ResultType>` 反序列化为多元素（逗号单键不可靠）。
    for (final t in resultTypes) {
      queryParts.add('type=${Uri.encodeQueryComponent(t.toJson())}');
    }
  }
  if (page != null) {
    queryParts.add('page=$page');
  }
  if (pageSize != null) {
    queryParts.add('page_size=$pageSize');
  }
  if (timeFrom != null) {
    queryParts.add(
      'time_from=${Uri.encodeQueryComponent(timeFrom.toIso8601String())}',
    );
  }
  if (timeTo != null) {
    queryParts.add(
      'time_to=${Uri.encodeQueryComponent(timeTo.toIso8601String())}',
    );
  }

  final uri = Uri.parse('$kApiBaseUrl/api/v1/search?${queryParts.join('&')}');

  final request = http.Request('GET', uri)
    ..headers.addAll(rustApiAuthHeaders(accessToken));

  // Support cancellation
  final client = http.Client();
  try {
    final streamedResponse = cancellationToken != null
        ? await cancellationToken.executeWithCancellation(
            () => client.send(request),
          )
        : await client.send(request).timeout(const Duration(seconds: 30));

    final res = await http.Response.fromStream(streamedResponse);
    ensureHttpSuccess(res);

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return SearchResponse.fromJson(json);
  } finally {
    client.close();
  }
}

/// `GET /api/v1/search/history` — Retrieve user's search history.
///
/// Returns list of recent search history entries (up to 10 most recent).
/// Throws [RustApiException] on error.
Future<List<HistoryEntry>> getHistory(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/search/history');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));

  ensureHttpSuccess(res);

  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final response = HistoryResponse.fromJson(json);
  return response.history;
}

/// `DELETE /api/v1/search/history` — Delete all search history for the current user.
///
/// Returns successfully (void) on HTTP 204 No Content.
/// Throws [RustApiException] on error.
Future<void> deleteHistory(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/search/history');
  final res = await http
      .delete(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));

  ensureHttpStatus(res, 204);
}

/// Cancellation token for aborting in-flight search requests
class CancellationToken {
  CancellationToken();

  bool _isCancelled = false;
  final _completer = Completer<void>();

  bool get isCancelled => _isCancelled;

  /// Cancel the operation
  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      _completer.complete();
    }
  }

  /// Execute a future with cancellation support
  Future<T> executeWithCancellation<T>(Future<T> Function() operation) async {
    if (_isCancelled) {
      throw RustApiException('Request was cancelled', statusCode: 499);
    }

    final operationFuture = operation();
    final cancelFuture = _completer.future;

    final result = await Future.any([
      operationFuture.then((value) => _Result<T>.success(value)),
      cancelFuture.then((_) => _Result<T>.cancelled()),
    ]);

    if (result.isCancelled) {
      throw RustApiException('Request was cancelled', statusCode: 499);
    }

    return result.value!;
  }
}

class _Result<T> {
  _Result.success(this.value) : isCancelled = false;
  _Result.cancelled()
      : value = null,
        isCancelled = true;

  final T? value;
  final bool isCancelled;
}
