# 错误消息国际化指南 / Error Message Internationalization Guide

## 概述 / Overview

本文档说明如何在 Toonflow 后端为错误消息提供中英文支持。

This document explains how to provide bilingual (Chinese/English) error messages in the Toonflow backend.

## 当前状态 / Current Status

### ✅ 已完成 / Completed

1. **ApiError 固定枚举** - `ApiError` 的固定错误类型（如 `NotFound`、`Unauthorized` 等）已支持根据 `Accept-Language` 返回中英文消息
2. **通用校验辅助函数** - `error/helpers` 模块中的 `validate_non_empty_string`、`validate_range`、`validate_enum` 已支持双语
3. **新增双语辅助函数** - 提供 `bad_request_i18n`、`forbidden_i18n`、`validate_positive`、`validate_max_length` 等常用模式

### 🚧 进行中 / In Progress

**其余 `BadRequest`/`Forbidden` 调用点** - 代码库中仍有大量直接使用英文字符串的错误调用点，需要逐域迁移到双语辅助函数。

## 使用方法 / Usage

### 1. 通用校验 / Common Validations

对于常见的输入校验场景，使用现有的双语辅助函数：

```rust
use crate::error::{
    validate_non_empty_string,
    validate_range,
    validate_enum,
    validate_positive,
    validate_max_length,
};

// 验证非空字符串
validate_non_empty_string(&body.name, "name")?;

// 验证数值范围
validate_range(body.duration, 1, 300, "duration")?;

// 验证枚举值
validate_enum(&body.format, &["mp4", "mov", "webm"], "format")?;

// 验证正数
validate_positive(body.id, "id")?;

// 验证最大长度
validate_max_length(&body.description, 500, "description")?;
```

### 2. 自定义错误消息 / Custom Error Messages

对于需要自定义消息的场景，使用 `bad_request_i18n` 或 `forbidden_i18n`：

```rust
use crate::error::{bad_request_i18n, forbidden_i18n};

// BadRequest 错误
if some_condition {
    return Err(bad_request_i18n(
        "field is required",
        "字段为必填项"
    ));
}

// Forbidden 错误
if !has_permission {
    return Err(forbidden_i18n(
        "access denied",
        "访问被拒绝"
    ));
}
```

### 3. 复杂场景 / Complex Scenarios

对于包含动态内容的错误消息，使用 `match current_locale()` 模式：

```rust
use crate::error::locale::{current_locale, ApiLocale};
use crate::error::ApiError;

let msg = match current_locale() {
    ApiLocale::En => format!("User {} not found", user_id),
    ApiLocale::Zh => format!("未找到用户 {}", user_id),
};
return Err(ApiError::NotFound(msg));
```

## 迁移指南 / Migration Guide

### 迁移优先级 / Migration Priority

1. **高优先级** - 用户直接可见的错误（API 端点、权限校验）
2. **中优先级** - 常见的输入验证错误
3. **低优先级** - 内部错误、调试信息

### 迁移步骤 / Migration Steps

#### Before (仅英文 / English only):
```rust
if body.id <= 0 {
    return Err(ApiError::BadRequest("id must be positive".into()));
}
```

#### After (双语 / Bilingual):
```rust
use crate::error::validate_positive;

validate_positive(body.id, "id")?;
```

或者 / Or:
```rust
use crate::error::bad_request_i18n;

if body.id <= 0 {
    return Err(bad_request_i18n(
        "id must be positive",
        "id 必须为正数"
    ));
}
```

## 常见模式 / Common Patterns

### 1. 正数验证 / Positive Number Validation

```rust
// Before
if body.project_id <= 0 {
    return Err(ApiError::BadRequest("projectId must be positive".into()));
}

// After
validate_positive(body.project_id, "projectId")?;
```

### 2. 非空验证 / Non-Empty Validation

```rust
// Before
if body.name.trim().is_empty() {
    return Err(ApiError::BadRequest("name must not be empty".into()));
}

// After
validate_non_empty_string(&body.name, "name")?;
```

### 3. 长度验证 / Length Validation

```rust
// Before
if body.description.len() > 500 {
    return Err(ApiError::BadRequest(
        "description must be at most 500 characters".into()
    ));
}

// After
validate_max_length(&body.description, 500, "description")?;
```

### 4. 枚举验证 / Enum Validation

```rust
// Before
let asset_type = body.asset_type.trim().to_lowercase();
if asset_type != "role" && asset_type != "scene" && asset_type != "tool" {
    return Err(ApiError::BadRequest(
        "type must be role, scene, or tool".into()
    ));
}

// After
validate_enum(&asset_type, &["role", "scene", "tool"], "type")?;
```

### 5. 权限错误 / Permission Errors

```rust
// Before
if !is_member {
    return Err(ApiError::Forbidden(
        "not a workspace member".into()
    ));
}

// After
if !is_member {
    return Err(forbidden_i18n(
        "not a workspace member",
        "不是工作空间成员"
    ));
}
```

## 测试 / Testing

所有双语辅助函数都包含单元测试，验证中英文消息的正确性：

```rust
#[tokio::test]
async fn validate_positive_zh_locale() {
    use crate::error::locale::{ApiLocale, REQUEST_LOCALE};
    
    let err = REQUEST_LOCALE
        .scope(ApiLocale::Zh, async {
            validate_positive(0, "id").unwrap_err()
        })
        .await;
    
    match err {
        ApiError::BadRequest(m) => assert_eq!(m, "id 必须为正数"),
        _ => panic!("expected BadRequest"),
    }
}
```

## Accept-Language 头 / Accept-Language Header

客户端可以通过 `Accept-Language` 请求头指定语言偏好：

```
Accept-Language: zh-CN,zh;q=0.9,en;q=0.8
Accept-Language: en-US,en;q=0.9
```

服务器会根据权重（q 值）选择最合适的语言。

## 待办事项 / TODO

以下模块仍需迁移到双语错误消息：

- [ ] `backend/src/assets/**` - 资产管理相关错误
- [ ] `backend/src/vendor/catalog/**` - 模型目录相关错误
- [ ] `backend/src/projects/**` - 项目管理相关错误
- [ ] `backend/src/workspaces/**` - 工作空间相关错误
- [ ] `backend/src/jobs/**` - 任务管理相关错误
- [ ] `backend/src/narrative/**` - 叙事内容相关错误
- [ ] `backend/src/auth/**` - 认证授权相关错误
- [ ] `backend/src/billing/**` - 计费相关错误
- [ ] `backend/src/settings/**` - 设置相关错误

## 参考 / References

- `backend/src/error/helpers.rs` - 双语辅助函数实现
- `backend/src/error/locale.rs` - 语言偏好解析
- `backend/src/error/api_error.rs` - ApiError 定义
