# Studio Ops 仪表板

本地/预发只读健康快照（任务 28）。

## 生成静态页

```bash
chmod +x scripts/studio_ops_dashboard.sh
STUDIO_API_BASE_URL=http://127.0.0.1:8666 ./scripts/studio_ops_dashboard.sh
open docs/ops/studio-ops-dashboard.html
```

## 探针脚本（CI / cron）

```bash
./scripts/studio_ops_health_check.sh
```

`STUDIO_API_BASE_URL` 默认 `http://127.0.0.1:8666`，探测 `/health`、`/ready`、`/version`。

Web 告警（PagerDuty 等）仍接团队运维栈；本仓库交付 **探针 + 静态仪表板**，不托管 SaaS 告警。
