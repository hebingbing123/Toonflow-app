import 'package:flutter/foundation.dart';

/// Resolves **`/product/search?q=`** from a full app [Uri] (path or hash fragment).
///
/// Supports:
/// - `https://host/product/search?q=关键词`
/// - `https://host/#/product/search?q=关键词`
/// - `https://host/#product/search?q=关键词`
@immutable
class ProductSearchDeepLink {
  const ProductSearchDeepLink._(
    this.query,
    this.resultTypes, {
    this.timeFrom,
    this.timeTo,
  });

  /// Trimmed search query; empty if invalid.
  final String query;
  final List<String> resultTypes;
  final DateTime? timeFrom;
  final DateTime? timeTo;

  /// Returns non-null when the URI targets global search with a usable query (≥2 chars).
  static ProductSearchDeepLink? tryParse(Uri uri) {
    final direct = _fromPathAndQuery(uri.path, uri.queryParametersAll);
    if (direct != null) {
      return direct;
    }
    final raw = uri.fragment.trim();
    if (raw.isEmpty) {
      return null;
    }
    final qMark = raw.indexOf('?');
    final pathPart = qMark == -1 ? raw : raw.substring(0, qMark);
    final queryPart = qMark == -1 ? '' : raw.substring(qMark + 1);
    final normalized = pathPart.startsWith('/')
        ? pathPart
        : '/${pathPart.trim()}';
    final qp = Uri(query: queryPart).queryParametersAll;
    return _fromPathAndQuery(normalized, qp);
  }

  static ProductSearchDeepLink? _fromPathAndQuery(
    String path,
    Map<String, List<String>> queryParameters,
  ) {
    if (path != '/product/search') {
      return null;
    }
    final q = (queryParameters['q']?.first ?? '').trim();
    if (q.length < 2 || q.length > 200) {
      return null;
    }
    final resultTypes = (queryParameters['type'] ?? const <String>[])
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final timeFrom = DateTime.tryParse(
      (queryParameters['timeFrom']?.first ?? '').trim(),
    );
    final timeTo = DateTime.tryParse(
      (queryParameters['timeTo']?.first ?? '').trim(),
    );
    return ProductSearchDeepLink._(
      q,
      resultTypes,
      timeFrom: timeFrom,
      timeTo: timeTo,
    );
  }
}
