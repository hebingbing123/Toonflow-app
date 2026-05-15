# 实现计划：platform-refactor-quality-boost

## 概述

在三轮已完成优化的基础上，并行推进文件拆分、功能补完、质量提升、Token 优化和 Benchmark 基建。

**测试原则**：拆分类 Task 只跑 `cargo check`；新功能只跑对应单个测试；全量测试留到 Task 16。

## 任务

- [x] 1. 拆分 video_prompt_memory/mod.rs（~12000行）
  - 提取 `#[cfg(test)] mod tests { ... }` 块（~5000行）到 `tests.rs`
  - mod.rs 末尾改为 `mod tests;`
  - mod.rs 从 12029 行降到 7063 行，tests.rs 4968 行
  - 测试：`cargo check` 编译通过 ✓
  - _需求: 1.1_

- [x] 2. 拆分 sub_agent.rs（91KB）
  - 新建 `harness/sub_agent/` 目录
  - 拆分为：`mod.rs`（常量 + 公共入口）、`spec.rs`（SubAgentSpec + sub_agent_spec 路由）、`script.rs`（storySkeleton/adaptationStrategy/script/supervision）、`production.rs`（derive_assets/generate_assets/director_plan/storyboard_gen/storyboard_panel/storyboard_table/production_supervision）、`memory.rs`（AutoMemoryRow + 记忆读取/压缩/注入）、`scope.rs`（ScopeSignature + 构建逻辑）
  - 删除原 `harness/sub_agent.rs`，`harness/mod.rs` 改为 `mod sub_agent;`
  - 测试：`cargo check` 编译通过
  - _需求: 1.2_

- [x] 3. 拆分 quality_gate.rs + feedback.rs + patch/dispatch.rs
  - `quality_gate.rs` → `quality_gate/`：mod.rs + rules.rs + enforce.rs + anti_ai.rs + attribution.rs
  - `quality/feedback.rs` → feedback_video.rs + feedback_generic.rs + feedback_memory.rs，原 feedback.rs 改为 barrel
  - `patch/dispatch.rs` → dispatch_scope.rs + dispatch_model.rs + dispatch_attribution.rs，原 dispatch.rs 改为 barrel
  - 测试：`cargo check` 编译通过
  - _需求: 1.3, 1.4, 1.5_

- [x] 4. 拆分前端 quality_reviews/support.dart（45KB）
  - 拆分为：support_models.dart + support_filters.dart（barrel：diagnostics / memory / scope 子模块）+ support_stats.dart + support_actions.dart
  - support.dart 改为 barrel（export 上述四个文件）
  - 测试：`flutter test test/quality_reviews_workbench_support_test.dart`
  - _需求: 1.6_

- [x] 5. 拆分前端 storyboard_editor/actions.dart（31KB，part of home_page）
  - 新建 `storyboard_editor/actions/patch_helpers.dart`（局部返工 dialog 逻辑）
  - 新建 `storyboard_editor/actions/video_helpers.dart`（视频生成/预览逻辑）
  - 新建 `storyboard_editor/actions/quality_helpers.dart`（质量门控触发逻辑）
  - actions.dart 保留为 `part of` 入口，缩减到 ≤ 200 行
  - 测试：`flutter test test/storyboard_workbench_support_test.dart`
  - _需求: 1.7_

- [x] 6. 后端补完质量评审驱动优化（bad-case-stats + suggested_action）
  - 在 `prompting/quality/` 新增 `bad_case_stats.rs`：按 `bad_case_category` 聚合 top-5
  - 在 `types.rs` 为 `QualityReview` 补充 `suggested_action` 字段，写入时自动映射
  - 新增 `GET /api/v1/quality/bad-case-stats?projectId=&limit=5` 端点
  - `stage-pass-rate` 端点增加可选 `skillVersionHash` 参数
  - 测试：`cargo test -p backend -- prompting::quality::tests`
  - _需求: 2.1_

- [x] 7. 补完 Benchmark 后端缺失模块（review_queue / observation_assets / memory_profiles / promotion_gate）
  - `benchmark/review_queue/`：mod.rs + handlers.rs（create/submit/skip）+ types.rs
  - `benchmark/observation_assets/`：mod.rs + handlers.rs（ingest/govern/counters）+ types.rs
  - `benchmark/memory_profiles/`：mod.rs + snapshot.rs + roi.rs
  - `benchmark/promotion_gate/`：mod.rs + decision.rs（四态决策）+ promote.rs
  - 每个模块注册到 `prompting/benchmark/mod.rs` 路由
  - 测试：每个模块只写一个 smoke test（创建 + 读取）
  - _需求: 2.2_

- [x] 8. 前端 Benchmark 工作台
  - 新建 `frontend/lib/rust_api/benchmark/`：index.dart + api.dart + models.dart
  - 新建 `frontend/lib/benchmark/`：section.dart + workbench_cases.dart + workbench_experiments.dart + workbench_review_queue.dart + workbench_gate.dart
  - 在 `shell/build_sections_product.dart` 注册新 section
  - 测试：`flutter test test/benchmark_workbench_support_test.dart`（最小 widget test）
  - _需求: 2.3_

- [x] 9. 强化反 AI 痕迹检测（anti_ai.rs）
  - 人物锚点漂移检测（对比 StyleBible 角色锚点，相似度 < 70% 触发警告）
  - 情绪递进检测（连续 3 帧相同情绪强度 → 写入 delta_memory）
  - 视线方向一致性（对话场景双方视线必须相对）
  - 严重命中 → 接入 patch/dispatch 返工入口
  - 测试：`cargo test -p backend -- production::quality_gate::anti_ai`
  - _需求: 3.1_

- [x] 10. 强化视频提示词情绪真实感
  - `data/prompt_defaults/videoPromptGeneration.txt` 补充 10 种情绪具象化规则
  - 视频提示词生成逻辑增加情绪强度梯度校验
  - `data/skills/production_agent_execution.md` 补充"情绪具象化"执行规则（≤ 200 字）
  - 测试：无需自动化测试（prompt 文件修改）
  - _需求: 3.2_

- [x] 11. Token 优化 — 收紧记忆注入范围
  - `sub_agent/memory.rs`（Task 2 拆出）：style_bible 按角色名过滤，stage_summary 按阶段过滤，返工注入收紧
  - `metering/llm_usage.rs` meta 字段补记 `context_chars_injected` 和 `rework_mode`
  - 测试：`cargo test -p backend -- settings::agent_memory`
  - _需求: 4.1_

- [x] 12. 属性测试补全（Benchmark 隔离与放行门，6 个属性）
  - 属性 1：基线样本隔离性
  - 属性 2：实验变体快照完整性
  - 属性 3：ROI 对比同样本约束
  - 属性 4：守卫样本阻断性
  - 属性 5：观察资产去重稳定性
  - 属性 6：低信号观察资产可降级归档
  - 注释格式：`// Feature: drama-quality-benchmark-ops, Property {N}: {property_text}`
  - 测试：`cargo test -p backend -- prompting::benchmark`
  - _需求: 5.1_

- [x] 13. 最小契约测试（bad-case-stats + review-queue + promotion-gate）
  - bad-case-stats roundtrip（写入 3 条 → 查询 → 验证 top-1）
  - review-queue roundtrip（create → submit → 验证回写）
  - promotion-gate/evaluate（守卫样本退化 → 验证 blocked）
  - 复用 `pg_contract_tests/common.rs`
  - 测试：`cargo test -p backend -- app::pg_contract_tests::ops_suite`
  - _需求: 5.2_

- [x] 14. 前端质量评审补完 bad-case-stats 展示
  - `rust_api/quality/stats.dart` 新增 `fetchBadCaseStats()`
  - `quality_reviews/support_stats.dart` 新增 `BadCaseStatsPanel` widget
  - `quality_reviews/section_workbench.dart` 接入该 panel
  - 测试：`flutter test test/quality_reviews_section_test.dart`
  - _需求: 2.4_

- [x] 15. Review — 检查三个 spec 是否有缺失功能
  - 逐一检查 drama-platform-completion requirements 18 组需求
  - 逐一检查 drama-quality-benchmark-ops requirements 9 组需求
  - 逐一检查 ai-drama-quality-optimization requirements 所有需求
  - 输出缺口清单（或确认无缺口）
  - 测试：无需自动化测试

- [x] 16. 全量门禁（refactor-check.sh + cargo test + flutter test）
  - `bash scripts/refactor-check.sh`
  - `cargo test` 全量后端测试
  - `flutter test` 全量前端测试
  - 测试：全量

## 备注

- Task 1 已完成（video_prompt_memory/mod.rs 测试块提取）
- Task 2 依赖 Task 1 完成（sub_agent.rs 中引用 video_prompt_memory 的导出）
- Task 9 依赖 Task 3 完成（anti_ai.rs 是 quality_gate/ 拆分后的子模块）
- Task 11 依赖 Task 2 完成（memory.rs 是 sub_agent/ 拆分后的子模块）
- 每次修改只测试对应范围，全量测试留到 Task 16
