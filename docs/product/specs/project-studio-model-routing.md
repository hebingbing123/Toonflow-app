# 项目 Studio 步骤模型路由

**状态**：已实现（平台级）  
**相关 API**：`GET` / `PATCH` `/api/v1/projects/{project_id}/model-routing`，`POST` `.../model-routing/resolve`

## 目标

同一工作区内，**不同项目**可在 **不同 Studio 步骤** 配置不同模型（文本 / 多模态 / 图像 / 视频 / 语音）。Harness、剧本/小说抽取、资产、分镜、视频批量、配音等链路在未显式传 `model_id` 时，经统一解析器选用模型。

## 数据模型（`metadata.modelRouting` v1）

```json
{
  "modelRouting": {
    "version": 1,
    "steps": {
      "script": { "text": "1:gpt-4.1-mini" },
      "video": { "multimodal": "1:gpt-4o", "video": "kling-v1" }
    }
  }
}
```

**槽位（`ModelSlot`）**：`text` | `multimodal` | `image` | `video` | `voice`

**模态默认列**（`app_project`）：`text_model`、`multimodal_model`、`image_model`、`video_model`、`voice_model` —— 步骤未覆盖时使用。

PATCH 合并时可将主步骤写回模态列（例如 `script.text` → `text_model`，`video.video` → `video_model`）。

## Studio 步骤与默认槽位

| Studio 步骤 | 常用槽位 | 典型 `task_kind`（计费） |
|-------------|----------|-------------------------|
| `script` | `text` | `text_completion` |
| `art` | `image` | `asset_image_batch` |
| `assets` | `image`, `text`（润色） | `asset_image_batch` / 文本 |
| `storyboard` | `image`, `multimodal` | `storyboard_video` |
| `video` | `video`, `multimodal`, `text` | `storyboard_video` |
| `deliver` | 继承 `video` | — |
| `quality` | `text` | `text_completion` |

## 解析优先级

1. 请求体 / Job payload 显式 `model_id`
2. `metadata.modelRouting.steps[step][slot]`
3. 项目模态列（与 slot 同名）
4. 用户 `preferred_text_model_id`（仅 `text` 槽）
5. `agent_deploy_config`（仅无步骤/模态配置时）：`script`→`scriptAgent`，`storyboard`/`video`→`productionAgent`，`voice`→`ttsDubbing`
6. 目录默认（按槽位对应 `kind`）

## Harness

- `WsAgentChannel::Script` → `step=script`，`slot=text`
- `WsAgentChannel::Production` → `step=storyboard`，`slot=text`（制作向对话）；多模态工具另解析 `multimodal`
- 须 attach 项目；无项目时回退用户文本默认 / `agent_deploy`
- 可选 WS payload `model_id` 覆盖（显式优先）

## 与 Agent 部署的关系

**项目步骤路由优先**。设置页「Agent 部署」仅作无项目上下文或迁移期兜底；UI 应引导用户在项目「步骤模型路由」中配置。

## 环境变量

| 变量 | 说明 |
|------|------|
| `OPENFLOW_MODEL_ROUTING_ENFORCE` | `0` 时 Job/Harness 仍走旧路径（仅 API 可读 effective）；非 `0` 时默认启用解析器（默认启用） |
