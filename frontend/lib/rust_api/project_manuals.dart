part of 'index.dart';

/// OpenAPI **`LegacyDirectorManualDataSlot`** (also used for visual manual POST bodies).
class LegacyDirectorManualDataSlot {
  const LegacyDirectorManualDataSlot({
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

  factory LegacyDirectorManualDataSlot.fromJson(Map<String, dynamic> json) {
    return LegacyDirectorManualDataSlot(
      label: json['label'] as String,
      value: json['value'] as String,
      data: json['data'] as String,
    );
  }
}

/// OpenAPI **`LegacyDirectorManualStyleRow`** (`directorManual` = folder under `story_skills`).
class LegacyDirectorManualStyleRow {
  const LegacyDirectorManualStyleRow({
    required this.name,
    required this.image,
    required this.directorManual,
    required this.data,
  });

  final String name;
  final List<String> image;
  final String directorManual;
  final List<LegacyDirectorManualDataSlot> data;

  factory LegacyDirectorManualStyleRow.fromJson(Map<String, dynamic> json) {
    final imgs = json['image'] as List<dynamic>? ?? const [];
    final slots = json['data'] as List<dynamic>? ?? const [];
    return LegacyDirectorManualStyleRow(
      name: json['name'] as String,
      image: imgs.map((e) => e as String).toList(),
      directorManual: json['directorManual'] as String,
      data: slots
          .map(
            (e) => LegacyDirectorManualDataSlot.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// OpenAPI **`LegacyDirectorManualListResponse`**.
class LegacyDirectorManualListResponse {
  const LegacyDirectorManualListResponse({required this.data});

  final List<LegacyDirectorManualStyleRow> data;

  factory LegacyDirectorManualListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return LegacyDirectorManualListResponse(
      data: raw
          .map(
            (e) => LegacyDirectorManualStyleRow.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

void _expectLegacyEmptyObjectResponse(http.Response res) {
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
