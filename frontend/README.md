# Toonflow `frontend` (Flutter)

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

本地全链路（登录 → `GET /api/v1/me` → WebSocket）需与 `supabase start` 一致的项目 URL 与 **anon key**（`supabase status`）：

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://127.0.0.1:8666 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=eyJ...你的anon密钥
```

首页提供：`GET /api/v1/health`、邮箱密码登录/注册、`GET /api/v1/me`（Bearer）、`WebSocket` 探针（`?access_token=` + `agent.script.attach` + `agent.chat.send`，以及 **`harness.tool.invoke`**：`echo`、**`skills.read`**（使用上方 Skill path 输入框，默认同 REST 示例路径））。
