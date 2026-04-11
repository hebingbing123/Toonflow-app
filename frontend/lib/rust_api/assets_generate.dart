part of 'index.dart';

/// `POST /api/v1/assets-generate/generate` — OpenAPI `postAssetsGenerateV1`.
/// **200** = **`queued`** **`JobRow`** (**`asset.generate.image`**); worker **`succeeded`** inserts
/// **`app_asset_image`** (temporary provider **`image_url`**) when **`OPENAI_API_KEY`/`LLM_API_KEY`**
/// is set. Optional **`base64`** accepts data URI or raw base64 reference image. **404** unknown
/// project; **429** daily quota; **503** no DB.
Future<int> postAssetsGenerateGenerateV1(
  String accessToken, {
  required int projectId,
  required int assetNumericId,
  required String model,
  required String resolution,
  required String type,
  required String name,
  required String prompt,
  String? base64,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/generate');
  final body = <String, dynamic>{
    'projectId': projectId,
    'model': model,
    'resolution': resolution,
    'id': assetNumericId,
    'type': type,
    'name': name,
    'prompt': prompt,
  };
  if (base64 != null) body['base64'] = base64;
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

/// `POST /api/v1/assets-generate/cancel-generate` — OpenAPI
/// `postAssetsGenerateCancelGenerateV1`.
/// Workbench-compatible cancel acknowledgement: **200** for accepted cancel (idempotent when
/// numeric image id is not found), **400** invalid id, **503** no DB.
Future<int> postAssetsGenerateCancelGenerateV1(
  String accessToken, {
  required int numericImageId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets-generate/cancel-generate');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': numericImageId}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
