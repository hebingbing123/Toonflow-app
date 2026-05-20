# `models_catalog.json`

Compile-time model/vendor directory. After editing, rebuild the backend (`cargo build` / restart API).

## Add a vendor

```json
{
  "id": 8,
  "name": "My Provider",
  "default_base_url": "https://api.example.com/v1",
  "api_key_optional": false,
  "models": [
    {
      "name": "My Model",
      "model_name": "my-model-id",
      "type": "text"
    }
  ]
}
```

- **`id`**: unique integer; composite model ids are `{id}:{model_name}` (e.g. `8:my-model-id`).
- **`default_base_url`**: OpenAI-compatible `/v1` root (chat completions at `{base}/chat/completions`).
- **`protocol`**: Wire format for Settings UI (`openai`, `volcengine_ark`, `anthropic`, `gemini_native`, …). Exposed on `GET /api/v1/settings/vendors/summary` with `official_api_host` when `video_provider` is set.
- **`api_key_optional`**: `true` for local Ollama/LM Studio (no real key required).
- **`type`**: `text`, `image`, or `video` (video entries are hidden from `type=all` list).

Also add matching keys under `model_pricing.json` → `models` for billing UI.

## Built-in vendors (ids 1–15)

| ID | Vendor | Default base URL |
|----|--------|------------------|
| 1 | OpenAI | (env `OPENAI_BASE_URL` or `https://api.openai.com/v1`) |
| 2–4 | Runway / Pika / Kling | video providers |
| 5 | Ollama | `http://127.0.0.1:11434/v1` (key optional) |
| 6 | LM Studio | `http://127.0.0.1:1234/v1` (key optional) |
| 7 | Qwen (DashScope) | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| 8 | DeepSeek | `https://api.deepseek.com/v1` |
| 9 | Zhipu GLM | `https://open.bigmodel.cn/api/paas/v4` |
| 10 | Moonshot (Kimi) | `https://api.moonshot.cn/v1` |
| 11 | Baichuan | `https://api.baichuan-ai.com/v1` |
| 12 | SiliconFlow | `https://api.siliconflow.cn/v1` |
| 13 | MiniMax | `https://api.minimaxi.com/v1` |
| 14 | Yi (零一万物) | `https://api.lingyiwanwu.com/v1` |
| 15 | Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` |

All listed cloud vendors use **OpenAI-compatible** `POST {base}/chat/completions`.

Users can override `base_url` per vendor in **Settings → API & models → Model providers**.

## Vendor HTTP contracts (implementation source of truth)

See [`backend/docs/vendor-api-contracts.md`](../docs/vendor-api-contracts.md) for official doc links, paths, and **Settings credential field** mapping (e.g. Kling AK/SK → JWT, Hunyuan video → Tencent SecretId/SecretKey, Pika → `FAL_KEY` on fal.ai queue).

## Mock / contract tests (no real API keys)

Document-shaped JSON fixtures and wiremock tests:

| Area | Location |
|------|----------|
| Video (Runway, Kling, fal/Pika, Seedance, Hailuo, Sora, Hunyuan VCLM) | `backend/src/vendor/video/http_integration.rs` |
| Fixtures | `backend/src/vendor/video/doc_fixtures.rs` |
| Images (Seedream, Imagen, Wanx) | `backend/src/llm/openai/tests/native_images_http.rs` |

```bash
cd backend && cargo test --lib vendor::video::http_integration -- --test-threads=1
cd backend && cargo test --lib native_images
```

Video tests set `OPENFLOW_TEST_VIDEO_API_BASE` to a local wiremock URI (mutex-serialized).

Video jobs honor **Settings → Base URL** per vendor (same as LLM): user override → catalog `default_base_url` → official host. See `backend/docs/vendor-api-contracts.md`.
