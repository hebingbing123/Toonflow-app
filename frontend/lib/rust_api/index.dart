import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'core.dart';

export 'core.dart';
export 'production.dart';

part 'catalog_memory.dart';
part 'art_styles.dart';
part 'assets_api.dart';
part 'harness_api.dart';
part 'jobs_api.dart';
part 'novels_api.dart';
part 'project_overview.dart';
part 'projects_legacy.dart';
part 'scripts_storyboards.dart';
part 'script_agent.dart';
part 'skills_api.dart';
part 'settings_admin.dart';
part 'status_and_auth.dart';
part 'tasks_legacy.dart';

/// `POST /api/v1/assets-generate/generate` — OpenAPI `postAssetsGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.image`**); worker **`succeeded`** inserts
/// **`app_asset_image`** (temporary provider **`image_url`**) when **`OPENAI_API_KEY`/`LLM_API_KEY`**
/// is set. **404** unknown project; **429** daily quota; **503** no DB.
Future<int> postAssetsGenerateGenerateV1(
  String accessToken, {
  required int projectId,
  required int assetLegacyId,
  required String model,
  required String resolution,
  required String type,
  required String name,
  required String prompt,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/generate');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'model': model,
          'resolution': resolution,
          'id': assetLegacyId,
          'type': type,
          'name': name,
          'prompt': prompt,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/polish-prompt` — OpenAPI `postAssetsGeneratePolishPromptV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.polish.prompt`**); worker **`succeeded`** with
/// **`result.polished_prompt`** when **`OPENAI_API_KEY`/`LLM_API_KEY`** is set on the server.
/// **404**/**429**/**503** as for **`generate`**.
Future<int> postAssetsGeneratePolishPromptV1(
  String accessToken, {
  required int assetsId,
  required int projectId,
  required String type,
  required String name,
  required String describe,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/polish-prompt');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'assetsId': assetsId,
          'projectId': projectId,
          'type': type,
          'name': name,
          'describe': describe,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/assets-generate/batch-generate` — OpenAPI `postAssetsGenerateBatchGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.batch`**); worker runs **`images/generations`**
/// per item when LLM keys are set (**`result.items`**). **404**/**429**/**503** as for **`generate`**.
Future<int> postAssetsGenerateBatchGenerateV1(
  String accessToken, {
  required int projectId,
  required String model,
  required String resolution,
  required List<Map<String, dynamic>> items,
  int? concurrentCount,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/batch-generate');
  final body = <String, dynamic>{
    'projectId': projectId,
    'model': model,
    'resolution': resolution,
    'items': items,
  };
  if (concurrentCount != null) body['concurrentCount'] = concurrentCount;
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

/// `POST /api/v1/assets-generate/batch-polish` — OpenAPI `postAssetsGenerateBatchPolishV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.polish.batch`**); worker **`succeeded`** with
/// **`result.items`** (each **`polished_prompt`**) when the server has **`OPENAI_API_KEY`/`LLM_API_KEY`**.
Future<int> postAssetsGenerateBatchPolishV1(
  String accessToken, {
  required int projectId,
  required List<Map<String, dynamic>> items,
  int? concurrentCount,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/batch-polish');
  final body = <String, dynamic>{'projectId': projectId, 'items': items};
  if (concurrentCount != null) body['concurrentCount'] = concurrentCount;
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

/// `POST /api/v1/production/get-production-data` — OpenAPI `postProductionGetProductionDataV1` (implemented in Rust; returns **200** or **503** without DB).

// --- Legacy `POST /api/v1/tasks/*` (Electron task center) ---

// --- Legacy `POST /api/v1/project/*` (Electron project CRUD helpers) ---

/// One **`app_novel`** row — OpenAPI **`NovelRow`**.
