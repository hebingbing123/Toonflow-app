# Workspace Migration Notice（W11.3）

**用途**：当团队 Workspace 能力进入默认发布面时，用这份文档向客户端、测试、运营说明“哪些行为和旧单用户语义不同”。  
总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) W11.3。  
路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。  
差异背景：[`electron-node-parity.md`](./electron-node-parity.md) §2.2。

## 1) 本次迁移影响什么

Workspace 上线后，以下语义以 **workspace 成员关系** 为主，不再只看 `owner_user_id`：

- 项目列表与项目详情可见性
- 大多数 `project_id` 路径下的 CRUD / workbench / publish / production 能力
- `current_workspace` 切换与自动回退 personal
- 带 `project_uuid` / `project_numeric_id` 的 jobs 可见性
- Harness / WS attach 的 workspace 上下文

仍然保留用户级口径的能力：

- Agent memory（`scope = user`）
- usage / skills / quality 当前聚合口径
- 无 project 关联的 jobs 仍以 owner 个人视图为主

## 2) 客户端需要知道的行为变化

### 2.1 项目不再天然等于“当前登录用户自己”

旧 Electron / 单机 SQLite 语义更接近“项目 = 当前用户资产”。  
现在的默认语义是：

- **项目属于某个 workspace**
- **用户只要是该 workspace 成员，就可能看见项目**
- 但写权限仍受角色与具体策略限制

### 2.2 `current_workspace` 会被服务端自动修正

以下场景下，客户端不要假设当前 workspace 永远稳定不变：

- 当前 workspace 被归档
- 用户被移出当前 workspace
- profile 中残留了失效的 `current_workspace_id`

服务端会回退到 personal workspace，客户端应以 `/api/v1/me` 回读结果为准。

### 2.3 `403` 不再总等价于“这个项目不存在”

workspace 模式下常见两类结果：

- **`404`**：资源真不存在
- **`403`**：资源存在，但当前用户不是该 workspace 成员，或角色不允许该动作

客户端与测试脚本不要继续把所有失败都归类成“找不到”。

### 2.4 jobs 与本地输出路径不一定跟当前操作者绑定

对于带项目上下文的 jobs：

- 可见性来自项目所属 workspace
- 但本地 artifact / 通知仍可能按 `job.owner_user_id` 对齐

所以“我能看到 job”和“本地文件一定落到我名下目录”不是同一件事。

## 3) 发布前最低客户端检查项

在 workspace 默认发布前，客户端至少确认：

1. `GET /api/v1/me` 的 `current_workspace` 能驱动首屏上下文
2. workspace 切换后，项目列表、选中项目、WS attach 都会刷新
3. 非成员访问 workspace / project 时，UI 能正确处理 `403`
4. 当前 workspace 被服务端回退时，客户端不会卡死在旧上下文
5. 接受邀请成功后，团队工作区页能刷新出新 membership

## 4) 测试与灰度建议

建议至少跑以下三类账号：

1. **personal-only 用户**
   - 验证个人主路径零回归
2. **enterprise owner/admin**
   - 验证成员管理、项目共享、workspace 切换
3. **enterprise member**
   - 验证可见性正确，但高权限动作仍被拒绝

灰度期间重点观察：

- `403 forbidden` 是否显著上升
- `current_workspace` 自动回退是否导致前端缓存异常
- jobs / Harness attach 是否仍有 owner-only 残留逻辑

## 5) 回滚口径

如果 workspace 发布后出现严重问题，先按“是否涉及数据结构变化”分两类处理：

- **纯客户端 / handler 语义问题**：
  - 优先回滚应用层变更
  - 保留 `app_workspace*` 数据，不做 destructive rollback
- **严重授权问题**：
  - 先关闭相关入口或回滚最近发布
  - 再按 [`workspace-operations-runbook.md`](./workspace-operations-runbook.md) 做数据核查

不建议为了回滚体验而删除 workspace / member 数据。

## 6) 当前默认发布说明模板

可直接复用以下文案做内部发布说明：

> 本次版本将项目与大多数生产能力切换到 workspace 成员语义。  
> 用户可能首次看到“团队工作区”与“个人工作区”并存；若当前工作区失效，系统会自动回退到 personal。  
> 若遇到项目可见性变化、`403` 增多、邀请接受后上下文异常，请按 `workspace-operations-runbook.md` 排查。

## 7) 关联真源

- 任务勾选：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)
- 路线图入口：[`roadmap-workspace.md`](./roadmap-workspace.md)
- 运维排障：[`workspace-operations-runbook.md`](./workspace-operations-runbook.md)
- 安全边界：[`workspace-security-boundary.md`](./workspace-security-boundary.md)
