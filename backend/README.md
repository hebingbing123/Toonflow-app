# Toonflow `backend` (Rust)

Axum HTTP 服务，默认端口 **8666**（环境变量 `PORT` 可覆盖）。

## 开发与运行

```bash
cd backend
cp .env.example .env   # 可选
cargo run
```

健康检查：

- `GET http://127.0.0.1:8666/health`
- `GET http://127.0.0.1:8666/api/v1/health`

## 技能资产

Harness 用 Markdown 技能位于 **`data/skills/`**（由仓库根目录 `data/skills` 复制而来；过渡期 Node 栈仍可使用根目录副本）。

## 路线图

见仓库 [`docs/plans/harness-rust-flutter.md`](../docs/plans/harness-rust-flutter.md)。
