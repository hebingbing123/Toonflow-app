import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Binary fetch helpers for skill assets under `data/skills`.
/// Builds `GET /api/v1/skills/binary?path=` — OpenAPI `getSkillBinaryV1` (JWT on the request).
Uri skillsBinaryV1Uri(String pathUnderDataSkills) {
  return Uri.parse(
    '$kApiBaseUrl/api/v1/skills/binary',
  ).replace(queryParameters: {'path': pathUnderDataSkills});
}

/// Fetches raw image (or other allowed) bytes from [`skillsBinaryV1Uri`].
Future<Uint8List> fetchSkillsBinaryV1(
  String accessToken,
  String pathUnderDataSkills,
) async {
  final uri = skillsBinaryV1Uri(pathUnderDataSkills);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(
      res.body.isNotEmpty ? res.body : 'binary response ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }
  return res.bodyBytes;
}
