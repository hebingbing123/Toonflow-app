# Toonflow `frontend` (Flutter)

桌面 + Web（**无 iOS/Android** 目标）。通过可配置 **`API_BASE_URL`** 连接 Rust 后端。

## 运行

```bash
cd frontend
flutter run -d chrome          # Web
flutter run -d macos           # macOS 桌面
```

默认 API：`http://127.0.0.1:8666`。覆盖示例：

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8666
```

首页按钮会请求 `GET {API_BASE_URL}/api/v1/health`。
