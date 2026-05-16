# 错误处理重构示例

本文档展示如何使用新的错误处理辅助函数重构现有代码。

## 重构前（旧代码）

```rust
use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

pub(crate) async fn post_project_workbench_add_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchAddAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    
    // 手动验证输入
    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }
    let describe = body.describe.trim();
    if describe.is_empty() {
        return Err(ApiError::BadRequest("describe must not be empty".into()));
    }
    let asset_type = body.asset_type.trim().to_lowercase();
    if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
        return Err(ApiError::BadRequest(
            "type must be role, scene, or tool".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    crate::projects::routes::common::require_project_write_scope(&state, uid, project_id).await?;

    // 手动处理数据库错误
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // ... 更多数据库操作
    
    Ok(Json(WorkbenchAssetMutationResponse {
        message: "新增资产成功",
    }))
}
```

## 重构后（新代码）

```rust
use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::error::helpers::{db_error, validate_non_empty_string, validate_enum};
use crate::state::AppState;

pub(crate) async fn post_project_workbench_add_assets(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchAddAssetsBody>,
) -> Result<Json<WorkbenchAssetMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    
    // 使用辅助函数验证输入 - 更简洁，自动记录日志
    validate_non_empty_string(&body.name, "name")?;
    validate_non_empty_string(&body.describe, "describe")?;
    
    let asset_type = body.asset_type.trim().to_lowercase();
    validate_enum(&asset_type, &["role", "scene", "tool"], "type")?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    crate::projects::routes::common::require_project_write_scope(&state, uid, project_id).await?;

    // 使用 db_error 辅助函数 - 自动记录详细的错误日志
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| db_error("Failed to begin transaction", e))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| db_error("Failed to acquire advisory lock", e))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| db_error("Failed to get next numeric ID", e))?;

    // ... 更多数据库操作
    
    Ok(Json(WorkbenchAssetMutationResponse {
        message: "新增资产成功",
    }))
}
```

## 改进点

### 1. 更简洁的输入验证

**旧代码**：
```rust
let name = body.name.trim();
if name.is_empty() {
    return Err(ApiError::BadRequest("name must not be empty".into()));
}
```

**新代码**：
```rust
validate_non_empty_string(&body.name, "name")?;
```

### 2. 更好的枚举验证

**旧代码**：
```rust
let asset_type = body.asset_type.trim().to_lowercase();
if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
    return Err(ApiError::BadRequest(
        "type must be role, scene, or tool".into(),
    ));
}
```

**新代码**：
```rust
let asset_type = body.asset_type.trim().to_lowercase();
validate_enum(&asset_type, &["role", "scene", "tool"], "type")?;
```

错误消息自动生成：`"type must be one of: role, scene, tool"`

### 3. 自动错误日志记录

**旧代码**：
```rust
.map_err(|e| ApiError::DatabaseError(e.to_string()))?;
```

只记录错误消息，没有上下文信息。

**新代码**：
```rust
.map_err(|e| db_error("Failed to begin transaction", e))?;
```

自动记录详细的错误日志：
```
ERROR toonflow.db.error context="Failed to begin transaction" error="..." error_debug=...
```

### 4. 更好的错误追踪

使用 `db_error` 辅助函数，每个数据库操作都有明确的上下文信息，便于调试：

```rust
// 清楚地知道哪个操作失败了
.map_err(|e| db_error("Failed to acquire advisory lock", e))?;
.map_err(|e| db_error("Failed to get next numeric ID", e))?;
.map_err(|e| db_error("Failed to insert asset", e))?;
```

## 其他常见模式

### 范围验证

```rust
// 旧代码
if body.duration < 1 || body.duration > 300 {
    return Err(ApiError::BadRequest(
        "duration must be between 1 and 300".into()
    ));
}

// 新代码
validate_range(body.duration, 1, 300, "duration")?;
```

### 自定义验证

```rust
// 旧代码
if body.age < 18 {
    return Err(ApiError::BadRequest("age must be at least 18".into()));
}

// 新代码
validate_input(body.age >= 18, "age must be at least 18")?;
```

### 内部错误处理

```rust
// 旧代码
let data = serde_json::from_str(&json_str)
    .map_err(|_| ApiError::Internal)?;

// 新代码
let data = serde_json::from_str(&json_str)
    .map_err(|e| internal_error("Failed to parse JSON", e))?;
```

## 迁移建议

1. **优先重构高频 API**：先重构使用频率高的 API 端点
2. **逐步迁移**：不需要一次性重构所有代码，可以逐步迁移
3. **保持一致性**：新代码统一使用辅助函数
4. **测试验证**：重构后运行测试确保行为一致

## 总结

使用新的错误处理辅助函数可以：

- ✅ 减少样板代码
- ✅ 提高代码可读性
- ✅ 自动记录详细的错误日志
- ✅ 统一错误处理模式
- ✅ 更容易调试和追踪问题
