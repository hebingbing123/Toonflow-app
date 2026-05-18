# Studio 交互契约（Wave 0b）

## 「超过竞品」的五条可测定义

1. **更少点击**：首条成片路径 ≤ 竞品 README 旅程 **−20%**（见 `studio-competitive-ui-benchmark.md` 基线表）。
2. **更少认知负担**：全局导航 ≤4 项；项目内单一步骤条；**禁止**产品路径默认「加载列表」按钮。
3. **更强反馈**：提交 job 后 ≤2s 内 Tray/步骤内出现进度（WS `generation.job.updated`，轮询兜底 30s）。
4. **更强恢复**：URL 保留项目+步骤；`clientDataVersion` 冲突显示 `StudioConflictBanner`。
5. **更强差异化**：质量门、九平台发布、工作区在 Studio 可达（非 Harness 探针）。

## 交互模式

| 模式 | 规则 |
|------|------|
| 自动数据 | 进入步骤/面板 `initState` 触发 load；SWR 缓存 |
| 单主 CTA | 每屏一个 `StudioPrimaryButton`；次要 `TextButton` / `⋯` |
| 乐观 UI | 配置/候选先更新 UI，失败回滚 + Snackbar |
| 任务闭环 | job → Tray → 完成 Snackbar + 刷新镜头 |
| 抽卡 | 网格候选 + ←→ + Enter 确认 |
| 批量 | 多选后底栏 `StudioBatchBar` |
| 错误 | 人话 + 重试 + 折叠诊断 id |
| 空状态 | `StudioEmptyState` + 一步 CTA |
| 骨架屏 | `StudioSkeleton` 优于无限转圈 |

## 快捷键

- **⌘K / Ctrl+K**：`StudioCommandPalette`（跳转项目/步骤/设置）
- **?**：快捷键帮助（分镜全屏，Wave 4）

## 禁止（产品路径）

- 默认 `showDialog` 打开项目详情
- Shell 层流水线 Strip + 15 项 Chip 导航
- 业务摘要用 monospace
- 手动「加载 xxx 列表」作为主路径

## 实现映射

| 契约 | 组件/模块 |
|------|-----------|
| 命令面板 | `design_system/ix/studio_command_palette.dart` |
| 冲突 | `design_system/ix/studio_conflict_banner.dart` |
| 任务 | `design_system/ix/studio_job_tray.dart` + `studio/job_center.dart` |
| Token/主题 | `design_system/tokens.dart`, `theme.dart` |
