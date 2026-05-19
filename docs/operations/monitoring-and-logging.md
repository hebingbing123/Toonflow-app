# 监控和日志系统

本文档描述 Openflow 应用的监控和日志系统架构及使用方法。

## 概述

Openflow 实现了全栈的可观测性解决方案，包括：

- **前端日志**：使用 `logger` 包记录用户操作和错误
- **后端追踪**：使用 `tracing` 和 OpenTelemetry 进行分布式追踪
- **性能指标**：记录关键业务指标（API 延迟、TTS 成功率、导出时长等）

## 前端日志

### 使用方法

前端使用全局单例 `appLogger` 进行日志记录：

```dart
import 'package:openflow_app/utils/app_logger.dart';

// 记录一般信息
appLogger.info('User logged in successfully');

// 记录错误
try {
  // 某些操作
} catch (e, stackTrace) {
  appLogger.error('Operation failed', e, stackTrace);
}

// 记录用户操作
appLogger.logUserAction('button_click', metadata: {
  'button_id': 'submit',
  'screen': 'login',
});

// 记录 API 调用
appLogger.logApiCall(
  '/api/v1/projects',
  'GET',
  statusCode: 200,
  duration: Duration(milliseconds: 150),
);

// 记录性能指标
appLogger.logPerformance(
  'render_frame',
  Duration(milliseconds: 16),
  metadata: {'frame_count': 60},
);
```

### 日志级别

支持以下日志级别（从低到高）：

- `trace`: 最详细的调试信息
- `debug`: 调试信息
- `info`: 一般信息（默认）
- `warning`: 警告信息
- `error`: 错误信息
- `fatal`: 致命错误

可以通过编译时环境变量设置日志级别：

```bash
flutter run --dart-define=LOG_LEVEL=debug
```

### 日志格式

日志输出包含以下信息：

- 时间戳（相对于应用启动时间）
- 日志级别（带表情符号）
- 日志消息
- 调用栈信息（错误日志）
- 元数据（如果提供）

## 后端追踪

### 基础配置

后端使用 `tracing` 和 `tracing-subscriber` 进行日志记录，支持控制台输出和 OpenTelemetry 导出。

#### 环境变量

- `RUST_LOG`: 设置日志级别（默认 `info`）
  ```bash
  RUST_LOG=debug cargo run
  ```

- `OPENFLOW_OTEL_EXPORT_ENABLED`: 启用 OTLP 导出（`1`/`true`/`yes`/`on`）
  ```bash
  OPENFLOW_OTEL_EXPORT_ENABLED=1
  ```

- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`: OTLP collector 地址（默认 `http://127.0.0.1:4317`）
  ```bash
  OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4317
  ```

- `OTEL_SERVICE_NAME`: 服务名称（默认 `openflow-server`）
  ```bash
  OTEL_SERVICE_NAME=openflow-api
  ```

### 使用方法

#### 基础日志

```rust
use tracing::{info, warn, error, debug};

// 记录信息
info!("Server started on port 8666");

// 记录警告
warn!(user_id = %user_id, "Rate limit approaching");

// 记录错误
error!(error = %e, "Database connection failed");

// 记录调试信息
debug!(request_id = %req_id, "Processing request");
```

#### 结构化日志

使用 `tracing` 的结构化字段：

```rust
info!(
    target: "openflow.api.request",
    method = %method,
    path = %path,
    status = %status_code,
    duration_ms = %duration.as_millis(),
    "Request completed"
);
```

#### Span 追踪

创建 span 追踪操作：

```rust
use tracing::{info_span, Instrument};

async fn process_request(req: Request) -> Response {
    let span = info_span!(
        "process_request",
        request_id = %req.id,
        user_id = %req.user_id,
    );
    
    async move {
        // 处理请求
        info!("Processing started");
        // ...
        info!("Processing completed");
    }
    .instrument(span)
    .await
}
```

### API 请求追踪中间件

所有 API 请求自动记录以下信息：

- HTTP 方法和路径
- 请求 ID（如果存在）
- 响应状态码
- 请求处理时长

中间件已集成到 `backend/src/middleware/tracing.rs`，可在路由配置中使用：

```rust
use axum::{Router, middleware};
use crate::middleware::tracing::trace_request;

let app = Router::new()
    .route("/api/v1/test", get(handler))
    .layer(middleware::from_fn(trace_request));
```

## 性能指标

### 后端指标

使用 `metrics` 模块记录关键业务指标：

```rust
use crate::metrics;
use std::time::Duration;

// 记录 API 请求
metrics::record_api_request(
    "/api/v1/projects",
    "GET",
    200,
    Duration::from_millis(150),
);

// 记录 TTS 生成
metrics::record_tts_generation(
    "openai",
    "alloy",
    true,
    Duration::from_secs(2),
    None,
);

// 记录导出任务
metrics::record_export_task(
    "mp4",
    "1080p",
    true,
    Duration::from_secs(30),
    Some(10_485_760),
    None,
);

// 记录批量操作
metrics::record_batch_operation(
    "batch_select",
    100,
    95,
    5,
    Duration::from_secs(3),
);

// 记录数据库查询
metrics::record_db_query(
    "select_shots",
    Duration::from_millis(50),
    Some(100),
);

// 记录缓存操作
metrics::record_cache_operation(
    "get",
    "user:123:profile",
    true,
    Duration::from_micros(500),
);
```

### 指标目标

所有指标使用结构化日志格式，包含以下目标（target）：

- `openflow.metrics.api`: API 请求指标
- `openflow.metrics.tts`: TTS 生成指标
- `openflow.metrics.export`: 导出任务指标
- `openflow.metrics.batch`: 批量操作指标
- `openflow.metrics.db`: 数据库查询指标
- `openflow.metrics.cache`: 缓存操作指标

可以通过 `RUST_LOG` 环境变量过滤特定指标：

```bash
# 只显示 API 指标
RUST_LOG=openflow::metrics::api=info

# 显示所有指标
RUST_LOG=openflow::metrics=info
```

## OpenTelemetry 集成

### 本地开发环境

使用 Docker 运行 OpenTelemetry Collector 和 Jaeger：

```bash
# 启动 Jaeger（包含 OTLP receiver）
docker run -d --name jaeger \
  -e COLLECTOR_OTLP_ENABLED=true \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  jaegertracing/all-in-one:latest

# 启用 OTLP 导出
export OPENFLOW_OTEL_EXPORT_ENABLED=1
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4317

# 启动应用
cargo run
```

访问 Jaeger UI：http://localhost:16686

### 生产环境

在生产环境中，建议使用专业的可观测性平台：

- **Jaeger**: 开源分布式追踪系统
- **Grafana Tempo**: 高性能追踪后端
- **Datadog**: 商业 APM 平台
- **New Relic**: 商业 APM 平台
- **Honeycomb**: 商业可观测性平台

配置示例：

```bash
# 使用 Grafana Cloud
export OPENFLOW_OTEL_EXPORT_ENABLED=1
export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=https://otlp-gateway-prod-us-central-0.grafana.net/otlp
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64-encoded-credentials>"
export OTEL_SERVICE_NAME=openflow-production
```

## 日志聚合和分析

### 推荐工具

- **ELK Stack** (Elasticsearch, Logstash, Kibana): 开源日志聚合
- **Grafana Loki**: 轻量级日志聚合
- **Datadog Logs**: 商业日志管理
- **Splunk**: 企业级日志分析

### 日志格式

后端日志使用 JSON 格式输出（生产环境推荐）：

```bash
# 使用 JSON 格式
RUST_LOG=info RUST_LOG_FORMAT=json cargo run
```

## 最佳实践

### 前端

1. **合理使用日志级别**：
   - `debug`: 开发调试信息
   - `info`: 用户操作、API 调用
   - `warning`: 可恢复的错误
   - `error`: 需要关注的错误
   - `fatal`: 致命错误

2. **避免敏感信息**：不要记录密码、令牌等敏感信息

3. **添加上下文**：使用 metadata 提供额外上下文

4. **性能考虑**：避免在高频操作中记录过多日志

### 后端

1. **使用结构化日志**：使用字段而不是字符串拼接

2. **添加 span**：为重要操作创建 span

3. **记录关键指标**：使用 `metrics` 模块记录业务指标

4. **错误处理**：记录错误时包含足够的上下文

5. **性能考虑**：
   - 使用异步日志
   - 避免在热路径中记录过多日志
   - 使用采样（sampling）减少追踪开销

## 故障排查

### 前端日志不显示

检查日志级别设置：

```bash
flutter run --dart-define=LOG_LEVEL=debug
```

### 后端日志不显示

检查 `RUST_LOG` 环境变量：

```bash
RUST_LOG=debug cargo run
```

### OTLP 导出失败

1. 检查 collector 是否运行：
   ```bash
   curl http://localhost:4317
   ```

2. 检查环境变量：
   ```bash
   echo $OPENFLOW_OTEL_EXPORT_ENABLED
   echo $OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
   ```

3. 查看应用日志中的错误信息

## 参考资料

- [tracing 文档](https://docs.rs/tracing/)
- [OpenTelemetry 文档](https://opentelemetry.io/docs/)
- [logger 包文档](https://pub.dev/packages/logger)
- [Jaeger 文档](https://www.jaegertracing.io/docs/)
