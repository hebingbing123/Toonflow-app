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

## 下一阶段（建议）

| ID | 内容 | 状态 | 备注 |
|----|------|------|------|
| CORS / WS 反代 | 生产域名下 WS 路径、HTTPS、缓存策略清单化 | `next` | 母文档 §0、§11 隐含项 |
| 迁移与备份 Runbook | `supabase/migrations` 发布顺序、回滚、备份验证 | `next` | 与 `postgres-ops`  operational 加深 |
| 错误码字典对外稳定 | 客户端依赖的 `code` 列表与变更日志 | `next` | 与 `api-contract` 文档同步 |

## 验收

- OpenAPI 可导出且与 `scripts/fixtures/openapi_baseline.yaml` 一致。
- `docs/websocket-events.md` 与实现一致（有变更则随门禁更新）。
