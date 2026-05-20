# Vendor API contracts (implementation source of truth)

## 两种接入方式（请先分清）

| 模式 | 你怎么配 | 我们怎么调 |
|------|----------|------------|
| **A. 第三方聚合平台** | 在 Settings 填 **OneAPI / New API / 硅基流动** 等统一地址 + 一把 API Key；换模型只改 `model` 名 | **OpenAI 兼容**：`/v1/chat/completions`、`/v1/images/generations`、`/v1/videos`（若平台支持） |
| **B. 厂商官方直连** | `base_url` 留空或等于官方 Host；凭证按厂商要求（Kling AK/SK、混元 SecretId/Key 等） | **各厂商原生 API**（见下表）：Runway tasks、Kling JWT、混元 TC3、fal 队列、万相 text2image 等 |

**自动判断（视频）**：仅当你在 Settings 里 **显式填写了 `base_url`，且 Host 不是该厂商官方 Host** 时，走 **A（OpenAI 兼容 `/v1/videos`）**；否则走 **B**。

**自动判断（图片）**：万相 Wan 仅在 `base_url` 为 **DashScope 官方域名** 时走原生 `text2image`；填聚合平台地址时走 **`/images/generations`**。Seedream / Imagen 同理：仅在 **火山 / Google 官方 Host** 走原生，否则走 OpenAI 形态。

**文本 / 多模态**：目录里各云厂商默认已是 OpenAI 兼容 `base_url`（如 Qwen `compatible-mode/v1`），直接填聚合平台地址即可，与 A 一致。

---

## 官方原生 API（模式 B，wiremock 契约见代码）

| Vendor | Official docs | Host / path | Auth |
|--------|---------------|-------------|------|
| **Runway** | [Runway API](https://docs.dev.runwayml.com/api/) | `https://api.dev.runwayml.com` | Bearer + `X-Runway-Version: 2024-11-06` |
| **Kling** | [Kling API](https://app.klingai.com/cn/dev/document-api/apiReference/model/textToVideo) | `https://api.klingai.com` | JWT (AK+SK) |
| **Pika** | [fal.ai Pika](https://fal.ai/models/fal-ai/pika) | `https://queue.fal.run` | `Key {FAL_KEY}` |
| **Doubao Seedance** | [Volcengine Ark](https://www.volcengine.com/docs/82379) | `https://ark.cn-beijing.volces.com` | Bearer |
| **Hunyuan video** | [VCLM TC3](https://cloud.tencent.com/document/api/1616/126160) | `https://vclm.tencentcloudapi.com` | SecretId + SecretKey |
| **MiniMax** | [MiniMax video](https://www.minimaxi.com/document/guides/video-generation) | `https://api.minimaxi.com` | Bearer |
| **OpenAI Sora** | [Video API](https://platform.openai.com/docs/api-reference/videos) | `https://api.openai.com` | Bearer |
| **DashScope Wan** | [万相文生图 V2](https://help.aliyun.com/zh/model-studio/text-to-image-v2-api-reference) | DashScope 官方域名 | Bearer + 异步 task |

## 聚合平台（模式 A）怎么配

1. 在 **设置 → 模型提供商** 选中对应条目（或统一用 OpenAI/硅基等已支持 OpenAI 协议的厂商）。
2. **Base URL**：填平台文档给的根地址，例如 `https://api.siliconflow.cn/v1`、`https://your-oneapi.com/v1`。
3. **API Key**：填平台密钥（单 Key 多模型）。
4. **模型名**：与平台文档一致（如 `gpt-4o`、`wanx2.1-t2i-turbo`、`kling-v1`）；Studio 路由里选 catalog 模型即可。

视频是否可用取决于 **平台是否提供 OpenAI 形态的 video 接口**；若无，需在平台侧开通或改选支持视频的模型，不能指望我们走 Kling 原生 JWT 去调 OneAPI 地址。

Settings → **模型提供商** 在填写非官方 `base_url` 时会显示紧凑标签「聚合平台 · OpenAI 协议」；非 `openai` 协议厂商显示 Ark / Claude / Gemini 等小标签。

## Settings 字段

| 场景 | API Key | API Secret | base_url |
|------|---------|------------|----------|
| 聚合平台 A | 平台 Key | 通常不需要 | **必填** 平台根 URL |
| Kling 官方 B | Access Key | Secret Key | 可选 |
| 混元视频官方 B | SecretId | SecretKey | 可选 |
| fal / Pika 官方 B | FAL Key | — | 可选 |

`base_url` 解析顺序（与 LLM 相同）：**用户 Settings** → **catalog `default_base_url`** → 内置官方 Host。

## Mock 测试

```bash
cd backend && cargo test --lib vendor::video::http_integration -- --test-threads=1
cd backend && cargo test --lib native_images
```

Native 契约测试使用 `OPENFLOW_TEST_VIDEO_API_BASE`（wiremock），**不**触发聚合模式（因未配置用户 `base_url`）。
