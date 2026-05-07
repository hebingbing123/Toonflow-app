# 路线图：Flutter 产品壳与工作台

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`flutter-shell`。

执行进度对照：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)（项目编辑器 / Agent 工作台 / 短剧空间等）。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| 可配置 baseUrl、桌面 + Web 连 Rust | `baseline_done` | |
| Projects / script / production / tasks / quality / short-video 等产品入口 | `baseline_done` | YAML 长描述已概括 |

## 下一阶段

| 内容 | 状态 | 备注 |
|------|------|------|
| `short_video_space/*` 静态分析告警清零 | `next` | `toonflow-platform-progress.md`「已知阻塞」曾提及 |
| Web：CORS / token / 深链方案文档化 | `next` | 与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) 联动 |
| 大屏信息架构（减少单文件复杂度） | `next` | 维持 ≤800 行文件 guideline |

## 验收

- `flutter analyze`、`flutter test`（门禁脚本已包含）。
