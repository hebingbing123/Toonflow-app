# 竖切任务：团队 Workspace MVP（个人路径已具备，本文件补 **enterprise + 成员**）

**前置**：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md) **§1 Workspace 基础竖切**（personal、`workspace_id` 落库、`/me` 返回 `current_workspace`）已完成。  
**母路线**：[`harness-rust-flutter.md`](./harness-rust-flutter.md)（组织/工作区「按阶段」）；本 MVP 不追求邮件营销级邀请，先 **可演示、可验收、可合并**。

**门禁**：涉及 `backend/` / `frontend/` / 迁移 / OpenAPI 时 **`yarn refactor:check`**。

---

## 五条验收标准（对外可说「团队 MVP 已收口」）

- [ ] **A1**：当前用户可 **创建** `workspace_type = enterprise` 的 workspace（名称必填），创建者自动为 `app_workspace_member.role = owner`。
- [ ] **A2**：`owner` / `admin` 可将 **另一已注册用户** 加入同一 workspace（`app_workspace_member`，`member` 或 `admin`）；首版允许 **按 `user_id`（UUID）** 添加，无需邮件链接（后续再加 invite 表）。
- [ ] **A3**：提供 **切换当前 workspace** 的 API（例如 `PATCH /api/v1/me/current-workspace` 或 `PUT /api/v1/workspaces/current`），服务端校验调用者 **必须是目标 workspace 的 member**。
- [ ] **A4**：`GET /api/v1/projects`（及文档中声明的「同里程碑内」至少一处写路径）在 **当前 workspace** 下按 **成员可见** 规则过滤：  
  `app_project.workspace_id = current_workspace_id` **且** 调用者为该 workspace 的 member（**不再**仅用 `owner_user_id = sub` 作为唯一条件；个人 workspace 下可与现网行为等价验证）。
- [ ] **A5**：Flutter：**workspace 选择器**（列出我有权限的 workspaces）+ 切换后 **刷新项目列表**；OpenAPI + `pg_contract` 覆盖新路径；`electron-node-parity.md` 若有对外承诺则补一行。

---

## 建议竖切顺序（可复制到 Issue）

| 序 | 内容 | 说明 |
|----|------|------|
| **M1** | 迁移（若缺）+ `POST /api/v1/workspaces` + `GET /api/v1/workspaces` | enterprise 创建；列表 = 我作为 member 的所有 workspace |
| **M2** | `POST /api/v1/workspaces/{id}/members` + RBAC | 仅 owner/admin；body `{ "user_id": "<uuid>", "role": "member" }` |
| **M3** | 切换 `current_workspace_id` | 见 A3；写 `app_user_profile` |
| **M4** | 项目列表 / 创建语义 | 创建项目时 `workspace_id` = **当前** workspace（enterprise 亦同）；列表见 A4 |
| **M5** | Flutter + 契约三件套 | `rust_api` + shell；测试与 parity |

---

## 实现触点（起步检索）

| 域 | 路径 |
|----|------|
| Workspace 保障 | `backend/src/workspaces/mod.rs`（扩展：非仅 personal） |
| Session | `backend/src/app/handlers/me.rs`、`handlers/types.rs` |
| 项目列表/创建 | `backend/src/projects/routes/handlers/create_list/*.rs` |
| 迁移 | `supabase/migrations/*workspace*`；`app_workspace.workspace_type` 已含 `enterprise` |
| 前端 | `frontend/lib/shell/workspace_context_view.dart`、`rust_api/system/auth.dart`、`home_page.dart` 数据源 |

---

## 非本 MVP（后续单列）

- 邮件/魔法链接邀请、待接受邀请表、org 级计费、RLS 与 **service role** 关系审计、跨 workspace 搜索、细粒度项目级 ACL。

---

## 完成定义（DoD）

- [ ] 五条 **A1–A5** 可演示 + `yarn refactor:check` 绿。
- [ ] [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 增加本节对应 **Phase / commit** 记录。
