import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// OpenAPI **`MemoryConfig`** — prior **`getMemory`** / **`sureMemory`** (**camelCase**).
class MemoryConfigV1 {
  const MemoryConfigV1({
    required this.messagesPerSummary,
    required this.shortTermLimit,
    required this.summaryMaxLength,
    required this.summaryLimit,
    required this.ragLimit,
    required this.deepRetrieveSummaryLimit,
    required this.modelOnnxFile,
    required this.modelDtype,
  });

  final int messagesPerSummary;
  final int shortTermLimit;
  final int summaryMaxLength;
  final int summaryLimit;
  final int ragLimit;
  final int deepRetrieveSummaryLimit;
  final List<String> modelOnnxFile;
  final String modelDtype;

  factory MemoryConfigV1.fromJson(Map<String, dynamic> json) {
    final files = json['modelOnnxFile'];
    return MemoryConfigV1(
      messagesPerSummary: (json['messagesPerSummary'] as num).toInt(),
      shortTermLimit: (json['shortTermLimit'] as num).toInt(),
      summaryMaxLength: (json['summaryMaxLength'] as num).toInt(),
      summaryLimit: (json['summaryLimit'] as num).toInt(),
      ragLimit: (json['ragLimit'] as num).toInt(),
      deepRetrieveSummaryLimit: (json['deepRetrieveSummaryLimit'] as num)
          .toInt(),
      modelOnnxFile: (files is List)
          ? files.map((e) => e.toString()).toList()
          : <String>[],
      modelDtype: json['modelDtype'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'messagesPerSummary': messagesPerSummary,
    'shortTermLimit': shortTermLimit,
    'summaryMaxLength': summaryMaxLength,
    'summaryLimit': summaryLimit,
    'ragLimit': ragLimit,
    'deepRetrieveSummaryLimit': deepRetrieveSummaryLimit,
    'modelOnnxFile': modelOnnxFile,
    'modelDtype': modelDtype,
  };

  MemoryConfigV1 copyWith({int? ragLimit}) {
    return MemoryConfigV1(
      messagesPerSummary: messagesPerSummary,
      shortTermLimit: shortTermLimit,
      summaryMaxLength: summaryMaxLength,
      summaryLimit: summaryLimit,
      ragLimit: ragLimit ?? this.ragLimit,
      deepRetrieveSummaryLimit: deepRetrieveSummaryLimit,
      modelOnnxFile: List<String>.from(modelOnnxFile),
      modelDtype: modelDtype,
    );
  }
}

/// `GET /api/v1/settings/memory-config` — OpenAPI `getMemoryConfigV1`.
Future<MemoryConfigV1> fetchMemoryConfigV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return MemoryConfigV1.fromJson(map);
}

/// `POST /api/v1/settings/memory-config` — OpenAPI `postMemoryConfigV1`; returns **`message`** (human-readable success text).
Future<String> postMemoryConfigV1(
  String accessToken,
  MemoryConfigV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/memory-config');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String;
}

/// `POST /api/v1/settings/memory-config/clear-agent-memories` — OpenAPI `postSettingsClearAgentMemoriesV1` (often **503** without DB).
Future<int> postSettingsClearAgentMemoriesV1(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/memory-config/clear-agent-memories',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
  };
  if (episodesId != null) {
    body['episodesId'] = episodesId;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
