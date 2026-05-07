# 路线图：仓库 / 契约 / 基础设施

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`git-branch`、`monorepo-layout`、`api-contract`、`postgres-ops`、`supabase-auth`。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| 重构分支 workflow | `baseline_done` | YAML `git-branch` completed |
| 单仓 `backend/` + `frontend/` | `baseline_done` | `monorepo-layout` |
| REST `/api/v1`、OpenAPI、WS 文档 | `baseline_done` | `api-contract`；门禁见 `yarn refactor:check` |
| Supabase Postgres / Auth 集成模型 | `baseline_done` | `postgres-ops`、`supabase-auth`（第一版无 BFF） |

## 下一阶段（必做）

| ID | 内容 | 状态 | 备注 |
|----|------|------|------|
| CORS / WS 反代 | 生产域名下 WS 路径、HTTPS、缓存策略清单化 | `next` | 母文档 §0、§11；**必做**上线前置 |
| 迁移与备份 Runbook | `supabase/migrations` 发布顺序、回滚、备份验证 | `next` | **必做**运维交付 |
| 错误码字典对外稳定 | 客户端依赖的 `code` 列表与变更日志 | `next` | **必做**契约维护 |

## 验收

- OpenAPI 可导出且与 `scripts/check_openapi_drift.sh` 所用 baseline（`scripts/fixtures/openapi_baseline.yaml`）一致。
- `scripts/check_rust_api_consistency.sh`（由 `yarn refactor:check` 调用）无 drift。
- `docs/websocket-events.md` 与实现一致（有变更则随门禁更新）。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。

### WP-A：生产 CORS / WebSocket 反代清单

| 项 | 内容 |
|----|------|
| **目标** | 把「浏览器 Web 客户端连线上 Rust」所需的反代、CORS、WS 升级、缓存策略写成可执行清单，减少部署猜谜。 |
| **依赖** | 已有 Flutter 可配置 `baseUrl`；TLS 证书与域名由运维提供。 |
| **PR 切片** | （1）**必做**：新建或充实 `docs/plans/deploy-web-client.md`（或等价单一真源），写清单与反代片段；（2）**必做**：生产路径将 `CorsLayer` 从 `Any` 改为 env 可控允许列表（单独 PR），默认值仅覆盖本地/dev。 |
| **触点** | `backend/src/app/router/build.rs`（CORS）；`docs/plans/harness-rust-flutter.md` §0（连接模型）；Nginx/Caddy 示例片段写入同一 Runbook。 |
| **测试** | 本地 `flutter run -d chrome` 指向 staging `baseUrl`；验证 REST + WS 握手；CORS 变更须补契约烟雾或书面集成验收步骤。 |
| **回滚** | CORS 配置回退上一提交；反代层仅文档变更无运行时回滚。 |

### WP-B：迁移与备份 Runbook

| 项 | 内容 |
|----|------|
| **目标** | `supabase/migrations` 发布顺序、灰度期间双写/只读策略（若有）、备份与恢复演练步骤可查。 |
| **依赖** | 托管 Supabase 或自管 PG 的连接串与备份工具权限。 |
| **PR 切片** | （1）**必做**：Runbook 文档；（2）**必做**：迁移版本一致性自动化——`scripts/` 只读检查 **或** CI workflow 步骤，至少一种入库且默认会跑（可与现有 refactor 门禁对齐）。 |
| **触点** | `supabase/migrations/`；[`database-migration-history-policy.md`](./database-migration-history-policy.md)。 |
| **测试** | 在 staging 执行「从备份恢复 → 跑迁移 → smoke」桌面演练并记录耗时。 |
| **回滚** | 按 Runbook 执行 down 迁移或从备份恢复（事先定义何种变更允许 down）。 |

### WP-C：错误码字典与变更日志

| 项 | 内容 |
|----|------|
| **目标** | 客户端依赖的 JSON `code` 字段有稳定清单；破坏性变更走文档或 semver 约定。 |
| **依赖** | 现有错误构造集中在 `backend/src/error/`（或等价模块）。 |
| **PR 切片** | （1）**必做**：维护 `docs/plans/api-error-codes.md` 或由脚本自 OpenAPI/代码生成并入库；（2）**必做**：Flutter `rust_api` 凡硬编码 `code` 映射处加注释链接真源表。 |
| **触点** | OpenAPI 导出；`backend/src/error/`；`backend/src/openapi_spec/`（摘要字段变更须同步）。 |
| **测试** | `yarn refactor:check`；抽查若干 4xx/5xx 响应与表一致。 |
| **回滚** | 文档回退；不建议对已发放客户端做静默改码（需版本协商）。 |
