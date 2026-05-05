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

- [x] 对照 `master` 梳理旧仓库 TTS / Audio 能力边界，明确哪些已经存在、哪些只是接口壳子
- [x] 把当前“旁白文案 + voiceover sidecar”升级成正式配音链路设计，不再把它视为低优先级增强
- [x] 明确最小可交付路径：旁白文本 -> TTS 请求 -> 音频资产回写 -> 成片装配可消费
- [x] 优先补单供应商 TTS 打通，不先做多供应商复杂编排
- [x] 给配音链路补状态可见性与失败重试，避免生成成功但没有可复用音频资产
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
- [x] 打通首版正式配音链路：
  - 新增 `POST /api/v1/production/workbench/generate-voiceover`，按 storyboard 批量入队 `voiceover.generate`
  - worker 复用 `ttsDubbing` 模型配置与 OpenAI 兼容 speech 接口，生成本地 mp3 资产
  - 音频结果通过现有 `GET /api/v1/jobs/{id}/file` 对外提供，不额外发明新文件接口
  - `app_storyboard.metadata.voiceover` 会持续回写 queued / completed / failed 状态、音频 URL、错误信息与旁白来源文本
  - 分镜查询与导出装配数据已可消费 `voiceover` 状态，前端状态面板也会展示“已生成配音 / 生成中 / 失败”

---

## Phase G - Production Gap Review (Feature + Quality + Token + Reliability)

- [x] 基于当前实现复核“发布是否真实闭环”而非 sandbox 演示闭环
- [x] 复核“质量信号是否真正阻断高风险导出/发布”而非仅展示提示
- [x] 复核“short-video-space 的刷新与拉取路径”是否存在明显 token/请求浪费
- [x] 复核“多草稿、多平台、自动化模式”是否仍停留在 happy path
- [x] 按严重级别收敛缺口，并转成可执行任务清单

## Phase H - Production Feature Closure (P0)

- [ ] 将发布适配从 `sandbox_closure` 升级到可区分 `sandbox/live/manual_bridge` 的真实投递链路
- [ ] 在 attempts/jobs 中落地 `delivery_mode + evidence(request_id/manual_step_id/callback_id)`，支持审计筛选
- [ ] 将表现数据同步从 mock 拉取升级为真实平台指标拉取（含失败重试与退避）
- [ ] 发布面板改为“显式草稿选择”主路径，禁止默认 `_publishDrafts.first` 作为核心操作目标
- [ ] 支持多草稿批量发布/定时/清档/重试，并返回逐草稿结果摘要
- [ ] 自动化模式按平台能力真实生效（`full_auto|semi_auto|manual_assisted` 可见且受后端校验）

## Phase I - Quality Enforcement Closure (P0)

- [ ] 将导出质量门禁从占位升级为 `off|warn|block` 策略，并在 `block` 下阻止导出入队
- [ ] 在发布入队前接入质量门禁校验，避免已知高风险内容直接进入发布作业
- [ ] 扩展候选对比质量范围到 `storyboard + video + output`，不只看 storyboard
- [ ] 把质量 `nextAction` 提升为显式 typed 字段并驱动“局部返工”一键动作
- [ ] 打通“低表现预警 -> 改写文案/重排/重投任务”闭环，并回链原 draft/job

## Phase J - Token and Cost ROI Closure (P0/P1)

- [ ] 为 publish copy 建立输入哈希缓存（draft+targets+style_hint），避免同输入重复 LLM 调用
- [ ] 将 publish copy 生成改为增量模式（仅生成变更平台块），降低全量重生成 token
- [ ] 为 publish copy 调用补齐 `app_llm_usage_log` 记录（`call_type=publish.copy_suggest`）
- [ ] 把 short-video-space 的发布切片请求聚合为单 endpoint（matrix/drafts/jobs/perf/prepare）
- [ ] 减少 `_loadProjectOverview` 扇出与重复拉取，优先局部刷新受影响面板
- [ ] 对高频刷新流程增加请求合并/代际保护，避免旧请求覆盖新状态与重复消耗

## Phase K - Reliability / Observability / Contract Governance

- [ ] 时间线重排保存增加版本冲突检测（避免并发静默覆盖）
- [ ] 单镜头时长对齐改为最小字段 patch，避免“先读 prompt 再整条写回”带来的回滚风险
- [ ] 对关键操作错误提示统一结构化（status/code/message/request-id + 下一步建议）
- [ ] 增加跨面板快照版本（assembly/compare/export-check）并在不一致时显式提示
- [ ] 为关键链路补埋点与 SLI（成功率、P95、失败码分布、质量转化漏斗）
- [ ] 增加 OpenAPI drift gate + rust_api 合约一致性检查，避免手写接口漂移

## Phase L - Production Acceptance Re-Run

- [ ] 以“真实能力”重做九平台矩阵验收（每平台至少一条 live 或 manual_bridge 可追溯样本）
- [ ] 在预发环境执行“质量门禁 + 发布闭环 + 回流指标”端到端回归
- [ ] 对 token 优化项做 A/B 验证，确认成本下降同时质量不回退
- [ ] 最终复核：功能、视频质量、token 成本、稳定性、可观测性五维全部过线

## Phase M - Security / Compliance / Idempotency (常见漏项补齐)

- [ ] 为平台回调与 webhook 增加签名校验、时间窗校验与防重放（nonce/timestamp）
- [ ] 为发布创建、确认、重试、回写等关键写操作补幂等键（避免重复提交造成脏状态）
- [ ] 统一 request-id 贯穿发布链路（API -> worker -> adapter -> callback）并可全链路检索
- [ ] 对审计明细中的敏感字段做脱敏与最小暴露（token、凭据片段、用户隐私文本）
- [ ] 为平台凭据访问增加更严格 RBAC（read/publish/retry/cancel/audit 分权）
- [ ] 补发布域速率限制与配额保护（项目级/用户级），防止误触发批量风暴

## Phase N - Operability / DR / Data Lifecycle (上线可运维补齐)

- [ ] 定义并落地发布 SLA 与告警：`awaiting_confirmation`、`scheduled_deferred`、`callback_timeout` 超时告警
- [ ] 为关键故障场景提供 runbook（平台不可用、回调失败、写回补偿失败、指标同步失败）
- [ ] 建立发布与表现数据归档/保留策略（冷热分层），避免长期表膨胀拖慢查询
- [ ] 为大项目场景补分页/游标能力（jobs/attempts/perf snapshots）与导出能力
- [ ] 增加灰度发布与快速回滚开关（按项目/平台启停 live adapter）
- [ ] 增加“生产级演练日”清单：从创建发布到回调/预警/补偿全链路桌面演练

## Phase O - FinOps / Governance / Release Safety (补漏二次复核)

- [ ] 建立发布与质量链路的成本归因看板（按项目/平台/call_type/模型统计 token 与调用成本）
- [ ] 为 token 优化建立质量防回退基线集（固定样本 + 自动比较），防止“省 token 但降质量”
- [ ] 增加“真实指标 vs mock 指标”口径隔离与看板标识，杜绝运营误读
- [ ] 增加回调与重试的数据对账任务（job/attempt/target/snapshot 周期性校验并自动告警）
- [ ] 为关键 schema 变更补 migration/backfill runbook（含回滚步骤与验收 SQL）
- [ ] 发布策略配置改为“可审计变更”（谁在何时修改阈值/门禁策略/自动化模式）
- [ ] 为生产级功能引入 feature flag 治理（默认关闭、灰度名单、自动回退）
- [ ] 增加上线前 go/no-go 检查表（功能/质量/token/安全/运维 5 维硬门槛）

## Phase P - UX and Human-in-the-loop Completeness (运营落地补漏)

- [ ] 完成“音频和视频装配一致性”复核与修复（对齐 Phase F 未完成项）
- [ ] 补齐“人工桥接发布”操作面板（手动步骤、回填凭证、超时处理、补偿动作）
- [ ] 为多草稿与多平台操作增加“操作预览 + 影响范围确认”步骤，降低误操作风险
- [ ] 增加失败态的一键恢复入口（重试、回滚到上次成功配置、跳转排障）
- [ ] 为关键状态文案统一“真实能力标签”（live/sandbox/manual）与下一步建议
