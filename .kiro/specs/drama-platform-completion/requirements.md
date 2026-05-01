# 需求文档

## 简介

本文档描述 **drama-platform-completion** 功能的需求。目标不再只是补齐前一轮遗留的 8 处缺口，而是把 Toonflow（OpenFlow）AI 短剧平台继续往“可上线前的完善状态”推进，并遵循以下优先级：

1. **功能优先**：先补齐平台闭环能力，确保用户能在平台内完成项目配置、生成、返工、审核、记忆管理等关键流程。
2. **流程优先**：在功能闭环后，继续缩短无效生成路径，提升返工效率、审核效率和运营效率。
3. **质量优先于成本**：生成短剧必须尽量避免“一眼 AI”“人物穿帮”“情绪僵硬像念文章”“全程一个情绪状态”等问题；如质量与 token 成本冲突，优先保证视频质量。
4. **在质量达标前提下压缩 token**：通过最小上下文读取、分层记忆、增量注入、局部返工、自动摘要等方式尽量减少大模型 token 消耗。
5. **记忆必须隔离**：若引入自动化记忆能力，必须保证不同用户、不同项目、不同短剧阶段之间记忆严格隔离，避免串味、污染和成本失控。

当前项目尚未上线，因此本轮需求 **无需为旧实现做向后兼容设计**；若现有实现与新方案冲突，可直接按新方案调整。平台技术栈：Rust 后端（Axum + SQLx）+ Flutter 前端。

---

## 优化原则

### 原则 1：不为省 token 牺牲成片质量

任何 token 优化策略都不得以降低人物一致性、情绪表现、画面真实感、镜头节奏和叙事抓力为代价。若两者冲突，系统 SHALL 选择质量更高的方案。

### 原则 2：优先减少“无效大模型调用”

系统优化重点 SHALL 放在减少重复生成、整段重跑、无差别注入、无边界检索和低价值长回复，而不是简单压缩提示词信息密度。

### 原则 3：自动化记忆只保留“后续确实有用”的内容

系统 SHALL 避免把所有对话和所有产出都写入记忆，而应只沉淀稳定设定、阶段结论、局部连续性补丁和高价值失败归因。

### 原则 4：一切围绕“最少 token 生成最好的短剧”

所有功能完善、流程升级、记忆建设、返工设计和评审机制的最终目标，都是用更少的 token 产出质量更稳定、更真实自然的短剧。

---

## 词汇表

- **System（系统）**：Toonflow 平台整体，包含 Rust 后端、Flutter 前端和 Agent 编排层
- **ProjectEditor（项目编辑器）**：Flutter 前端中用于创建和编辑项目基本信息的对话框（`frontend/lib/project_editor/`）
- **StylePackPicker（风格包选择器）**：用于在项目编辑器中选择画风包和故事风格包的 UI 组件
- **MemoryWorkbench（记忆工作台）**：Flutter 前端中 Agent 记忆管理界面（`frontend/lib/agent_workspaces/`）
- **SkillsHarness（技能文件工作台）**：Flutter 前端中技能文件管理界面（`frontend/lib/skills_harness/`）
- **StoryboardEditor（分镜编辑器）**：Flutter 前端中分镜表编辑界面（`frontend/lib/storyboard_editor/`）
- **QualityReviewsSection（质量评审区）**：Flutter 前端中质量评审管理界面（`frontend/lib/quality_reviews/`）
- **MemoryTier（记忆分层）**：`app_agent_memory` 表中 `memory_tier` 字段的取值，包含 `style_bible`、`stage_summary`、`delta_memory`、`message`
- **StyleBible（风格圣经）**：项目级稳定记忆，包含角色核心设定、视觉锚点、情绪基调、叙事禁忌
- **StageSummary（阶段摘要）**：阶段完成后自动沉淀的摘要记忆，记录阶段结论、失败原因和关键决策点
- **DeltaMemory（增量记忆）**：只记录局部连续性变化和返工修复点的最小补丁记忆
- **MessageMemory（消息记忆）**：普通消息层记忆，用于低优先级系统提示或人工备注
- **MemoryIsolation（记忆隔离）**：记忆数据按 `user_id + project_id + agent_type` 严格隔离，不跨用户、不跨项目、不跨 Agent 污染
- **MemoryInjectionPlan（记忆注入计划）**：系统针对当前任务决定要注入哪些记忆层、每层注入多少内容的策略
- **TokenBudget（token 预算）**：单次任务允许使用的输入/输出 token 预算与软上限
- **QualityGate（质量门）**：进入下一阶段前必须满足的最低质量条件
- **PatchRegeneration（局部返工）**：`POST /api/v1/production/patch` 触发的定点重生成操作
- **PatchScope（返工粒度）**：局部返工最小对象粒度，包含 `storyboard_item`、`scene`、`video_prompt`、`derive_asset`
- **ModelTier（模型层级）**：局部返工时选择的模型策略，`low`（格式修复）或 `high`（剧情改写/情绪强化）
- **AttributionMode（归因模式）**：同一对象连续返工未达标后触发的问题归因分析状态
- **ArtStylePack（画风技能包）**：`art_skills/` 下的风格技能包目录路径
- **StoryStylePack（故事风格包）**：`story_skills/` 下的故事类型技能包目录路径
- **QualityScore（质量评分）**：对阶段产出进行的结构化质量评分，可包含真实感、情绪表达、人物一致性、镜头节奏等维度
- **AI Artifact（AI 痕迹）**：会让用户一眼看出“这是 AI 生成”的不自然问题，如情绪生硬、动作不连贯、人物长相漂移、镜头逻辑断裂、无意义空镜、机械台词感

---

## 需求优先级

### P0：先补功能闭环

- 风格包配置可用
- 记忆工作台可用
- 技能版本历史与回滚可用
- 局部返工可用
- 质量评审筛选可用
- 阶段摘要自动写入可用
- StyleBible 自动初始化可用
- 技能变更通知可用

### P1：再优化业务流程

- 高成本阶段前增加质量预检与拦截
- 局部返工优先替代整段重跑
- 返工失败自动归因
- 质量评审结果可驱动下一步动作
- 记忆写入、压缩、注入具备自动化策略

### P2：最后优化质量与成本

- 人物风格、情绪、节奏、镜头真实感提升
- 减少一眼 AI 的画面与表演
- 在不降质前提下降低 token 消耗
- 建立项目级自动化记忆增强体系

---

## 需求

### 需求 1：前端 UI — 风格包选择器（StylePackPicker）

**用户故事：** 作为短剧创作者，我希望在创建或编辑项目时能够选择画风技能包和故事风格包，这样系统才能在生成流水线中自动加载对应的风格规范，而不需要我手动配置。

#### 验收标准

1. WHEN 用户打开项目编辑器对话框时，THE ProjectEditor SHALL 在基本信息区域展示「画风技能包」和「故事风格包」两个选择字段，显示当前项目已配置的包名称；若未配置则显示「未选择」。
2. WHEN 用户点击「画风技能包」选择字段时，THE StylePackPicker SHALL 展示所有可用的画风技能包列表，并显示包名称、简短描述、适用场景标签。
3. WHEN 用户点击「故事风格包」选择字段时，THE StylePackPicker SHALL 展示所有可用的故事风格包列表，并显示包名称、简短描述、推荐题材标签。
4. WHEN 用户选择一个画风技能包或故事风格包后点击保存时，THE ProjectEditor SHALL 调用 `PATCH /api/v1/projects/{id}/style-config` 将选择持久化，并在保存成功后更新界面显示。
5. IF `PATCH /api/v1/projects/{id}/style-config` 返回错误，THEN THE ProjectEditor SHALL 显示错误信息，并保留用户当前选择状态。
6. WHEN 用户清空画风技能包或故事风格包选择时，THE ProjectEditor SHALL 允许将对应字段设置为空（传递 `null`），并在保存后显示「未选择」。
7. THE ProjectEditor SHALL 在项目编辑器的「基本信息」标签页中展示风格包选择字段，与项目名称和简介字段同级显示，不折叠隐藏。

---

### 需求 2：前端 UI — 记忆分层展示与成本概览

**用户故事：** 作为短剧创作者，我希望在 Agent 记忆工作台中能够按分层查看记忆条目、了解记忆成本，并知道系统是否正在浪费 token，这样我才能判断是否需要清理或优化记忆。

#### 验收标准

1. WHEN 用户在记忆工作台加载记忆列表时，THE MemoryWorkbench SHALL 将记忆条目按 `memory_tier` 分组展示，分组标题依次为「风格圣经」「阶段摘要」「增量记忆」「普通消息」。
2. WHEN 用户点击「加载成本概览」按钮时，THE MemoryWorkbench SHALL 调用 `GET /api/v1/agents/memory/cost-overview` 并展示各层条目数、近 30 次任务平均注入字数、近 30 次任务平均命中层级数。
3. THE MemoryWorkbench SHALL 以可读格式展示成本概览，例如：「风格圣经 2 条 · 阶段摘要 6 条 · 增量记忆 14 条 · 近 30 次平均注入 1320 字」。
4. WHEN 用户选择按分层过滤记忆时，THE MemoryWorkbench SHALL 提供过滤项（全部 / StyleBible / StageSummary / DeltaMemory / Message），选择后仅展示对应层级条目。
5. WHEN 用户通过 `POST /api/v1/agents/memory/query` 查询记忆时，THE MemoryWorkbench SHALL 在请求体中传递 `memoryTier` 过滤参数。
6. IF `GET /api/v1/agents/memory/cost-overview` 返回错误，THEN THE MemoryWorkbench SHALL 显示错误信息且不影响记忆列表继续使用。
7. THE MemoryWorkbench SHALL 在每条记忆条目旁显示其 `memory_tier` 标签和最近一次被注入时间，帮助用户判断哪些记忆值得保留。

---

### 需求 3：前端 UI — 技能文件版本历史与回滚

**用户故事：** 作为平台运营者，我希望在技能文件工作台中能够查看某个技能文件的版本历史、对比差异，并在生成质量下降时快速回滚到上一个有效版本。

#### 验收标准

1. WHEN 用户在技能文件工作台选中一个技能文件后，THE SkillsHarness SHALL 展示「查看版本历史」按钮，点击后调用 `GET /api/v1/skill-versions?path={filePath}` 并展示版本列表。
2. THE SkillsHarness SHALL 在版本历史列表中为每个版本显示：变更时间、变更摘要、版本哈希前 8 位。
3. WHEN 用户选中某个历史版本时，THE SkillsHarness SHALL 展示该版本与当前版本并排对比，并高亮差异行。
4. WHEN 用户点击「回滚到此版本」时，THE SkillsHarness SHALL 弹出确认对话框，明确提示当前文件将被回滚到目标版本。
5. WHEN 用户确认回滚后，THE SkillsHarness SHALL 调用 `POST /api/v1/skill-versions/rollback`，完成后刷新文件内容和版本历史列表。
6. IF `POST /api/v1/skill-versions/rollback` 返回错误，THEN THE SkillsHarness SHALL 显示具体错误信息，不执行任何内容变更。
7. WHEN 版本历史为空时，THE SkillsHarness SHALL 显示「该文件暂无版本历史记录」，且不展示回滚按钮。

---

### 需求 4：前端 UI — 局部返工（PatchRegeneration）

**用户故事：** 作为短剧创作者，我希望在分镜编辑器中能够对特定分镜发起局部返工，指定返工粒度与模型层级，而不是重新跑完整流水线。

#### 验收标准

1. WHEN 用户在分镜编辑器中选中一个或多个分镜条目时，THE StoryboardEditor SHALL 展示「局部返工」按钮，点击后打开配置面板。
2. THE StoryboardEditor SHALL 在返工配置面板中提供返工粒度、模型层级、返工原因三个配置项；返工原因必填且不超过 200 字。
3. WHEN 用户提交返工请求时，THE StoryboardEditor SHALL 调用 `POST /api/v1/production/patch`，请求体包含 `scope`、`ids`、`reason`、`model_tier` 字段。
4. WHEN 响应中 `attribution_mode = true` 时，THE StoryboardEditor SHALL 显示归因模式警告，包括连续失败次数和归因摘要。
5. WHEN 用户未填写返工原因时，THE StoryboardEditor SHALL 禁用提交按钮，并提示「请填写返工原因」。
6. IF `POST /api/v1/production/patch` 返回错误，THEN THE StoryboardEditor SHALL 显示错误信息，并保留用户当前配置。
7. WHEN 局部返工提交成功后，THE StoryboardEditor SHALL 显示返工任务 ID 和状态，并关闭配置面板。

---

### 需求 5：前端 UI — 质量评审阶段与等级筛选

**用户故事：** 作为平台运营者，我希望在质量评审界面中能够按生产阶段和评审等级筛选评审记录，并查看阶段分布，以便快速定位质量问题。

#### 验收标准

1. THE QualityReviewsSection SHALL 提供「阶段筛选」下拉菜单，包含全部及各生产阶段选项。
2. THE QualityReviewsSection SHALL 提供「等级筛选」下拉菜单，包含全部 / A / B / C / D。
3. WHEN 用户选择阶段或等级筛选条件后，THE QualityReviewsSection SHALL 将 `stage` 和 `grade` 查询参数传递给后端 API，并仅展示符合条件的记录。
4. THE QualityReviewsSection SHALL 在评审列表中显示 `stage` 和 `grade` 字段，`stage` 用中文名称展示，`grade` 用彩色标签展示。
5. WHEN 用户点击「查看等级分布」按钮时，THE QualityReviewsSection SHALL 调用 `GET /api/v1/quality/stage-pass-rate` 并以表格或简单图表展示各阶段 A/B/C/D 分布。
6. WHEN 阶段筛选和等级筛选同时生效时，THE QualityReviewsSection SHALL 以 AND 逻辑组合两者。
7. WHEN 筛选结果为空时，THE QualityReviewsSection SHALL 显示「当前筛选条件下无评审记录」。

---

### 需求 6：后端逻辑 — 阶段摘要记忆自动写入

**用户故事：** 作为平台运营者，我希望当 Agent 完成一个生产阶段任务时，系统能够自动把阶段结论写入记忆，后续会话不需要重新读取全量工作区。

#### 验收标准

1. WHEN Agent 通过 Harness WebSocket 完成一个阶段任务时，THE System SHALL 自动向 `app_agent_memory` 表写入一条 `memory_tier = 'stage_summary'` 的记忆条目。
2. THE System SHALL 确保阶段摘要内容不超过 320 字，包含阶段名称、完成状态、关键决策点和必要的失败原因摘要。
3. THE System SHALL 在阶段摘要中附加 `scope_signature`，至少包含 `episodeId`、`storyboardIds`、`focusSections` 中的一个非空范围字段。
4. IF 同一项目、同一 Agent 类型、同一阶段已存在 `stage_summary` 条目，THEN THE System SHALL 使用 upsert 语义覆盖旧摘要，避免重复累积。
5. WHEN 阶段任务失败时，THE System SHALL 仍然写入 `status: failed` 的阶段摘要，供后续诊断和归因使用。
6. THE System SHALL 异步执行阶段摘要写入，写入失败时记录 `WARN` 日志但不阻塞主任务响应。
7. FOR ALL 自动写入的阶段摘要条目，THE System SHALL 保证其 `user_id`、`project_id` 与触发会话一致，不破坏记忆隔离。

---

### 需求 7：后端逻辑 — StyleBible 自动初始化

**用户故事：** 作为短剧创作者，我希望项目创建后系统能自动生成初始 StyleBible，并在首次资产提取后补充角色与视觉约束，这样后续生成能更快稳定下来。

#### 验收标准

1. WHEN 用户创建新项目时，THE System SHALL 自动写入一条 `memory_tier = 'style_bible'` 的初始模板条目。
2. 初始模板 SHALL 包含 `characters`、`visual_taboos`、`narrative_taboos`、`world_constraints`、`platform_rhythm`、`core_relationships`、`emotion_baseline` 字段，值初始化为空数组或空字符串。
3. WHEN 首次资产提取完成后，THE System SHALL 自动使用提取到的角色与视觉信息填充 StyleBible，至少补充角色名、固定外观、核心气质。
4. THE System SHALL 确保自动填充后的 StyleBible 内容不超过 800 字；若超过上限，优先保留主要角色与高频视觉禁忌。
5. IF 已存在非空 StyleBible，THEN THE System SHALL 不覆盖已有内容，仅在条目缺失或为空模板时自动填充。
6. THE System SHALL 异步执行初始化与填充，失败时记录 `WARN` 日志但不阻塞项目创建或资产提取主流程。
7. WHEN StyleBible 初始化完成后，THE System SHALL 在 `scope_signature` 中标记项目级作用域（包含 `projectId`）。

---

### 需求 8：后端逻辑 — 技能文件变更通知

**用户故事：** 作为平台运营者，我希望当技能文件版本发生变更时，系统能通知受影响的进行中项目，提醒用户重新审核相关阶段产出物。

#### 验收标准

1. WHEN 技能文件通过 `PUT /api/v1/skills/content` 或 `POST /api/v1/skills/content` 成功写入后，THE System SHALL 检查所有 `in_progress` 项目是否使用了该技能文件或对应风格包。
2. WHEN 检测到进行中项目受影响时，THE System SHALL 为关联用户写入一条系统通知，提示技能文件已更新并建议重新审核相关阶段产出物。
3. THE 通知记录 SHALL 包含 `user_id`、`project_id`、`file_path`、`changed_at`、`message` 字段。
4. IF 系统暂无独立通知表，THEN THE System SHALL 将该通知写入 `app_agent_memory`，`memory_tier = 'message'`，`agent_type = 'system'`。
5. THE System SHALL 异步执行通知发送，失败时记录 `WARN` 日志但不阻塞技能文件写入响应。
6. WHEN 同一技能文件 1 分钟内多次变更时，THE System SHALL 合并通知，避免通知轰炸。
7. THE System SHALL 对核心技能文件、画风技能包文件、故事风格包文件都支持变更通知，并在通知中注明受影响的包类型与名称。

---

### 需求 9：业务流程优化 — 高成本阶段前质量预检

**用户故事：** 作为平台运营者，我希望在进入高成本生成阶段前，系统能自动预检前置产出质量，避免把明显有问题的内容继续送进更贵的模型调用里浪费 token。

#### 验收标准

1. WHEN 流水线即将进入 `storyboard_panel`、`video_prompt` 或视频生成前置阶段时，THE System SHALL 先执行一次轻量质量预检。
2. THE 质量预检 SHALL 至少检查：人物设定是否缺失、情绪曲线是否单一、分镜节奏是否过平、是否存在明显视觉冲突、是否存在台词机械朗读风险。
3. IF 预检判定存在严重问题，THEN THE System SHALL 阻止进入下一高成本阶段，并给出最小返工建议，而不是直接继续生成。
4. IF 预检仅发现轻微问题，THEN THE System SHALL 允许继续，但需把问题写入 `delta_memory` 供下一阶段约束。
5. THE 预检结果 SHALL 结构化记录问题等级、问题类型、建议动作和命中对象范围。
6. THE System SHALL 优先使用规则校验和已有结构化字段完成预检，只有在规则无法判断时才调用大模型补充评估。
7. THE System SHALL 记录因预检拦截而节省的高成本调用次数，用于后续评估 ROI。

---

### 需求 10：短剧质量提升 — 人物真实感、情绪表达与反 AI 痕迹

**用户故事：** 作为短剧创作者，我希望生成的人物有明确风格、有情绪起伏、动作和镜头真实自然，不会看起来像 AI 在朗读或拼贴画面。

#### 验收标准

1. WHEN ScriptAgent 或 ProductionAgent 生成内容时，THE System SHALL 把“人物一致性、情绪起伏、动作衔接、镜头真实感、反 AI 痕迹”视为高优先级质量目标，而不是可选优化项。
2. THE System SHALL 对每个主要角色维护稳定的人物锚点，至少包含外貌识别点、气质关键词、情绪表达习惯、关系定位和常见动作倾向。
3. WHEN 生成分镜或视频提示词时，THE System SHALL 确保相邻镜头中的角色情绪具有递进或回落逻辑，禁止连续 3 条以上分镜保持同一强度、同一姿态、同一表演状态。
4. THE System SHALL 避免生成“像读文章”的台词表现：含台词镜头必须明确说话对象、情绪意图、停顿方式、语速或气口特征中的至少两项。
5. THE System SHALL 建立 AI 痕迹检查项，至少覆盖：人物长相漂移、衣着突然变化、肢体不连贯、视线方向错误、场景物理关系错乱、无意义重复动作、情绪不匹配台词。
6. IF AI 痕迹检查命中严重问题，THEN THE System SHALL 优先触发局部返工或归因，而不是继续沿用该结果进入后续阶段。
7. FOR ALL 高情绪场景，THE System SHALL 要求生成结果具备可感知的情绪峰值，不允许整场景维持“平平淡淡、一个状态说到底”的表现。

---

### 需求 11：Token 消耗优化（质量优先）

**用户故事：** 作为平台运营者，我希望在保证视频质量的前提下，系统能显著降低不必要的 token 消耗，尤其减少整段重跑和无差别上下文注入。

#### 验收标准

1. WHEN 任意 Agent 读取工作区数据时，THE Agent SHALL 优先使用最小读取策略：先限制字段，再限制 ID/范围，最后才允许全量读取。
2. WHEN 任意 Agent 组装提示词上下文时，THE System SHALL 按任务类型生成 `MemoryInjectionPlan`，仅注入与当前对象和当前阶段相关的最小记忆集合。
3. WHEN 决策层向执行层派发任务时，THE 决策层 SHALL 发送短指令，避免在派发消息中重复技能文件里已存在的长规则。
4. WHEN 执行层完成任务后，THE 执行层 SHALL 返回不超过 50 字的确认信息，禁止冗长复述已写入工作区的内容。
5. WHEN 同一对象连续返工时，THE System SHALL 优先注入“上次失败原因 + 本次修复目标 + 局部上下文”，禁止每次返工都重新注入整阶段全量背景。
6. IF 为减少 token 而需要删减上下文，THEN THE System SHALL 优先删减低价值普通消息和重复摘要，不得删减人物锚点、风格硬约束和关键失败归因。
7. THE System SHALL 支持统计每类阶段的平均 token 消耗、返工消耗和因局部返工节省的消耗，供后续持续优化。

---

### 需求 12：自动化记忆增强 — 类 Codex 记忆能力的项目化引入

**用户故事：** 作为平台运营者，我希望评估并引入类似 Codex 的自动化记忆能力，提升项目质量稳定性，但必须保证记忆独立、可控、节省成本，不让平台被长期记忆烧穿预算。

#### 验收标准

1. THE System SHALL 支持项目级自动化记忆机制，但该机制必须以 `user_id + project_id + agent_type` 为硬隔离边界。
2. THE System SHALL 不允许默认把所有会话全文写入长期记忆，而应仅自动沉淀 StyleBible、StageSummary、DeltaMemory 和高价值系统通知。
3. WHEN 自动化记忆写入触发时，THE System SHALL 先判断该信息是否具有跨阶段复用价值；若没有复用价值，则不得写入长期记忆。
4. THE System SHALL 对每个项目维护独立的记忆预算指标，至少包含记忆条目数、近 30 次平均注入量、低价值记忆占比。
5. WHEN 项目记忆预算超过阈值时，THE System SHALL 优先执行摘要压缩、重复合并和低价值消息淘汰，而不是继续无上限累积。
6. WHEN Agent 查询记忆时，THE System SHALL 优先按 `scope_signature` 精确检索，再决定是否扩展到项目级广义检索，避免每次 deepRetrieve 都打满全局记忆。
7. IF 自动化记忆引入后未显著提升质量或返工率，THEN THE System SHALL 支持按项目关闭或降级自动记忆注入强度，避免“质量没提升，钱反而烧太多”。

---

### 需求 13：返工升级 — 从重生成转向问题归因与定点修复

**用户故事：** 作为平台运营者，我希望返工流程不是简单“再生成一次”，而是能明确失败原因、缩小修复范围，减少重复烧 token。

#### 验收标准

1. WHEN 同一对象连续两次返工仍未达标时，THE System SHALL 自动进入 `AttributionMode`，输出明确的失败归因。
2. THE 失败归因 SHALL 至少区分：设定缺失、情绪错误、镜头语言错误、视觉连续性错误、提示词表达不足、上游数据错误 六类问题。
3. WHEN 归因结果表明问题来自上游阶段时，THE System SHALL 优先建议回退到最小必要上游阶段，而不是继续在当前阶段盲目重试。
4. WHEN 归因结果表明问题仅属于当前对象局部修复，THE System SHALL 优先使用 `storyboard_item` 或 `video_prompt` 级返工。
5. THE System SHALL 将高价值失败归因写入 `delta_memory` 或 `stage_summary`，供后续同类任务规避复发。
6. THE System SHALL 在返工结果中记录“本次返工比整段重跑节省的 token 估算值”。
7. THE System SHALL 为用户显示返工建议优先级：先局部修，再上游修，最后才整段重跑。

---

### 需求 14：质量评审驱动持续优化

**用户故事：** 作为平台运营者，我希望质量评审不只是打分，而是能反向驱动技能、提示词、记忆和返工策略持续优化。

#### 验收标准

1. WHEN 监督层完成审核时，THE 监督层 SHALL 输出结构化评审摘要，至少包含 `grade`、问题等级统计、问题类型统计、建议下一步动作。
2. THE System SHALL 支持把评审问题映射到固定问题类型，如人物一致性、情绪表达、镜头节奏、视觉连续性、台词生硬、AI 痕迹等。
3. WHEN 某类问题在近 20 次评审中反复出现时，THE System SHALL 将其标记为高频 bad case，用于后续技能文件和提示词优化。
4. WHEN 技能文件或提示词模板变更后，THE System SHALL 支持按版本对比变更前后的评审分布，帮助判断修改是否真正提升质量。
5. THE System SHALL 支持基于评审结果推荐最小修复动作，例如“仅修 3 条分镜情绪”“回退到导演规划重做”“更新角色锚点后重生成视频提示词”。
6. THE System SHALL 优先把评审结果作为返工和记忆优化输入，而不是把所有差评都转化为整段重新生成。
7. THE System SHALL 为后续单独 spec 预留 bad case 样本池、自动对比基线和 ROI 分析能力的扩展空间。

---

## 附录 A：现阶段缺口与新增优化项映射

| 类别 | 说明 |
|------|------|
| 原缺口 | 风格包选择器、记忆分层展示、技能版本历史、局部返工、质量评审筛选、阶段摘要自动写入、StyleBible 自动初始化、技能变更通知 |
| 新流程优化 | 高成本阶段前质量预检、返工归因、质量评审驱动动作建议 |
| 新质量优化 | 人物锚点、情绪起伏、反 AI 痕迹检查、真实自然视频表现 |
| 新成本优化 | 最小上下文读取、记忆注入计划、项目级记忆预算、记忆压缩与淘汰 |
| 新平台能力 | 类 Codex 自动化记忆的项目化引入与独立隔离控制 |

---

## 附录 B：各需求对应的后端 API / 能力

| 需求 | 相关后端 API / 能力 | 状态 |
|------|-------------------|------|
| 需求 1（风格包选择器） | `PATCH /api/v1/projects/{id}/style-config` | ✅ 已有基础接口 |
| 需求 2（记忆分层展示） | `POST /api/v1/agents/memory/query`、`GET /api/v1/agents/memory/cost-overview` | ✅ 已有基础接口 |
| 需求 3（技能版本历史） | `GET /api/v1/skill-versions?path=`、`POST /api/v1/skill-versions/rollback` | ✅ 已有基础接口 |
| 需求 4（局部返工） | `POST /api/v1/production/patch` | ✅ 已有基础接口 |
| 需求 5（质量评审筛选） | `GET /api/v1/quality-reviews`、`GET /api/v1/quality/stage-pass-rate` | ✅ 已有基础接口 |
| 需求 6（阶段摘要自动写入） | 任务完成钩子 + 记忆写入逻辑 | ❌ 触发逻辑待补齐 |
| 需求 7（StyleBible 自动初始化） | 项目创建钩子 / 资产提取完成钩子 + 记忆写入逻辑 | ❌ 触发逻辑待补齐 |
| 需求 8（技能文件变更通知） | 技能写入后通知机制 | ❌ 待实现 |
| 需求 9（质量预检） | 规则校验器 + 轻量评估调用 + 流水线拦截逻辑 | ❌ 待实现 |
| 需求 10（质量提升） | 角色锚点、情绪约束、AI 痕迹检查、评审规则 | ❌ 待实现 |
| 需求 11（token 优化） | 最小读取策略、记忆注入计划、成本统计 | ❌ 待实现或待补强 |
| 需求 12（自动化记忆） | 自动写入策略、记忆预算、压缩淘汰、隔离检索 | ❌ 待评估并实现 |
| 需求 13（返工归因） | 归因分类器、返工策略路由、节省量统计 | ❌ 待实现 |
| 需求 14（评审驱动优化） | 结构化评审摘要、bad case 聚类、版本对比分析 | ❌ 待实现 |

---

## 附录 C：后续建议拆分的独立 spec

如果后续要继续纵深推进，建议从本需求文档再拆出一个独立 spec：**`drama-platform-memory-efficiency`**，专门覆盖以下内容：

1. 项目级自动化记忆预算控制
2. 记忆压缩/淘汰/注入算法
3. 返工节省 token 的量化统计
4. bad case 样本池与质量 ROI 分析

这样可以把“先补功能”与“再做质量/成本深优化”拆开推进，避免后续实现阶段混在一起失控。
