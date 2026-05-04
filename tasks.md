# 短剧生成完善化 tasks

基线原则：

- 先补功能闭环，再压 token。
- 质量优先于成本。
- 每次只测当前改动范围。
- 每轮结束后都再 review 一次是否还有更高收益优化点。

## Phase A - Workflow Gap Review

- [x] 盘点当前“生成 -> review -> 返工 -> 回写记忆”链路还缺哪些环节
- [x] 标注每个缺口对“人物稳定 / 情绪自然 / 穿帮率 / token 成本”的影响
- [x] 选出第一个最高 ROI 竖切，不等候额外确认直接开做

## Phase B - Quality Loop Closure

- [x] 检查质量 review 结果是否能稳定回写到视频专用记忆
- [x] 检查坏例分类是否足够支撑自动负向约束
- [x] 检查连续失败镜头是否已有明确“局部返工 / 归因模式”
- [x] 若缺失，补一条最影响出片质量的闭环能力

## Phase C - Memory Governance

- [x] 梳理 `agent_memory` 与 `video_prompt_memory` 的职责边界
- [x] 明确哪些信号允许自动写入，哪些必须拒绝或淘汰
- [x] 检查项目 / 用户 / agent / scope 隔离是否贯穿所有自动写入路径
- [ ] 压缩低信号记忆，避免重复注入上下文

## Phase D - Token ROI Optimization

- [x] 盘点当前生成链路里最浪费 token 的重复上下文
- [ ] 优先压缩导演手册、角色锚点、阶段历史的重复注入
- [x] 检查低风险 / 高风险镜头预算分流是否还可继续细化
- [ ] 验证 token 压缩后是否出现质量回退

## Phase E - Missing Feature Completion

- [x] 如果现有功能已基本无缺口，再 review 是否还缺少应有能力
- [x] 收敛“短剧生成”主流程的操作步数，避免用户在项目 / 剧本 / 分镜 / 视频工作台之间频繁跳转
- [x] 评估是否能把“生成默认提示词 -> 应用建议 -> 提交视频生成 -> 刷新结果”压成更短的一条动作链
- [ ] 优先补能直接提升短剧质量而不是增加表面功能复杂度的能力
- [ ] 完成后再次 review，决定是否继续深挖当前方向或切换到新高收益点

## 交付节奏

- [x] 每完成一个主要阶段，提交一次小步 commit
- [x] 每轮提交前只运行本次改动对应的最小必要验证
- [ ] 全部功能与质量优化阶段接近完成后，再统一执行一次全量检查

## 已完成进展记录

- [x] 修复 `quality review` 建单所有权与范围校验：
  - storyboard 目标必须落在用户拥有的 project/script scope 内
  - scoped `video/output` 目标必须解析到真实 storyboard numeric id
  - `jobId` 必须属于当前用户
- [x] 修复 benchmark 人工复核写回不影响下游放行门 / ROI 的问题：
  - 人工复核结果提升到 `score_summary` 顶层
  - `skip review` 会同步解除 `requires_human_review`
  - `submit/skip` 增加 pending 状态并发保护
- [x] 修复 benchmark 聚合统计误差：
  - stage ROI 基线均值改为使用自己的样本数
  - 未评分结果不再被当作 0 分 / 未通过污染 gate 与 ROI
- [x] 修复 agent memory 隔离与清理语义：
  - `clearType=message` 不再误删 summary
  - scoped tier 写入与查询都要求有效 `scopeSignature`
  - scoped 查询不再回落到更宽 project 记忆
- [x] 修复 quality review 聚合口径：
  - placeholder / diagnostics-only 评审不再污染 scored aggregates
  - storyboard review 必须带 project scope
- [x] 简化视频工作台默认生成路径：
  - 主按钮改为“一键生成视频”，明确自动处理提示词刷新 / 生成前建议 / 负向约束压缩 / 结果回刷
  - 手动提示词与刷新按钮降级为辅助入口，减少用户对多步骤的误感知
  - 提交时仅在存在唯一可用轨道时自动回填轨道 ID，少一步但不牺牲结果可控性
