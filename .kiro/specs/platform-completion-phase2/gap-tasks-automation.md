# Phase 2 主清单外 — 缺口与自动化（不重复 `tasks.md` 编号）

**目的**：跟踪 **`.kiro/specs/platform-completion-phase2/tasks.md` 未展开或正交** 的收尾项（文档、轻量验证脚本、与 S1/S2 配套的测试/审计），避免与 W1–F1 主任务行重复开条。

**原则**：主清单已有 **S1/S2** 时，本文件只放 **补遗、验证、文档锚点**；不另起一套「第二份 S1」。

---

## 状态总览

| ID | 内容 | 状态 | 说明 |
|----|------|------|------|
| GAP-DOC-1 | `docs/plans/platform-capabilities-backlog.md` **P-A2** 备注写上服务端保存视图同步（表名、`GET/PUT`、RLS） | [x] | 与实现一致，避免读者以为「仅存 SharedPreferences」 |
| GAP-VERIFY-1 | 仓库内 **`scripts/verify_saved_views_vertical_slice.sh`**：`cargo check` + `dart analyze`（保存视图相关路径） | [x] | 非完整 `yarn refactor:check`，供竖切迭代快速自检 |
| GAP-LINK-1 | 在 **`tasks.md`** Notes 区指向本文件 | [x] | 已增加 Notes 交叉引用 |
| GAP-C1-WS | **内容合规 WS 推送全双工测试**：`content_compliance_ws_full_duplex` — 订阅 WsNotifyHub、触发 sync、验证 WS 消息实时推送与格式 | [x] | C1.8 — 代码：`.../content_compliance_ws_push_roundtrip.rs`；脚本：`scripts/run_content_compliance_ws_tests.sh` |

---

## GAP-S1：与主清单 S1/S2 对齐的收尾（非重复实现）

| ID | 内容 | 状态 | 对应主清单 |
|----|------|------|------------|
| GAP-S1-TEST | **契约测试（PG）**：`search_saved_views_roundtrip` — `GET` 空列表、`PUT` 非法 `workspaceId`→403、`PUT` 成功、`GET` 回读、`POST /workspaces` 后带成员 `workspaceId` 再 `PUT` | [x] | S1.8 / S2.4 — 代码：`.../search_saved_views_roundtrip.rs`；**Colima + 本地 Supabase 已跑通**（见下方「本地 DB」补迁移说明） |
| GAP-S1-AUDIT | **可观测 / 合规审计**：DB 级 `app_*_audit` 行尚未建 | [~] | S1.6 — **已实现**：`PUT` 成功后 `tracing::info!`，`target = "openflow.platform_audit"`，`kind = search_saved_views_full_sync`，含 `user_id` / `requested_count` / `persisted_count`（供日志聚合；合规落库另立项） |
| GAP-S1-UX | 删除确认：已登录时提示跨端同步移除 | [x] | `frontend/lib/global_search/global_search_bar.dart` 删除对话框 |

---

## GAP-C1：内容合规 WebSocket 推送全双工测试

| ID | 内容 | 状态 | 对应主清单 |
|----|------|------|------------|
| GAP-C1-WS-DUPLEX | **全双工 WS 推送测试**：`content_compliance_ws_full_duplex` — 订阅 `WsNotifyHub`、调用 sync 端点、验证 `settings.notification.created/updated` 实时推送、验证消息格式与 payload 正确性 | [x] | C1.8 — 测试文件：`backend/src/app/pg_contract_tests/ops_suite/content_compliance_ws_push_roundtrip.rs` |
| GAP-C1-WS-SCRIPT | **执行脚本**：`scripts/run_content_compliance_ws_tests.sh` | [x] | 与 `run_search_saved_views_contract_test.sh` 同模式，需本地 PG + 契约用户种子 |

### 测试覆盖范围

新增的 `content_compliance_ws_full_duplex` 测试验证以下场景：

1. **创建新告警** → 验证收到 `settings.notification.created` WebSocket 消息
   - 验证消息格式：`event`、`data`、`notificationType`、`title`、`message`、`linkPath`、`payload`
   - 验证 payload 包含正确的 `stage`、`level`、`count`

2. **更新已有告警** → 验证收到 `settings.notification.updated` WebSocket 消息
   - 验证 count 更新正确
   - 验证 `readAt` 被重置为 null

3. **告警消退** → 验证收到 `content_compliance_alert_cleared` 通知
   - 验证 cleared 通知格式
   - 考虑节流策略可能跳过

4. **多个告警同时推送** → 验证批量同步时每个告警都收到独立的 WebSocket 消息
   - 验证所有告警的 stage 都被正确推送

### 与现有测试的关系

- **现有测试**（`content_compliance_ws_push_create_update_cleared` 等）：验证数据库状态与 REST 响应一致性
- **新增测试**（`content_compliance_ws_full_duplex`）：验证 WebSocket 推送的完整流程，包括实时消息接收

两者互补，共同确保内容合规通知系统的完整性。

---

## 自动化执行记录

执行方式（项目根）：

```bash
./scripts/verify_saved_views_vertical_slice.sh
```

**本地 Docker / Supabase 已启动时**跑完整 PG 契约（需已 `supabase db reset` 或迁移含 `app_user_search_saved_view`，且 `auth.users` 中存在契约用户种子 —— 与同目录其它 `#[ignore]` PG 测试一致）：

```bash
./scripts/run_search_saved_views_contract_test.sh
```

（脚本会 `source env/.env.dev` 读取 `DATABASE_URL` / `SUPABASE_JWT_SECRET`；若端口不是 `64322`，请改 `env/.env.dev` 或自行 export。）

**Colima + Supabase 本地**：`colima status` 为 running 且 `supabase status` 出 DB URL 后，`127.0.0.1:64322` 应可连。若 `supabase migration up` 中途失败（例如某条迁移依赖尚未创建的表），契约测试可能缺列 —— 典型：`operational_status`（补跑 `20260510143000_app_user_profile_governance.sql`）、`app_user_search_saved_view`（补跑 `20260522100000_app_user_search_saved_view.sql`）；契约用户需在 `auth.users`：`aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`（见 `backend/tests/E2E_REGRESSION_TESTS.md`，注意列名为 `confirmed_at` 等 Supabase 版本差异）。上述补齐后，`cargo test search_saved_views_roundtrip -- --ignored` 已在 Colima 环境 **通过**。

| 时间 | 命令 | 结果 |
|------|------|------|
| 2026-05-11 | `./scripts/verify_saved_views_vertical_slice.sh` | **exit 0**：`cargo check` 通过（仓库既有 deprecation warnings）；`dart analyze` 覆盖路径 **No issues found** |
| 2026-05-11 | `cargo test search_saved_views_roundtrip --no-run` | **exit 0**：契约测试目标编译通过（未执行运行时 DB 用例） |
| 2026-05-11 | Colima running + `cargo test search_saved_views_roundtrip -- --ignored` | **exit 0**：1 passed（补 schema / 契约用户后） |

**内容合规 WebSocket 推送测试**：

```bash
./scripts/run_content_compliance_ws_tests.sh
```

| 时间 | 命令 | 结果 |
|------|------|------|
| 2026-05-22 | `cargo test content_compliance_ws_full_duplex --no-run` | **exit 0**：全双工 WS 测试编译通过 |
| 2026-05-22 | `cargo check --tests` | **exit 0**：所有测试代码编译通过 |
| 2026-05-22 | `yarn refactor:quick` | **exit 0**：快速门禁检查通过 |

---

*与 `tasks.md` 关系：主清单管里程碑与需求追溯；本文件管「主清单没写细、但实现已存在」的文档与轻量验证，避免任务重复。*
