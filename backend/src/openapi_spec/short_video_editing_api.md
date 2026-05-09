# 短视频轻量剪辑工作台 API 文档

本文档描述短视频轻量剪辑工作台的 API 端点，包括 TTS 配音、视频导出、批量操作等功能。

## 目录

1. [认证](#认证)
2. [TTS 配音 API](#tts-配音-api)
3. [视频导出 API](#视频导出-api)
4. [批量操作 API](#批量操作-api)
5. [错误处理](#错误处理)
6. [速率限制](#速率限制)

---

## 认证

所有 API 端点都需要 JWT 认证。

### 请求头

```http
Authorization: Bearer <jwt_token>
```

### 权限检查

- 用户必须是项目的所有者或协作者
- 某些操作需要特定权限（如导出需要导出权限）

---

## TTS 配音 API

### POST /api/v1/tts/generate

为单个镜头生成 TTS 配音。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "project_id": "uuid",
  "shot_id": "uuid",
  "text": "配音文本内容",
  "provider": "openai",
  "voice_id": "alloy",
  "emotion": "neutral",
  "speed": 1.0
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| shot_id | string (UUID) | 是 | 镜头 ID |
| text | string | 是 | 配音文本（1-5000 字符） |
| provider | string | 是 | TTS 供应商（openai, azure） |
| voice_id | string | 是 | 声线 ID |
| emotion | string | 否 | 情绪（neutral, happy, sad, angry）默认 neutral |
| speed | number | 否 | 语速（0.5-2.0）默认 1.0 |

#### 响应

**成功 (200 OK):**
```json
{
  "task_id": "uuid",
  "status": "completed",
  "audio_url": "https://storage.example.com/audio/xxx.mp3",
  "duration": 5.2,
  "created_at": "2025-01-15T10:30:00Z"
}
```

**响应字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| task_id | string (UUID) | 任务 ID |
| status | string | 任务状态（pending, running, completed, failed） |
| audio_url | string | 音频文件 URL（仅 completed 状态） |
| duration | number | 音频时长（秒） |
| created_at | string (ISO 8601) | 创建时间 |

**错误响应:**

- `400 Bad Request`: 参数错误
- `401 Unauthorized`: 未认证
- `403 Forbidden`: 无权限
- `404 Not Found`: 项目或镜头不存在
- `429 Too Many Requests`: 超过速率限制
- `503 Service Unavailable`: TTS 服务不可用

---

### POST /api/v1/tts/batch-generate

为多个镜头批量生成 TTS 配音。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "project_id": "uuid",
  "shots": [
    {
      "shot_id": "uuid",
      "text": "配音文本内容",
      "voice_id": "alloy",
      "emotion": "neutral",
      "speed": 1.0
    }
  ],
  "provider": "openai"
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| shots | array | 是 | 镜头配音配置数组（最多 100 个） |
| shots[].shot_id | string (UUID) | 是 | 镜头 ID |
| shots[].text | string | 是 | 配音文本 |
| shots[].voice_id | string | 是 | 声线 ID |
| shots[].emotion | string | 否 | 情绪 |
| shots[].speed | number | 否 | 语速 |
| provider | string | 是 | TTS 供应商 |

#### 响应

**成功 (200 OK):**
```json
{
  "batch_id": "uuid",
  "total": 10,
  "completed": 8,
  "failed": 2,
  "results": [
    {
      "shot_id": "uuid",
      "status": "completed",
      "audio_url": "https://storage.example.com/audio/xxx.mp3",
      "duration": 5.2
    },
    {
      "shot_id": "uuid",
      "status": "failed",
      "error": "TTS service timeout"
    }
  ]
}
```

**响应字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| batch_id | string (UUID) | 批次 ID |
| total | number | 总数 |
| completed | number | 成功数 |
| failed | number | 失败数 |
| results | array | 结果数组 |
| results[].shot_id | string (UUID) | 镜头 ID |
| results[].status | string | 状态（completed, failed） |
| results[].audio_url | string | 音频 URL（仅 completed） |
| results[].duration | number | 音频时长（秒） |
| results[].error | string | 错误信息（仅 failed） |

---

## 视频导出 API

### POST /api/v1/export/start

启动视频导出任务。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "project_id": "uuid",
  "version_id": "uuid",
  "format": "mp4",
  "quality": {
    "resolution": "1080p",
    "bitrate": 5000,
    "framerate": 30
  }
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| version_id | string (UUID) | 否 | 版本 ID（默认当前版本） |
| format | string | 是 | 格式（mp4, mov, webm） |
| quality.resolution | string | 是 | 分辨率（720p, 1080p, 4k） |
| quality.bitrate | number | 是 | 码率（kbps，1000-20000） |
| quality.framerate | number | 是 | 帧率（24, 30, 60） |

#### 响应

**成功 (200 OK):**
```json
{
  "task_id": "uuid",
  "status": "pending",
  "stage": "preparing",
  "progress": 0,
  "estimated_duration": 120,
  "created_at": "2025-01-15T10:30:00Z"
}
```

**响应字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| task_id | string (UUID) | 任务 ID |
| status | string | 状态（pending, running, completed, failed, cancelled） |
| stage | string | 阶段（preparing, encoding, uploading） |
| progress | number | 进度（0-100） |
| estimated_duration | number | 预计时长（秒） |
| created_at | string (ISO 8601) | 创建时间 |

---

### GET /api/v1/export/tasks

查询导出任务列表。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Query Parameters:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| status | string | 否 | 状态过滤（pending, running, completed, failed, cancelled） |
| limit | number | 否 | 每页数量（默认 20，最大 100） |
| offset | number | 否 | 偏移量（默认 0） |

#### 响应

**成功 (200 OK):**
```json
{
  "total": 50,
  "tasks": [
    {
      "task_id": "uuid",
      "status": "completed",
      "stage": "uploading",
      "progress": 100,
      "format": "mp4",
      "quality": {
        "resolution": "1080p",
        "bitrate": 5000,
        "framerate": 30
      },
      "output_url": "https://storage.example.com/video/xxx.mp4",
      "file_size": 10485760,
      "started_at": "2025-01-15T10:30:00Z",
      "completed_at": "2025-01-15T10:32:00Z",
      "created_at": "2025-01-15T10:30:00Z"
    }
  ]
}
```

**响应字段:**

| 字段 | 类型 | 说明 |
|------|------|------|
| total | number | 总数 |
| tasks | array | 任务数组 |
| tasks[].task_id | string (UUID) | 任务 ID |
| tasks[].status | string | 状态 |
| tasks[].stage | string | 阶段 |
| tasks[].progress | number | 进度（0-100） |
| tasks[].format | string | 格式 |
| tasks[].quality | object | 质量参数 |
| tasks[].output_url | string | 输出 URL（仅 completed） |
| tasks[].file_size | number | 文件大小（字节） |
| tasks[].started_at | string (ISO 8601) | 开始时间 |
| tasks[].completed_at | string (ISO 8601) | 完成时间 |
| tasks[].created_at | string (ISO 8601) | 创建时间 |

---

### POST /api/v1/export/cancel

取消导出任务。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "task_id": "uuid"
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| task_id | string (UUID) | 是 | 任务 ID |

#### 响应

**成功 (200 OK):**
```json
{
  "task_id": "uuid",
  "status": "cancelled",
  "message": "Export task cancelled successfully"
}
```

---

## 批量操作 API

### POST /api/v1/workbench/batch-select

批量选择镜头。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "project_id": "uuid",
  "shot_ids": ["uuid1", "uuid2", "uuid3"],
  "selected": true
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| shot_ids | array | 是 | 镜头 ID 数组（最多 1000 个） |
| selected | boolean | 是 | 选中状态 |

#### 响应

**成功 (200 OK):**
```json
{
  "total": 100,
  "success": 95,
  "failed": 5,
  "results": [
    {
      "shot_id": "uuid",
      "status": "success"
    },
    {
      "shot_id": "uuid",
      "status": "failed",
      "error": "Shot not found"
    }
  ]
}
```

---

### POST /api/v1/workbench/batch-delete

批量禁用镜头。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "project_id": "uuid",
  "shot_ids": ["uuid1", "uuid2", "uuid3"]
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| shot_ids | array | 是 | 镜头 ID 数组（最多 1000 个） |

#### 响应

**成功 (200 OK):**
```json
{
  "total": 100,
  "success": 95,
  "failed": 5,
  "results": [
    {
      "shot_id": "uuid",
      "status": "success"
    },
    {
      "shot_id": "uuid",
      "status": "failed",
      "error": "Shot not found"
    }
  ]
}
```

---

### POST /api/v1/workbench/batch-update-duration

批量更新镜头时长。

#### 请求

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Body:**
```json
{
  "project_id": "uuid",
  "shot_ids": ["uuid1", "uuid2", "uuid3"],
  "duration": 5.0
}
```

**参数说明:**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| project_id | string (UUID) | 是 | 项目 ID |
| shot_ids | array | 是 | 镜头 ID 数组（最多 1000 个） |
| duration | number | 是 | 目标时长（秒，1-300） |

#### 响应

**成功 (200 OK):**
```json
{
  "total": 100,
  "success": 95,
  "failed": 5,
  "results": [
    {
      "shot_id": "uuid",
      "status": "success",
      "old_duration": 3.0,
      "new_duration": 5.0
    },
    {
      "shot_id": "uuid",
      "status": "failed",
      "error": "Invalid duration"
    }
  ]
}
```

---

## 错误处理

### 错误响应格式

所有错误响应遵循统一格式：

```json
{
  "status": 400,
  "code": "bad_request",
  "message": "Invalid parameter: duration must be between 1 and 300",
  "request_id": "req_abc123xyz",
  "details": {
    "field": "duration",
    "constraint": "range",
    "min": 1,
    "max": 300
  }
}
```

**字段说明:**

| 字段 | 类型 | 说明 |
|------|------|------|
| status | number | HTTP 状态码 |
| code | string | 错误代码 |
| message | string | 错误消息 |
| request_id | string | 请求 ID（用于追踪） |
| details | object | 详细信息（可选） |

### 常见错误代码

| 状态码 | 错误代码 | 说明 |
|--------|---------|------|
| 400 | bad_request | 请求参数错误 |
| 401 | unauthorized | 未认证 |
| 401 | invalid_token | JWT 令牌无效 |
| 403 | forbidden | 无权限 |
| 404 | not_found | 资源不存在 |
| 409 | conflict | 资源冲突 |
| 429 | quota_exceeded | 超过配额限制 |
| 500 | internal_error | 内部服务器错误 |
| 503 | service_unavailable | 服务不可用 |

### 错误处理最佳实践

1. **检查 status 字段**：判断错误类型
2. **使用 request_id**：用于追踪和调试
3. **显示 message**：向用户展示友好的错误消息
4. **处理 details**：提供更详细的错误信息
5. **实现重试逻辑**：对于 429 和 503 错误

---

## 速率限制

### 限制规则

| 端点 | 限制 | 窗口 |
|------|------|------|
| POST /api/v1/tts/generate | 100 次 | 1 分钟 |
| POST /api/v1/tts/batch-generate | 10 次 | 1 分钟 |
| POST /api/v1/export/start | 10 次 | 1 小时 |
| POST /api/v1/workbench/batch-* | 50 次 | 1 分钟 |
| 其他端点 | 1000 次 | 1 分钟 |

### 速率限制响应头

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642262400
```

**响应头说明:**

| 响应头 | 说明 |
|--------|------|
| X-RateLimit-Limit | 速率限制（次数） |
| X-RateLimit-Remaining | 剩余次数 |
| X-RateLimit-Reset | 重置时间（Unix 时间戳） |

### 超过速率限制

**响应 (429 Too Many Requests):**
```json
{
  "status": 429,
  "code": "quota_exceeded",
  "message": "Rate limit exceeded. Please try again in 60 seconds.",
  "retry_after_ms": 60000
}
```

**响应头:**
```http
Retry-After: 60
```

---

## 请求示例

### cURL 示例

**生成 TTS 配音:**
```bash
curl -X POST https://api.toonflow.com/api/v1/tts/generate \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "123e4567-e89b-12d3-a456-426614174000",
    "shot_id": "123e4567-e89b-12d3-a456-426614174001",
    "text": "这是一段配音文本",
    "provider": "openai",
    "voice_id": "alloy",
    "emotion": "neutral",
    "speed": 1.0
  }'
```

**启动导出任务:**
```bash
curl -X POST https://api.toonflow.com/api/v1/export/start \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "123e4567-e89b-12d3-a456-426614174000",
    "format": "mp4",
    "quality": {
      "resolution": "1080p",
      "bitrate": 5000,
      "framerate": 30
    }
  }'
```

**查询导出任务:**
```bash
curl -X GET "https://api.toonflow.com/api/v1/export/tasks?project_id=123e4567-e89b-12d3-a456-426614174000&status=completed&limit=20" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### JavaScript 示例

**使用 Fetch API:**
```javascript
// 生成 TTS 配音
async function generateTTS(projectId, shotId, text) {
  const response = await fetch('https://api.toonflow.com/api/v1/tts/generate', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${YOUR_JWT_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      project_id: projectId,
      shot_id: shotId,
      text: text,
      provider: 'openai',
      voice_id: 'alloy',
      emotion: 'neutral',
      speed: 1.0
    })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message);
  }

  return await response.json();
}

// 启动导出任务
async function startExport(projectId, format, quality) {
  const response = await fetch('https://api.toonflow.com/api/v1/export/start', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${YOUR_JWT_TOKEN}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      project_id: projectId,
      format: format,
      quality: quality
    })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message);
  }

  return await response.json();
}

// 查询导出任务
async function getExportTasks(projectId, status = null) {
  const params = new URLSearchParams({
    project_id: projectId,
    limit: 20
  });

  if (status) {
    params.append('status', status);
  }

  const response = await fetch(`https://api.toonflow.com/api/v1/export/tasks?${params}`, {
    headers: {
      'Authorization': `Bearer ${YOUR_JWT_TOKEN}`
    }
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.message);
  }

  return await response.json();
}
```

### Python 示例

**使用 requests 库:**
```python
import requests

API_BASE_URL = 'https://api.toonflow.com'
JWT_TOKEN = 'YOUR_JWT_TOKEN'

headers = {
    'Authorization': f'Bearer {JWT_TOKEN}',
    'Content-Type': 'application/json'
}

# 生成 TTS 配音
def generate_tts(project_id, shot_id, text):
    url = f'{API_BASE_URL}/api/v1/tts/generate'
    data = {
        'project_id': project_id,
        'shot_id': shot_id,
        'text': text,
        'provider': 'openai',
        'voice_id': 'alloy',
        'emotion': 'neutral',
        'speed': 1.0
    }
    
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()

# 启动导出任务
def start_export(project_id, format, quality):
    url = f'{API_BASE_URL}/api/v1/export/start'
    data = {
        'project_id': project_id,
        'format': format,
        'quality': quality
    }
    
    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    return response.json()

# 查询导出任务
def get_export_tasks(project_id, status=None):
    url = f'{API_BASE_URL}/api/v1/export/tasks'
    params = {
        'project_id': project_id,
        'limit': 20
    }
    
    if status:
        params['status'] = status
    
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json()
```

---

## 相关文档

- [用户指南](../docs/short-video-editing-user-guide.md)
- [快捷键参考](../docs/short-video-editing-shortcuts.md)
- [错误处理指南](../backend/ERROR_HANDLING.md)
- [监控和日志](../docs/monitoring-and-logging.md)

---

**最后更新**: 2025-01-15
**API 版本**: v1
