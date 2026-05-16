import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core.dart';

/// OpenAPI **`DirectorManualDataSlot`** (also used for visual manual POST bodies).
class DirectorManualDataSlot {
  const DirectorManualDataSlot({
    required this.label,
    required this.value,
    required this.data,
  });

  final String label;
  final String value;
  final String data;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'data': data,
  };

  factory DirectorManualDataSlot.fromJson(Map<String, dynamic> json) {
    return DirectorManualDataSlot(
      label: json['label'] as String,
      value: json['value'] as String,
      data: json['data'] as String,
    );
  }
}

/// OpenAPI **`DirectorManualStyleRow`** (`directorManual` = folder under `story_skills`).
class DirectorManualStyleRow {
  const DirectorManualStyleRow({
    required this.name,
    required this.image,
    required this.directorManual,
    required this.data,
  });

  final String name;
  final List<String> image;
  final String directorManual;
  final List<DirectorManualDataSlot> data;

  factory DirectorManualStyleRow.fromJson(Map<String, dynamic> json) {
    final imgs = json['image'] as List<dynamic>? ?? const [];
    final slots = json['data'] as List<dynamic>? ?? const [];
    return DirectorManualStyleRow(
      name: json['name'] as String,
      image: imgs.map((e) => e as String).toList(),
      directorManual: json['directorManual'] as String,
      data: slots
          .map(
            (e) => DirectorManualDataSlot.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// OpenAPI **`DirectorManualListResponse`**.
class DirectorManualListResponse {
  const DirectorManualListResponse({required this.data});

  final List<DirectorManualStyleRow> data;

  factory DirectorManualListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return DirectorManualListResponse(
      data: raw
          .map(
            (e) => DirectorManualStyleRow.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

void expectEmptyObjectResponse(http.Response res) {
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw RustApiException('expected JSON object', statusCode: res.statusCode);
  }
  if (decoded.isNotEmpty) {
    throw RustApiException(
      'expected empty object {{}}, got $decoded',
      statusCode: res.statusCode,
    );
  }
}
