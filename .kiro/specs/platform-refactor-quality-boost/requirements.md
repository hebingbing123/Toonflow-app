# 需求文档：platform-refactor-quality-boost

## 概述

在三轮已完成优化（ai-drama-quality-optimization、drama-platform-completion、drama-quality-benchmark-ops）的基础上，推进第四轮全面优化：

1. **文件拆分**：超大文件按职责分层拆分，单文件 ≤ 800 行，不平铺
2. **功能补完**：补完三个 spec 中未完成的功能（`[ ]`/`[~]` 任务）
3. **质量提升**：强化反 AI 痕迹检测、人物情绪真实感
4. **Token 优化**：在不降低质量的前提下收紧记忆注入范围
5. **Benchmark 基建**：补完缺失的四个 benchmark 模块

## 核心约束

- 质量优先于 token 节省
- 记忆系统按用户/项目严格隔离
- 每次只测试对应修改范围（最小化测试）
- 项目未上线，直接修改无需兼容

---

## 需求 1：文件拆分

### 1.1 video_prompt_memory/mod.rs（447KB / ~12000行）
- **现状**：`backend/src/production/workbench/video_prompt_memory/mod.rs` 约 12000 行，是全项目最大文件
- **目标**：拆分后 mod.rs ≤ 800 行（barrel），各子模块 ≤ 800 行
- **约束**：已有 brief.rs、observation.rs、rejected.rs、auto_scope.rs 保持不动；内部函数耦合度高，优先提取测试块和独立性强的模块

### 1.2 sub_agent.rs（91KB）
- **现状**：`backend/src/harness/sub_agent.rs` 约 2500 行，包含所有子 Agent 调度逻辑
- **目标**：拆分为 mod.rs + spec.rs + script.rs + production.rs + memory.rs + scope.rs，各文件 ≤ 800 行
- **约束**：保持原有公共 API 不变

### 1.3 quality_gate.rs（40KB）
- **现状**：`backend/src/production/quality_gate.rs` 约 1000 行
- **目标**：拆分为 quality_gate/ 目录，包含 mod.rs + rules.rs + enforce.rs + anti_ai.rs + attribution.rs

### 1.4 quality/feedback.rs（34KB）
- **现状**：`backend/src/prompting/quality/feedback.rs` 约 850 行
- **目标**：拆分为 feedback_video.rs + feedback_generic.rs + feedback_memory.rs，原 feedback.rs 改为 barrel

### 1.5 patch/dispatch.rs（26KB）
- **现状**：`backend/src/production/patch/dispatch.rs` 约 650 行
- **目标**：拆分为 dispatch_scope.rs + dispatch_model.rs + dispatch_attribution.rs，原 dispatch.rs 改为 barrel

### 1.6 前端 quality_reviews/support.dart（45KB）
- **现状**：`frontend/lib/quality_reviews/support.dart` 约 1100 行
- **目标**：拆分为 support_models.dart + support_filters.dart + support_stats.dart + support_actions.dart，support.dart 改为 barrel

### 1.7 前端 storyboard_editor/actions.dart（31KB，part of home_page）
- **现状**：`frontend/lib/storyboard_editor/actions.dart` 约 780 行，是 `part of home_page.dart`
- **目标**：提取 patch_helpers.dart + video_helpers.dart + quality_helpers.dart（普通 Dart 文件），actions.dart 缩减到 ≤ 200 行

---

## 需求 2：功能补完

### 2.1 质量评审驱动持续优化（drama-platform-completion 任务 15）
- 在 `prompting/quality/` 新增 `bad_case_stats.rs`，按 `bad_case_category` 聚合 top-5
- 为 `QualityReview` 补充 `suggested_action` 字段，写入时从 `bad_case_category` 自动映射
- 新增 `GET /api/v1/quality/bad-case-stats?projectId=&limit=5` 端点
- 在 `stage-pass-rate` 端点增加可选 `skillVersionHash` 参数，支持版本对比

### 2.2 Benchmark 后端缺失模块（drama-quality-benchmark-ops 任务 6-9）
- `benchmark/review_queue/`：create/submit/skip 三个端点，防重复创建
- `benchmark/observation_assets/`：ingest/govern/counters，去重用相似度 > 80%
- `benchmark/memory_profiles/`：MemoryBudgetProfileSnapshot + ROI 对比摘要端点
- `benchmark/promotion_gate/`：四态决策（blocked/needs_review/approved/approved_limited）+ 提升为新基线

### 2.3 前端 Benchmark 工作台（drama-quality-benchmark-ops 任务 10-13）
- 新建 `frontend/lib/benchmark/` 和 `frontend/lib/rust_api/benchmark/`
- 包含：基线样本列表、实验创建/运行、人工复核队列、放行门 + 趋势视图
- 在 `shell/build_sections_product.dart` 中注册新 section

### 2.4 前端质量评审补完 bad-case-stats 展示
- 在 `rust_api/quality/stats.dart` 新增 `fetchBadCaseStats()`
- 在 `quality_reviews/support_stats.dart` 新增 `BadCaseStatsPanel` widget
- 在 `quality_reviews/section_workbench.dart` 接入该 panel

---

## 需求 3：质量提升

### 3.1 强化反 AI 痕迹检测
- 人物锚点漂移检测：对比当前分镜描述与 StyleBible 角色锚点（发型/服装），相似度 < 70% 触发警告
- 情绪递进检测：同一角色连续 3 帧相同情绪强度 → 写入 delta_memory
- 视线方向一致性：对话场景中双方视线方向必须相对
- 严重命中（锚点漂移 + 视线错误同时出现）→ 接入 patch/dispatch 返工入口

### 3.2 强化视频提示词情绪真实感
- 在 `data/prompt_defaults/videoPromptGeneration.txt` 补充情绪具象化规则：10 种常见情绪各自的具体行为描述模板
- 在视频提示词生成逻辑中增加情绪强度梯度校验：同一场景内若所有分镜情绪强度相同，自动在首/中/末分镜插入强度变化标注
- 在 `data/skills/production_agent_execution.md` 补充"情绪具象化"执行规则（≤ 200 字）

---

## 需求 4：Token 优化

### 4.1 收紧记忆注入范围
- `style_bible` 层：按当前分镜涉及角色名过滤，只注入相关角色段落
- `stage_summary` 层：只注入当前阶段摘要，不注入其他阶段
- 连续返工注入：改为"失败原因(≤120字) + 修复目标(≤60字) + 局部上下文"
- 在 `metering/llm_usage.rs` 的 meta 字段中补记 `context_chars_injected` 和 `rework_mode`

---

## 需求 5：属性测试与契约测试

### 5.1 Benchmark 属性测试（6 个）
- 属性 1：基线样本隔离性（不同 project_id 的样本不互相污染）
- 属性 2：实验变体快照完整性（快照必须包含 5 个必填字段）
- 属性 3：ROI 对比同样本约束（对比必须基于同一 case_id 集合）
- 属性 4：守卫样本阻断性（guard_weight > 0.8 且严重退化 → 必须 blocked）
- 属性 5：观察资产去重稳定性（相同内容多次 ingest 只产生一条记录）
- 属性 6：低信号观察资产可降级归档（hit_count = 0 且 age > 30d → 可归档）
- 注释格式：`// Feature: drama-quality-benchmark-ops, Property {N}: {property_text}`

### 5.2 最小契约测试（3 个）
- bad-case-stats：写入 3 条 bad case → 查询 → 验证 top-1 正确
- review-queue：create → submit → 验证回写
- promotion-gate/evaluate：守卫样本退化 → 验证返回 blocked
