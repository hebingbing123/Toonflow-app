# OpenFlow `frontend` (Flutter)

桌面 + Web（**无 iOS/Android** 目标）。通过可配置 **`API_BASE_URL`** 连接 Rust 后端；**Supabase Auth** 通过 `supabase_flutter`（可选，需 dart-define）。

## 运行

```bash
cd frontend
flutter pub get
flutter run -d chrome          # Web
flutter run -d macos           # macOS 桌面
```

默认 API：`http://127.0.0.1:8666`。仅测后端连通性时可不设 Supabase：

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8666
```

本地全链路（登录 → `GET /api/v1/me` → WebSocket）需与 `supabase start` 一致的项目 URL 与 **anon key**（`supabase status -o env`）。

推荐：`dart_defines.dev.json` 已与默认配置对齐（Rust **`API_BASE_URL` → 8666**；Supabase **`SUPABASE_URL` → 64321**，见 `supabase/config.toml`）。若你改了 Supabase 端口，请同步编辑该 JSON：

```bash
cd frontend
flutter run -d chrome --dart-define-from-file=dart_defines.dev.json
```

或手写 `--dart-define`（端口以 `supabase status` 为准）：

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8666 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:64321 \
  --dart-define=SUPABASE_ANON_KEY=eyJ...你的anon密钥
```

首页提供：`GET /api/v1/health`、邮箱密码登录/注册、`GET /api/v1/me`（Bearer）、`WebSocket` 探针（`?access_token=` + `agent.script.attach` + `agent.chat.send`，以及 **`harness.tool.invoke`**：`echo`、**`skills.read`**（使用上方 Skill path 输入框，默认同 REST 示例路径））。

## 功能开关（Feature Flags）

### Workspace 计费（Workspace Billing）

**开关名称**：`ENABLE_WORKSPACE_BILLING`  
**默认值**：`false`（用户级计费）  
**定义位置**：`lib/config.dart` → `kEnableWorkspaceBilling`

启用后，应用将调用 `/api/v1/me?v=2` API 并显示 workspace 级别的配额与计费信息。

```bash
# 开发环境启用
flutter run -d chrome --dart-define=ENABLE_WORKSPACE_BILLING=true

# 生产构建启用
flutter build apk --release --dart-define=ENABLE_WORKSPACE_BILLING=true
```

**相关文档**：
- [Feature Flag Guide](../docs/plans/workspace-billing-feature-flag-guide.md)（完整使用指南）
- [Migration Notice](../docs/plans/workspace-billing-migration-notice.md)（迁移时间线）
- [Cutover Runbook](../docs/plans/workspace-billing-cutover-runbook.md)（分阶段上线计划）

### 内部运维 Token（Internal Ops Token）

**开关名称**：`INTERNAL_OPS_TOKEN`  
**默认值**：空字符串（隐藏运维 UI）  
**定义位置**：`lib/config.dart` → `kInternalOpsToken`

用于访问 `GET /api/v1/jobs/queue/stats` 等内部运维接口。

```bash
flutter run -d chrome --dart-define=INTERNAL_OPS_TOKEN=your-secret-token
```
