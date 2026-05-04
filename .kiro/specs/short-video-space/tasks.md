# 实现计划：short-video-space

## 概述

按 `space/short-video/implementation-breakdown.md` 的 Wave 顺序推进；P0 竖切优先：**项目级短视频目标配置 + 分镜 readiness 摘要 + 发布准备状态占位**，使 Space 成为可调度入口。测试范围遵循仓库 AGENTS.md：涉及 `backend/` 与 `frontend/` 时在提交前跑 `bash scripts/refactor-check.sh`。

## 任务

- [ ] 1. Wave 1 — 项目级短视频目标配置（后端模型 + API）
  - 项目扩展或等价存储：读写 `mode`、`video_ratio`、`target_market`、`target_platforms`、`duration_strategy`、`voice_profile`、`subtitle_style`、`bgm_strategy`
  - 供脚本、分镜、导出、发布读取的单一配置源
  - 测试：对应模块 `cargo test` 或契约 smoke（按实际落点选择最小集）
  - _需求: 2_

- [ ] 2. Wave 1 — 项目级短视频目标配置（前端 Space 面板）
  - 配置表单、校验、保存；展示创作模式摘要与默认市场/平台
  - 测试：`flutter test` 最小 widget / golden（若有）
  - _需求: 2, 9.4_

- [ ] 3. Wave 2 — 分镜 readiness 聚合接口
  - 聚合检查项：基础信息、脚本/提示词上下文、参考图或关键帧、候选确认、进行中任务等（与现有字段映射）
  - 测试：聚合逻辑单元测试 + API smoke
  - _需求: 3_

- [ ] 4. Wave 2 — 候选资产状态 `pending` / `linked` / `ignored`
  - 若现有模型可承载则扩展枚举/字段；否则增量迁移
  - 测试：状态迁移与 readiness 联动单测
  - _需求: 3_

- [ ] 5. Wave 2 — 前端 readiness 与候选摘要
  - 项目级 readiness 摘要；分镜工作区未就绪原因；候选确认摘要卡
  - 测试：widget / 导航 smoke
  - _需求: 3, 9.4_

- [ ] 6. Wave 3 — 成片装配域与导出前检查（后端）
  - 读取已选视频、旁白、字幕、BGM；导出前缺失项与版本确认检查
  - 测试：导出检查单元测试
  - _需求: 4_

- [ ] 7. Wave 3 — 成片装配入口与检查摘要（前端）
  - Space 入口、按剧本顺序缺失列表、任务失败可行动原因与回跳
  - 测试：widget smoke
  - _需求: 4_

- [ ] 8. Wave 4 — 发布域数据模型与迁移
  - `publish_profiles`、`publish_drafts`、`publish_targets`、`publish_jobs`、`publish_attempts`（可按竖切分步合并迁移）
  - 测试：迁移 + repository smoke
  - _需求: 5_

- [ ] 9. Wave 4 — 发布准备校验与 `publish` 任务状态机
  - 校验：比例、时长、标题、封面、标签、必填字段
  - 状态：`queued` → `validating` → `uploading` → `platform_processing` → 终态（含 `partial_failed`、`retrying`）
  - 测试：状态机单元测试
  - _需求: 5_

- [ ] 10. Wave 4 — 发布 API、adapter 抽象与 worker 骨架
  - 独立 `publish` 路由；`publish adapter` trait/模块；worker 消费 `publish_jobs`（首轮可 mock 上传）
  - 测试：adapter mock 集成测试
  - _需求: 5, 7_

- [ ] 11. Wave 4 — 前端发布准备占位与发布单列表
  - 发布准备面板、发布单列表、平台状态视图（半自动/自动说明）
  - 测试：widget smoke
  - _需求: 5, 9.4_

- [ ] 12. Wave 5 — 首批平台 adapter（2–3 个代表平台）
  - 建议首轮：YouTube Shorts、TikTok、哔哩哔哩、抖音中择 2–3 个验证竖屏工作流
  - 字段映射、约束校验、错误归一化
  - 测试：各 adapter 契约单测（不上传真实生产）
  - _需求: 7_

- [ ] 13. Wave 5 — 多平台文案改写与排程
  - Agent 生成差异化标题/简介/标签/时间建议；adapter 校验；定时与多平台串行发布
  - 测试：文案生成 mock + 排程数据 roundtrip
  - _需求: 6_

- [ ] 14. Wave 6 — 发布结果回流
  - 回写平台 id、链接、时间、失败原因、重试历史；项目级发布概览 API
  - 测试：回流写入与查询 smoke
  - _需求: 6_

- [ ] 15. OpenAPI / 前端 rust_api 与 Space 注册
  - 导出新端点；Dart 模型与调用；`shell` 或等价处注册 Section（按仓库现有模式）
  - 测试：`refactor-check.sh` 内 OpenAPI 与 analyze
  - _需求: 10_

- [ ] 16. Review — 对照 `space/short-video` 四文档核对缺口
  - 确认 P0/P1/P2 与边界（不做清单）仍与代码计划一致；更新本 tasks 勾选
  - 测试：无自动化
  - _需求: 8, 9_

- [ ] 17. 全量门禁
  - `bash scripts/refactor-check.sh`
  - _需求: 设计文档测试策略_

## 依赖与顺序说明

- Task 2 依赖 Task 1（配置先有 API）。
- Task 5 依赖 Task 3–4（readiness 与候选状态）。
- Task 7 依赖 Task 6。
- Task 9–11 依赖 Task 8；Task 12 依赖 Task 10。
- Task 13 依赖 Task 9–12 中的发布与 adapter 骨架。
- Task 15 随各 Wave 端点增量更新，或在 Wave 4 后集中补契约。

## 备注

- 开源参考仅作产品路径约束，**不**引入 `MoneyPrinterTurbo` / `Jellyfish` 源码依赖。
- 平台 API 权限与限流差异大，adapter 与文案层需预留「半自动确认」钩子。
