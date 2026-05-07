# 路线图：Rust 后端领域 + Harness

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`rust-backend-mvp`、`harness-rust-core`。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| PG + SQLx、核心 REST 竖切 | `baseline_done` | `rust-backend-mvp` YAML completed |
| Harness WS：tools / agent / 权限 / observe 挂钩 | `baseline_done` | `harness-rust-core` YAML completed |
| 契约烟雾与部分 PG 合约测试 | `baseline_done` | 见 `backend/src/app/contract_smoke_tests`、`pg_contract_tests` |

## 下一阶段（母文档已写明「仍缺」）

### rust-backend-mvp 加深

| 内容 | 状态 | 备注 |
|------|------|------|
| 更广端到端契约矩阵（关键用户路径） | `next` | YAML 正文「仍缺更广…矩阵」 |
| `video_count` 等与统计语义彻底对齐产品 | `next` | 若产品定义变化则驱动 schema/API |

### harness-rust-core 加深

| 内容 | 状态 | 备注 |
|------|------|------|
| 用户上传 WASM 策略（配额、签名、审计） | `next` | YAML「仍缺…用户上传 WASM」 |
| 隔离执行进程池预热/回收 | `next` | 与 `HARNESS_ISOLATE_MAX_CONCURRENT` 运维策略 |
| LLM 流式工具调用融合 | `next` | 产品里程碑驱动 |
| Trace / 结构化观测管线（可选 OTel） | `next` | 与 `quality-bar`、运维 KPI 联动 |

## 验收

- 变更域跑 `yarn refactor:check`。
- 新增 WS 或 HTTP 工具必须更新 `docs/websocket-events.md` 与 OpenAPI（若暴露 REST）。
