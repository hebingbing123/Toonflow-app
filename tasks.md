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
- [x] 压缩低信号记忆，避免重复注入上下文

## Phase D - Token ROI Optimization

- [x] 盘点当前生成链路里最浪费 token 的重复上下文
- [x] 优先压缩导演手册、角色锚点、阶段历史的重复注入
- [x] 检查低风险 / 高风险镜头预算分流是否还可继续细化
- [x] 验证 token 压缩后是否出现质量回退

## Phase E - Missing Feature Completion

- [x] 如果现有功能已基本无缺口，再 review 是否还缺少应有能力
- [x] 收敛“短剧生成”主流程的操作步数，避免用户在项目 / 剧本 / 分镜 / 视频工作台之间频繁跳转
- [x] 评估是否能把“生成默认提示词 -> 应用建议 -> 提交视频生成 -> 刷新结果”压成更短的一条动作链
- [x] 优先补能直接提升短剧质量而不是增加表面功能复杂度的能力
- [x] 完成后再次 review，决定是否继续深挖当前方向或切换到新高收益点

## Phase F - Highest Priority Dubbing Parity

- [ ] 对照 `master` 梳理旧仓库 TTS / Audio 能力边界，明确哪些已经存在、哪些只是接口壳子
- [ ] 把当前“旁白文案 + voiceover sidecar”升级成正式配音链路设计，不再把它视为低优先级增强
- [ ] 明确最小可交付路径：旁白文本 -> TTS 请求 -> 音频资产回写 -> 成片装配可消费
- [ ] 优先补单供应商 TTS 打通，不先做多供应商复杂编排
- [ ] 给配音链路补状态可见性与失败重试，避免生成成功但没有可复用音频资产
- [ ] 完成后再 review 是否还缺“音频和视频装配一致性”或“声线 / 情绪控制”补口

## 交付节奏

- [x] 每完成一个主要阶段，提交一次小步 commit
- [x] 每轮提交前只运行本次改动对应的最小必要验证
- [x] 全部功能与质量优化阶段接近完成后，再统一执行一次全量检查

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
- [x] 简化分镜批量出图默认路径：
  - 主按钮改为“一键批量出图”，与诊断建议保持一致
  - 未手动选择分镜时自动抓取已具备可用提示词的分镜入队
  - 继续把预览 / 下载 / 导出保留为显式选择动作，避免误操作
- [x] 简化视频结果确认后的后续动作：
  - 单独展示“当前已选视频”，减少用户判断哪条结果真正生效的心智负担
  - 候选结果直接提供“设为当前视频 / 局部返工”，少一次来回找入口
  - 当前已选视频旁直接保留导出与删除动作，缩短确认成片前的操作路径
- [x] 自动挂接项目级记忆瘦身与资产锚点去重：
  - 视频 prompt 生成前自动执行 project-level memory budget optimize，先剔除低信号 / 重复记忆再组 prompt
  - 诊断里区分低信号、重复、纯视觉三类瘦身来源，便于继续 review token ROI
  - 脚本角色 / 场景 / 道具锚点在进入预算前先按资产身份去重，避免多版本同名锚点重复注入
- [x] 对照 `master` 复核配音链路现状：
  - 旧仓库存在 `AiAudio` / `ttsRequest` / `ttsDubbing` 部署位与供应商模型定义
  - 但现有证据更接近“供应商适配入口 + 音频能力占位”，不是已完整打通的正式短剧配音工作流
  - 因此当前重构分支仍需把“正式配音链路”提升为最高优先级补齐项
