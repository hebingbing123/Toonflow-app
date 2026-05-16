# 后端错误处理指南

本文档说明 Toonflow 后端的统一错误处理机制。

## 概述

后端使用统一的错误处理系统，确保所有 API 端点返回一致的错误响应格式，并自动记录错误日志。

## 错误响应格式

所有 API 错误响应遵循以下 JSON 格式：

```json
{
  "status": 400,
  "code": "bad_request",
  "message": "name must not be empty",
  "request_id": "req_abc123xyz",
  "details": {
    "field": "name",
    "constraint": "non_empty"
  },
  "retry_after_ms": 60000
}
```

### 字段说明

- **status** (u16): HTTP 状态码 (e.g., 400, 404, 409, 500)
- **code** (string): 机器可读的错误代码 (e.g., "validation_error", "not_found", "conflict")
- **message** (string): 人类可读的错误消息
- **request_id** (string, optional): 请求 ID，用于追踪和调试（由中间件自动注入）
- **details** (object, optional): 额外的上下文信息（如字段级验证错误、版本冲突详情）
- **retry_after_ms** (u64, optional): 速率限制重试等待时间（仅 429 响应）

## ApiError 枚举

`ApiError` 枚举定义了所有可能的错误类型：

```rust
pub enum ApiError {
    // 4xx 客户端错误
    Unauthorized,                    // 401: 缺少或无效的 Authorization 头
    BadToken,                        // 401: JWT 验证失败
    Forbidden(String),               // 403: 已认证但无权限
    NotFound,                        // 404: 资源不存在
    BadRequest(String),              // 400: 请求参数错误
    Conflict(String),                // 409: 资源冲突
    ConflictWithDetails {            // 409: 带详细信息的冲突
        message: String,
        details: serde_json::Value,
    },
    QuotaExceeded(String),           // 429: 配额超限
    
    // 5xx 服务器错误
    Internal,                        // 500: 内部服务器错误
    DatabaseError(String),           // 503: 数据库错误
    NotImplemented(String),          // 501: 功能未实现
    
    // 配置错误
    AuthNotConfigured,               // 503: SUPABASE_JWT_SECRET 未设置
    WebhookNotConfigured,            // 503: BILLING_WEBHOOK_SECRET 未设置
    LlmNotConfigured,                // 503: LLM API 密钥未配置
    InvalidWebhookSignature,         // 401: Webhook HMAC 验证失败
}
```

## 自动错误日志记录

所有错误在转换为 HTTP 响应时自动记录日志：

- **5xx 错误**（Internal、DatabaseError）记录为 `error` 级别
- **配置错误**（AuthNotConfigured、LlmNotConfigured）记录为 `warn` 级别
- **4xx 错误**（BadRequest、NotFound、Unauthorized）记录为 `info` 或 `debug` 级别

日志包含以下信息：
- `target`: 日志目标（`toonflow.api.error`）
- `error_type`: 错误类型（与 `code` 字段对应）
- `status`: HTTP 状态码
- `message`: 错误消息（如果有）
- `details`: 详细信息（如果有）

## 错误处理辅助函数

`error::helpers` 模块提供了常用的错误处理辅助函数：

### 数据库错误处理

```rust
use crate::error::helpers::db_error;

let user = sqlx::query_as("SELECT * FROM users WHERE id = $1")
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| db_error("Failed to fetch user", e))?;
```

### 内部错误处理

```rust
use crate::error::helpers::internal_error;

let data = serde_json::from_str(&json_str)
    .map_err(|e| internal_error("Failed to parse JSON", e))?;
```

### 输入验证

```rust
use crate::error::helpers::{
    validate_non_empty_string,
    validate_range,
    validate_enum,
    validate_input,
};

// 验证字符串非空
validate_non_empty_string(&body.name, "name")?;

// 验证数值范围
validate_range(body.duration, 1, 300, "duration")?;

// 验证枚举值
validate_enum(&body.format, &["mp4", "mov", "webm"], "format")?;

// 自定义验证
validate_input(body.age >= 18, "age must be at least 18")?;
```

## 使用示例

### 基本错误处理

```rust
use crate::error::ApiError;
use crate::error::helpers::{db_error, validate_non_empty_string};

pub async fn create_user(
    State(state): State<AppState>,
    Json(body): Json<CreateUserRequest>,
) -> Result<Json<User>, ApiError> {
    // 输入验证
    validate_non_empty_string(&body.name, "name")?;
    validate_non_empty_string(&body.email, "email")?;
    
    // 数据库操作
    let pool = state.pool.as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    
    let user = sqlx::query_as("INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *")
        .bind(&body.name)
        .bind(&body.email)
        .fetch_one(pool)
        .await
        .map_err(|e| db_error("Failed to create user", e))?;
    
    Ok(Json(user))
}
```

### 带详细信息的冲突错误

```rust
use crate::error::ApiError;

pub async fn update_timeline(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Json(body): Json<UpdateTimelineRequest>,
) -> Result<Json<Timeline>, ApiError> {
    let pool = state.pool.as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    
    // 检查版本冲突
    let current = sqlx::query_as::<_, Timeline>("SELECT * FROM timelines WHERE id = $1")
        .bind(id)
        .fetch_optional(pool)
        .await
        .map_err(|e| db_error("Failed to fetch timeline", e))?
        .ok_or(ApiError::NotFound)?;
    
    if current.version != body.expected_version {
        return Err(ApiError::ConflictWithDetails {
            message: "Timeline has been modified by another user".to_string(),
            details: serde_json::json!({
                "expected_version": body.expected_version,
                "current_version": current.version,
                "conflict_type": "version_mismatch"
            }),
        });
    }
    
    // 更新时间线...
    Ok(Json(updated_timeline))
}
```

### 权限检查

```rust
use crate::error::ApiError;
use crate::auth::require_user_uuid;

pub async fn delete_project(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<DeleteResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    
    let pool = state.pool.as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    
    // 检查项目所有权
    let project = sqlx::query_as::<_, Project>("SELECT * FROM projects WHERE id = $1")
        .bind(project_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| db_error("Failed to fetch project", e))?
        .ok_or(ApiError::NotFound)?;
    
    if project.owner_id != user_id {
        return Err(ApiError::Forbidden(
            "You do not have permission to delete this project".to_string()
        ));
    }
    
    // 删除项目...
    Ok(Json(DeleteResponse { success: true }))
}
```

## Request ID 追踪

Request ID 自动通过以下方式传播：

1. **客户端提供**：客户端可通过 `X-Request-ID` 请求头提供自定义 ID
2. **服务器生成**：如果客户端未提供，服务器自动生成 UUID
3. **响应返回**：Request ID 在响应头和错误体中返回
4. **日志关联**：所有日志记录包含 request ID（通过 tracing span）

### 使用 Request ID 调试

```bash
# 客户端发送请求时指定 Request ID
curl -H "X-Request-ID: my-debug-request-123" \
     -H "Authorization: Bearer $TOKEN" \
     https://api.toonflow.com/api/v1/projects

# 服务器日志中会包含该 Request ID
# 2025-01-15T10:30:45Z ERROR toonflow.api.error request_id="my-debug-request-123" error_type="database_error" ...
```

## 最佳实践

1. **使用辅助函数**：优先使用 `error::helpers` 中的辅助函数，而不是手动构造 `ApiError`
2. **提供上下文**：在错误消息中提供足够的上下文信息，帮助调试
3. **不泄露敏感信息**：避免在错误消息中包含敏感信息（如密码、密钥）
4. **使用 Internal 错误**：对于不应该暴露给客户端的内部错误，使用 `ApiError::Internal`
5. **记录详细日志**：使用 `db_error` 和 `internal_error` 辅助函数自动记录详细的错误日志
6. **一致的错误代码**：使用标准的 `ApiError` 枚举，确保错误代码的一致性

## 测试

错误处理系统包含完整的单元测试：

```bash
# 运行错误模块测试
cargo test --package toonflow-server --lib error

# 运行所有测试
cargo test
```

## 监控和告警

错误日志通过 `tracing` 框架记录，可以通过以下方式监控：

1. **OTLP 导出**：设置 `TOONFLOW_OTEL_EXPORT_ENABLED=1` 启用 OTLP trace 导出
2. **日志聚合**：使用 ELK、Loki 等日志聚合工具收集和分析错误日志
3. **告警规则**：为 5xx 错误设置告警规则，及时发现和处理服务器错误

## 相关文档

- [API 文档](./backend/src/openapi_spec/README.md)
- [认证和授权](./backend/src/auth/README.md)
- [可观测性](./backend/src/telemetry.rs)
