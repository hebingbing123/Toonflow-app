# 需求文档

## 简介

本文档描述 **AI 短剧生成质量优化**功能的需求。目标是在 OpenFlow平台上，通过优化 Agent 技能文件、提示词工程、记忆系统和生成流水线，使生成的短剧视频达到"不穿帮"的质量标准——人物有风格与情绪、画面真实自然、叙事节奏有起伏——同时在保证质量的前提下尽量减少大模型 token 消耗。

平台技术栈：Rust 后端（Axum + SQLx + Tokio）+ Flutter 前端，Agent 编排通过 Harness WebSocket 协议运行，技能文件为 Markdown 格式存储于 `backend/data/skills/`，提示词模板存储于 `backend/data/prompt_defaults/`。

---

## 词汇表

- **System（系统）**：Openflow 平台整体，包含 Rust 后端、Flutter 前端和 Agent 编排层
- **ScriptAgent**：负责小说改编为剧本的 Agent 体系（决策层 + 执行层 + 监督层）
- **ProductionAgent**：负责剧本到分镜、分镜到视频提示词的 Agent 体系
- **Skill（技能文件）**：存储于 `backend/data/skills/` 的 Markdown 文件，定义 Agent 的行为规范
- **PromptTemplate（提示词模板）**：存储于 `backend/data/prompt_defaults/` 的文本文件
- **Memory（记忆）**：`app_agent_memory` 表中按用户 + 项目 + Agent 类型隔离的持久化上下文
- **FlowData（工作区数据）**：通过 `get_flowData` / `set_flowData` 读写的生产工作区状态
- **StoryboardItem（分镜条目）**：包含 `videoDesc`、`prompt`、`track`、`duration`、`associateAssetsIds` 等字段的分镜单元
- **VideoDesc（视频描述）**：分镜条目中结构化的画面描述字段，是视频提示词生成的核心输入
- **DeriveAsset（衍生资产）**：父资产的视觉状态变体（如角色换装、场景时间变体）
- **Token（令牌）**：大模型 API 计费单位，输入 + 输出 token 之和
- **MemoryIsolation（记忆隔离）**：不同用户、不同项目之间的记忆数据完全独立，不互相污染
- **MemoryTier（记忆分层）**：按稳定程度和用途拆分的记忆层级，如项目圣经、阶段摘要、局部连续性补丁
- **StyleBible（风格圣经）**：项目级高稳定约束，包含角色核心设定、视觉锚点、叙事禁忌、情绪基调
- **DeltaMemory（增量记忆）**：仅记录相对上一次状态变化的最小补丁记忆，而非重复存整段摘要
- **PatchRegeneration（局部返工）**：仅对失败的集、场、分镜、提示词或镜头做定点重生成，不整段重跑
- **QualityReview（质量评审）**：`app_quality_review` 表记录的人工或自动化质量评分
- **ArtStyle（画风）**：`art_skills/` 下的风格技能包，定义色彩、光影、构图等视觉规范
- **StoryStyle（故事风格）**：`story_skills/` 下的故事类型技能包，定义叙事节奏、情绪曲线等规范

---

## 需求

### 需求 1：人物情绪与风格一致性

**用户故事：** 作为短剧创作者，我希望生成的人物在整部短剧中保持一致的性格风格，并在不同场景中展现符合剧情的情绪变化，而不是全程一种状态，这样观众才不会感到生硬。

#### 验收标准

1. WHEN ScriptAgent 编写剧本时，THE ScriptAgent SHALL 在每个场景的 △ 描述中包含角色的具体肢体动作链（至少 2 个连续动作）、面部微表情和情绪状态，禁止仅写"感到悲伤"等抽象情绪词。

2. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 为每条分镜的 `emotion` 字段填写具象可感的情绪描述（如"冷傲轻蔑""痛苦绝望"），禁止填写"开心""难过"等空泛词。

3. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 确保同一角色在相邻分镜中的情绪强度遵循渐进变化原则，禁止出现连续 3 条以上同情绪强度的分镜。

4. WHEN ProductionAgent 生成分镜提示词时，THE ProductionAgent SHALL 在 `action` 字段中描述角色在视频首帧（t=0）的预备状态（蓄势待发的静态张力），而非动作终态或过程态。

5. WHEN ScriptAgent 编写剧本时，THE ScriptAgent SHALL 确保每集剧本的情绪曲线包含至少 3 个不同强度层次（低强度铺垫、中强度推进、高强度高潮），且高潮段落不出现在前 20% 的场景中。

6. WHERE 故事风格技能包（StoryStyle）已配置，THE ScriptAgent SHALL 在生成剧本骨架和改编策略时加载对应风格的叙事规范，并确保情绪曲线设计与风格定义一致。

---

### 需求 2：视频画面真实自然（不穿帮）

**用户故事：** 作为短剧创作者，我希望生成的视频画面看起来真实自然，不会一眼被看出是 AI 生成的，包括人物动作连贯、视觉风格统一、镜头语言专业。

#### 验收标准

1. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 对每条分镜执行视觉连续性校验，确保相邻分镜的角色位置、动作进度、朝向符合物理逻辑，并在 `action` 字段中标注与上一镜的衔接关系（格式：`（承接上镜：{上一镜终态}）`）。

2. WHEN ProductionAgent 生成分镜提示词时，THE ProductionAgent SHALL 禁止在提示词中使用画质降级词（`film grain`、`imperfect focus`、`柔焦`、`朦胧感`等），并在负向词中声明禁止这些效果。

3. WHEN ProductionAgent 写入分镜面板时，THE ProductionAgent SHALL 确保同一场景内同一角色的画面位置（左/中/右）在所有分镜中保持固定，位置变化须有对应的动作衔接描述。

4. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 遵循景别递进法则（渐进聚焦或渐进释放），禁止出现连续 3 条以上使用完全相同景别的分镜。

5. WHEN ProductionAgent 生成分镜提示词时，THE ProductionAgent SHALL 为每条分镜的 `prompt` 字段添加图像资产标注前缀（格式：`@图N 为{资产名称}{资产类型}`），并在提示词正文中用 `@图N` 替代角色/场景名称，建立参考图与画面描述的直接绑定。

6. WHERE 画风技能包（ArtStyle）已配置，THE ProductionAgent SHALL 在生成所有分镜提示词时加载对应画风的全局约束规则（必守规则 R1-R5）和严禁项（X1-X5），并确保提示词符合画风定义的色彩盘和光影规范。

7. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 对每个新场景的定场镜头限制在最多 2 个，禁止出现 3 个以上的碎片化定场镜头。

8. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 对无台词镜头应用黄金 6 秒规则，确保单个无台词镜头时长不超过 6 秒（一镜到底镜头除外，上限 12 秒）。

---

### 需求 3：Token 消耗优化（质量优先）

**用户故事：** 作为平台运营者，我希望在保证短剧生成质量的前提下，尽量减少大模型的 token 消耗，降低运营成本，同时不因节省 token 而降低生成质量。

#### 验收标准

1. WHEN ProductionAgent 执行层读取工作区数据时，THE ProductionAgent SHALL 优先使用最小读取策略：先用 `fields` 参数限制返回字段，再用 `ids` 参数精确读取，最后才用全量读取；禁止在信息已足够时继续补读整包数据。

2. WHEN ScriptAgent 执行层读取工作区数据时，THE ScriptAgent SHALL 优先按当前任务章节范围读取事件表，并使用 `fields:["numeric_id","name","detail"]` + `limit` + `maxChars` 参数限制返回量；禁止默认整章全读。

3. WHEN 任意 Agent 执行层完成任务后，THE Agent SHALL 返回不超过 50 字的简短确认消息，禁止在确认消息中复述完整内容或输出预览摘要。

4. WHEN 决策层向执行层派发任务时，THE 决策层 SHALL 确保派发指令正文（不含项目配置头部）不超过 100 字，执行层已具备完整技能指令，无需在派发指令中重复执行流程细节。

5. WHEN ProductionAgent 执行层读取分镜表时，THE ProductionAgent SHALL 优先使用 `ids` 参数精确读取当前任务相关的分镜行，仅在无法精确定位时才使用 `rowStart`/`rowCount` 窗口读取；禁止默认整表读取。

6. IF 为节省 token 而需要在生成质量与 token 消耗之间取舍，THEN THE System SHALL 优先保证生成质量，允许增加 token 消耗。

7. WHEN ScriptAgent 执行层读取剧本内容时，THE ScriptAgent SHALL 使用 `lineStart`/`lineEnd`/`maxChars` 参数进行窗口化读取，仅在需要承接上一集时才读取上一集尾段窗口（`lineStart:61, lineEnd:120, maxChars:1600`），禁止默认读取整集剧本。

---

### 需求 4：项目级记忆隔离与质量增强

**用户故事：** 作为平台运营者，我希望引入类似 Codex 的自动化记忆功能来增强生成质量，同时确保不同用户和不同短剧项目之间的记忆完全独立，不会互相污染。

#### 验收标准

1. THE System SHALL 确保 `app_agent_memory` 表中的记忆数据按 `user_id` + `project_id`（或 `episodes_id`）+ `agent_type` 三维度隔离，不同用户之间的记忆数据完全独立。

2. WHEN Agent 执行任务时，THE Agent SHALL 仅能读取与当前用户、当前项目、当前 Agent 类型匹配的记忆条目，禁止跨用户或跨项目读取记忆。

3. WHEN ScriptAgent 决策层开始新会话时，THE ScriptAgent 决策层 SHALL 仅在用户明确要求回想历史内容时才调用 `deepRetrieve`，禁止在每次会话开始时自动触发记忆检索。

4. WHEN ProductionAgent 决策层需要判断项目进度时，THE ProductionAgent 决策层 SHALL 通过 `deepRetrieve` 检索当前项目的历史进度记忆，而非通过读取工作区数据来判断进度。

5. WHEN Agent 完成一个阶段任务后，THE System SHALL 自动将该阶段的关键产出摘要（不超过 320 字）写入 `app_agent_memory`，包含阶段名称、完成状态和关键决策点，供后续会话检索。

6. WHEN 自动记忆摘要写入时，THE System SHALL 在摘要中附加范围签名（scope signature），包含相关的 `storyboardIds`、`assetIds`、`assetTypes`、`focusSections` 等维度，以支持精确的范围匹配检索。

7. IF 记忆检索无结果，THEN THE Agent SHALL 向用户请求必要的上下文信息，而非基于猜测继续执行。

---

### 需求 5：叙事节奏与短剧平台适配

**用户故事：** 作为短剧创作者，我希望生成的短剧符合短视频平台的观看习惯，开场抓人、节奏紧凑、每集结尾有钩子，而不是像读文章一样平铺直叙。

#### 验收标准

1. WHEN ScriptAgent 编写剧本时，THE ScriptAgent SHALL 确保每集剧本的前 3 个场景（约前 30 秒）包含至少一个冲突或悬念建立点，禁止以纯环境描写或人物介绍开场。

2. WHEN ScriptAgent 构建故事骨架时，THE ScriptAgent SHALL 为每集设计一个集末钩子（最后 5-10 秒的台词或画面），钩子类型须多样化（悬念钩子、情感钩子、智识钩子、世界观钩子），禁止全部集数使用同一类型钩子。

3. WHEN ScriptAgent 编写剧本时，THE ScriptAgent SHALL 确保单句台词不超过 20 字（适配竖屏短视频观众阅读速度），对话场景中连续台词之间须有 △ 动作描述间隔。

4. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 根据台词字数和角色情绪状态计算分镜时长（愤怒 ~4 字/秒、正常 ~3 字/秒、悲伤 ~2 字/秒），含台词分镜的 `duration` 不得短于台词字数除以对应语速后向上取整加 1 秒安全余量。

5. WHEN ScriptAgent 编写剧本时，THE ScriptAgent SHALL 在场景之间使用 `---` 分隔，并在节拍转换处标注转场方式（`[硬切]`、`[淡入]`、`[闪白]`、`[闪黑]`、`[叠化]`），禁止场景之间无任何转场标注。

6. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 在跨场景时插入 1 个空镜分镜（2-3 秒）作为情绪缓冲，空镜内容须与前后场景氛围相关，禁止使用花式转场（划屏、旋转、百叶窗等）。

---

### 需求 6：质量评审与持续改进

**用户故事：** 作为平台运营者，我希望有系统化的质量评审机制，能够追踪生成质量的变化趋势，识别 bad case，并通过版本对比持续改进技能文件。

#### 验收标准

1. WHEN 监督层 Agent 完成审核时，THE 监督层 SHALL 输出包含 `grade`（A/B/C/D）、`severeCount`、`mediumCount`、`minorCount` 和 `nextAction` 的结构化 XML 摘要（`<reviewSummary />`），供工作台直接解析并生成下一步动作建议。

2. WHEN 监督层 Agent 发现严重问题时，THE 监督层 SHALL 在审核报告中提供至少 2 个可选修复方案，并在 `<reviewSummary />` 的 `nextAction` 字段中指定最优先的下一步动作。

3. WHEN 用户在质量评审工作台创建评审记录时，THE System SHALL 将评审结果写入 `app_quality_review` 表，包含阶段名称（`stage`）、评分（`grade`）、问题描述和修复建议。

4. THE System SHALL 通过 `GET /api/v1/quality-reviews/stats` 提供分环节通过率统计，返回各阶段（故事骨架、改编策略、导演规划、分镜表）的 A/B/C/D 评分分布和通过率（A+B 占比）。

5. WHEN 技能文件（Skill）或提示词模板（PromptTemplate）发生变更时，THE System SHALL 在 `app_quality_review` 记录中保留对应的技能版本信息（文件路径 + 最后修改时间），以支持版本对比回归。

6. WHILE 质量评审工作台处于活跃状态，THE System SHALL 支持按项目 ID、阶段、评分等级筛选评审记录，并展示问题清单和建议方案。

---

### 需求 7：视频提示词生成质量

**用户故事：** 作为短剧创作者，我希望系统能根据不同的视频生成模型（Seedance 2.0、KlingOmni、Nanobanana 等）自动生成最优格式的视频提示词，确保台词、情绪、光影等关键信息不丢失。

#### 验收标准

1. WHEN 视频提示词生成 Agent 处理含台词的分镜时，THE 视频提示词生成 Agent SHALL 在提示词中完整保留台词原文（禁止翻译），并正确标注台词类型（普通对白 `dialogue`、内心独白 `inner monologue OS`、画外音 `voiceover VO`）。

2. WHEN 视频提示词生成 Agent 处理 Seedance 2.0 模型时，THE 视频提示词生成 Agent SHALL 使用中文结构化格式，包含 `画面风格和类型`、`分镜N<duration-ms>` 段落，并为有台词的角色生成 9 维度音色描述（性别、年龄音色、音调、音色质感、声音厚度、发音方式、气息、语速、特殊质感）。

3. WHEN 视频提示词生成 Agent 处理多参模式时，THE 视频提示词生成 Agent SHALL 按资产输入顺序从 `@图1` 开始编号，分镜图编号接续资产编号，`shouldGenerateImage="false"` 的分镜不分配编号。

4. WHEN 视频提示词生成 Agent 生成提示词时，THE 视频提示词生成 Agent SHALL 严格基于 `videoDesc` 字段的内容生成，禁止编造 `videoDesc` 中未包含的画面内容或台词。

5. WHEN 视频提示词生成 Agent 处理首尾帧模式时，THE 视频提示词生成 Agent SHALL 生成全程单一连贯镜头的提示词（不切镜），`[Motion]` 时间轴每段最低 1 秒，并为每个主体标注说话状态（`speaking`/`silent`）。

6. IF 视频提示词生成 Agent 未收到明确的模型指定，THEN THE 视频提示词生成 Agent SHALL 默认使用模式 A（Seedream 中文 Prompt），并在输出前询问用户确认。

---

### 需求 8：功能完善 — 现有流水线缺失环节补齐

**用户故事：** 作为短剧创作者，我希望整个生成流水线是完整闭环的，不存在需要手动干预的断点，从小说导入到最终视频提示词生成都能在平台内完成。

#### 验收标准

1. WHEN 用户在 ScriptAgent 工作台发起改编时，THE System SHALL 在项目初始化阶段校验用户输入的章节范围，调用 `get_novel_events` 验证章节 ID 是否存在，若包含不存在的章节 ID 则立即提示用户修正，禁止使用不存在的章节 ID 继续执行。

2. WHEN ScriptAgent 阶段 3（剧本编写）循环派发时，THE ScriptAgent 决策层 SHALL 单次循环上限为 5 集，超过 5 集须告知用户并等待确认，防止上下文超载。

3. WHEN ProductionAgent 阶段 5（分镜面板写入）完成后，THE ProductionAgent 决策层 SHALL 根据模型参数 `多参` 决定写入模式（纯文本多参模式 / 分镜图辅助多参模式 / 首位帧模式），并在派发指令中明确携带写入模式，禁止执行层自行判断模式。

4. WHEN ProductionAgent 执行层完成任务时，THE ProductionAgent 执行层 SHALL 返回简短确认后立即终止本次任务，禁止在确认后继续输出任何预览、复述或摘要内容。

5. WHEN 监督层 Agent 发现执行层未正常完成任务时，THE 决策层 SHALL 向用户汇报失败原因并终止当前阶段，禁止决策层自行接管执行层任务或在执行层异常时触发审核流程。

6. WHEN 用户请求删除剧本时，THE ScriptAgent SHALL 提示用户在道具本管理中手动删除，禁止 Agent 自行执行删除操作。

---

### 需求 9：画风与故事风格技能包集成

**用户故事：** 作为短剧创作者，我希望能为不同的短剧项目选择不同的画风（如真人古风写实、2D 国风等）和故事风格（如甜宠、玄幻等），系统能自动将对应的风格规范注入到生成流水线中。

#### 验收标准

1. WHEN ProductionAgent 执行导演规划时，THE ProductionAgent SHALL 加载当前项目配置的画风技能包中的 `director_planning_style.md`，并以该文件为风格基准，冲突时以风格技法参考为准。

2. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 加载当前项目配置的画风技能包中的 `director_storyboard_table_style.md`，确保光影描述与风格规范一致。

3. WHEN ProductionAgent 写入分镜面板时，THE ProductionAgent SHALL 加载当前项目配置的画风技能包中的 `director_storyboard.md`，作为提示词生成的风格专属技法参考。

4. WHERE 画风技能包包含 `prefix.md`，THE ProductionAgent SHALL 在生成所有图像提示词时将 `prefix.md` 中的全局约束规则（必守规则和严禁项）注入到提示词生成上下文中。

5. WHERE 故事风格技能包（StoryStyle）已配置，THE ScriptAgent SHALL 在生成故事骨架时加载对应风格的叙事规范，确保情绪曲线、付费卡点设计和集末钩子类型符合风格定义。

6. THE System SHALL 支持在项目创建或设置时选择画风技能包和故事风格技能包，选择后的配置持久化到项目记录中，后续所有 Agent 任务自动使用该配置。

---

### 需求 10：事件提取质量

**用户故事：** 作为短剧创作者，我希望从原著章节中提取的事件信息准确、结构化，能够支撑后续的剧本改编，特别是主线关系判断和预估集长要准确。

#### 验收标准

1. WHEN 事件提取 Agent 处理章节原文时，THE 事件提取 Agent SHALL 输出严格符合管道分隔格式的单行结果（以 `|` 开头、以 `|` 结尾、恰好 7 个字段），禁止在结果行前后输出任何引导语、解释或总结。

2. WHEN 事件提取 Agent 判断主线关系时，THE 事件提取 Agent SHALL 使用 `强/中/弱（3-8字理由）` 格式，其中"强"表示直接推动主角弧线，"中"表示补充世界观/人物关系/伏笔，"弱"表示过渡/气氛。

3. WHEN 事件提取 Agent 估算集长时，THE 事件提取 Agent SHALL 以秒为单位输出（格式：`X秒`），禁止使用分钟单位；高密度+高情绪章节估算 45-60 秒，中等密度估算 35-45 秒，低密度估算 25-35 秒。

4. WHEN 事件提取 Agent 提取核心事件时，THE 事件提取 Agent SHALL 确保核心事件描述包含动作和结果（30-60 字），忠于原文，禁止推测或脑补原文未出现的情节。

5. FOR ALL 章节原文输入，THE 事件提取 Agent SHALL 保持角色称呼与原文一致，多条平行事件线时选择对主角影响最大的一条，其余简要带过。

---

### 需求 11：技能文件一致性与规范统一

**用户故事：** 作为平台开发者，我希望各技能文件中的规则标准保持一致，执行层与监督层之间不存在相互矛盾的阈值或策略，避免 Agent 在执行与审核时产生冲突。

#### 验收标准

1. WHEN ProductionAgent 执行层构建分镜表时，THE ProductionAgent 执行层 SHALL 以「禁止连续 3 条以上使用完全相同景别」为景别连续性阈值；WHEN ProductionAgent 监督层审核分镜表时，THE ProductionAgent 监督层 SHALL 使用相同的阈值（连续 3 条以上同景别），禁止执行层与监督层使用不同的景别连续性判断标准。

2. WHEN ScriptAgent 决策层开始新会话时，THE ScriptAgent 决策层 SHALL 仅在用户明确要求回想时才调用 `deepRetrieve`，与 ProductionAgent 决策层的主动检索策略保持一致；两个 Agent 体系的 `deepRetrieve` 触发策略须在各自技能文件中明确声明且不相互矛盾。

3. WHEN 任意技能文件中的数值阈值（如景别连续上限、情绪强度连续上限、定场镜头数量上限等）发生变更时，THE System SHALL 确保执行层技能文件与监督层技能文件中的对应阈值同步更新，禁止出现执行层与监督层阈值不一致的情况。

4. WHEN ProductionAgent 执行层规定某项视觉连续性铁律时，THE ProductionAgent 监督层 SHALL 在分镜表审核维度中包含对该铁律的对应审核项，确保执行层的每条强制规则都有监督层的对应审核覆盖。

5. WHEN ScriptAgent 技能文件中定义了付费卡点设计规范时，THE ScriptAgent 执行层 SHALL 在剧本编写阶段的自查清单中包含「付费卡点是否在对应集数的对应位置落地」检查项，确保骨架设计的付费卡点在剧本中得到实现。

---

### 需求 12：监督层审核维度完善

**用户故事：** 作为短剧创作者，我希望监督层能够全面审核执行层的产出物，不遗漏任何影响最终视频质量的关键维度，特别是视觉连续性、情绪渐进、台词时长匹配等执行层已有规则的对应审核。

#### 验收标准

1. WHEN ProductionAgent 监督层执行分镜表审核时，THE ProductionAgent 监督层 SHALL 包含「视觉连续性」专项审核维度，逐项检查动作连续性、景别递进法则、视轴守恒（180度线原则）、朝向空间逻辑、信息控制意识、节拍密度约束、头尾安全区共 7 条视觉连续性铁律是否被遵守。

2. WHEN ProductionAgent 监督层执行分镜表审核时，THE ProductionAgent 监督层 SHALL 包含「情绪渐进」专项审核维度，检查同一角色在相邻分镜中的情绪强度是否遵循渐进变化原则，禁止出现连续 3 条以上同情绪强度的分镜。

3. WHEN ProductionAgent 监督层执行分镜表审核时，THE ProductionAgent 监督层 SHALL 包含「台词-时长匹配」审核维度，验证含台词分镜的 `duration` 是否不短于台词字数除以对应情绪语速（愤怒 ~4 字/秒、正常 ~3 字/秒、悲伤 ~2 字/秒）向上取整后加 1 秒安全余量。

4. WHEN ProductionAgent 监督层执行导演规划审核时，THE ProductionAgent 监督层 SHALL 包含「转场策略」审核维度，检查导演规划的⑥转场与视觉连续性维度是否完整输出（场间转场策略、段落间过渡手法、视觉连续性锚点），并验证转场策略与叙事节奏的一致性。

5. WHEN ProductionAgent 监督层执行分镜表审核时，THE ProductionAgent 监督层 SHALL 包含「定场镜头数量」审核维度，检查每个新场景的定场镜头是否不超过 2 个，标注超过 2 个定场镜头的场景。

6. WHEN ScriptAgent 监督层执行剧本正文审核时，THE ScriptAgent 监督层 SHALL 包含「情绪具象化」审核维度，检查 △ 描述中是否使用了具象动作链（至少 2 个连续动作）而非抽象情绪词（如"感到悲伤""很开心"等），标注使用抽象情绪词的场景。

7. WHEN ScriptAgent 监督层执行故事骨架审核时，THE ScriptAgent 监督层 SHALL 包含「钩子类型多样性」审核维度，检查全部集数的集末钩子类型是否多样化（悬念钩子、情感钩子、智识钩子、世界观钩子），标注连续 3 集以上使用同一类型钩子的情况。

8. WHEN ScriptAgent 监督层执行改编策略审核时，THE ScriptAgent 监督层 SHALL 包含「短剧平台适配」审核维度，检查改编策略是否明确了竖屏短视频的核心约束（单句台词不超过 20 字、开场 30 秒内必须有冲突或悬念建立点），标注缺失这些约束的改编策略。

---

### 需求 13：风格技能包完整性与联动

**用户故事：** 作为短剧创作者，我希望画风技能包和故事风格技能包能够覆盖整个生成流水线的所有阶段，包括故事骨架搭建、剧本编写、视频提示词生成等，而不仅仅是导演规划和分镜表阶段。

#### 验收标准

1. WHEN ProductionAgent 执行导演规划时，THE ProductionAgent SHALL 在「风格技法参考」章节中动态加载当前项目配置的画风技能包 `director_planning_style.md` 和故事风格技能包 `director_planning_narrative.md`，禁止该章节为空；若技能包未配置，THE ProductionAgent SHALL 使用内置默认规范并在输出中注明。

2. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 在「风格技法参考」章节中动态加载当前项目配置的画风技能包 `director_storyboard_table_style.md` 和故事风格技能包 `director_storyboard_table_narrative.md`，禁止该章节为空。

3. WHEN ScriptAgent 执行层执行导演规划的「声音与音乐方向」规划时，THE ScriptAgent 执行层 SHALL 优先以故事风格技能包中的声音规范为准；IF 故事风格技能包未配置，THEN THE ScriptAgent 执行层 SHALL 使用内置默认声音规范（乐器选择、组合策略、环境音设计），禁止该维度输出为空。

4. WHERE 故事风格技能包（StoryStyle）已配置，THE ScriptAgent 执行层 SHALL 在故事骨架搭建阶段加载对应风格的骨架叙事规范文件（`script_execution_skeleton_narrative.md`），确保三幕结构划分、分集策略和付费卡点设计符合风格定义；IF 该文件不存在，THE System SHALL 降级使用 `director_planning_narrative.md` 中的叙事规范。

5. WHERE 故事风格技能包（StoryStyle）已配置，THE ScriptAgent 执行层 SHALL 在剧本编写阶段加载对应风格的剧本叙事规范文件（`script_execution_script_narrative.md`），确保台词风格、场景描写和情绪表达符合风格定义；IF 该文件不存在，THE System SHALL 降级使用 `director_planning_narrative.md` 中的叙事规范。

6. WHERE 画风技能包（ArtStyle）已配置，THE ProductionAgent SHALL 在视频提示词生成阶段加载对应画风的视频提示词专属规范文件（`video_prompt_style.md`），包含该画风的风格锚定词、负向词模板和画质锁定词；IF 该文件不存在，THE ProductionAgent SHALL 使用通用基础技法规范。

7. THE System SHALL 定义统一的画风技能包文件结构规范，要求每个画风技能包目录必须包含以下文件：`prefix.md`、`director_planning_style.md`、`director_storyboard_table_style.md`、`director_storyboard.md`；WHEN 系统加载画风技能包时，THE System SHALL 检查必需文件是否存在，缺失时记录警告日志并降级使用通用规范。

8. THE System SHALL 支持在项目初始化参数表中明确包含「画风技能包」和「故事风格技能包」两个配置项，ScriptAgent 决策层在项目初始化阶段必须向用户确认这两个配置，确认后持久化到项目记录中供所有后续 Agent 任务自动加载。

---

### 需求 14：剧本质量强化

**用户故事：** 作为短剧创作者，我希望生成的剧本在格式规范、内容质量和平台适配性上都达到专业水准，包括正确的旁白格式、强制的开场冲突、可视化的情绪曲线，以及与资产包一致的角色描写。

#### 验收标准

1. WHEN ScriptAgent 执行层编写剧本时，THE ScriptAgent 执行层 SHALL 使用正确的旁白格式：画外音使用 `OS（{人物名}，{情绪}）：` 格式（Off Screen），旁白使用 `V.O.（{人物名}，{情绪}）：` 格式（Voice Over），禁止将 `V.S.` 用于旁白格式（V.S. 不是标准剧本旁白缩写）。

2. WHEN ScriptAgent 执行层编写剧本时，THE ScriptAgent 执行层 SHALL 在自查清单中包含「开场冲突」检查项，确保每集剧本的前 3 个场景（约前 30 秒）包含至少一个冲突或悬念建立点，禁止以纯环境描写或人物介绍开场。

3. WHEN ScriptAgent 执行层编写剧本时，THE ScriptAgent 执行层 SHALL 在自查清单中包含「情绪曲线」检查项，验证本集剧本的情绪曲线是否符合故事骨架中该集的情绪设计，确保包含至少 3 个不同强度层次（低强度铺垫、中强度推进、高强度高潮）。

4. WHEN ScriptAgent 执行层编写剧本时，THE ScriptAgent 执行层 SHALL 在自查清单中包含「资产一致性」检查项：WHEN 剧本中出现资产包中不存在的角色或场景时，THE ScriptAgent 执行层 SHALL 在剧本中使用资产包中已有的最接近资产，并在确认消息中注明差异；禁止在剧本中描写资产包中完全不存在的角色外貌或场景特征。

5. WHEN ScriptAgent 执行层构建故事骨架时，THE ScriptAgent 执行层 SHALL 在分集决策中为每集逐集追踪角色弧线推进情况，在集末钩子之后标注「角色弧推进：{本集主角内在变化一句话描述}」，确保每集都有可验证的角色弧推进记录。

6. WHEN ScriptAgent 执行层构建故事骨架时，THE ScriptAgent 执行层 SHALL 确保集末钩子类型在全部集数中多样化分布，在骨架自查清单中增加「钩子类型多样性」检查项，禁止连续 3 集以上使用同一类型钩子（悬念钩子、情感钩子、智识钩子、世界观钩子）。

7. WHEN ScriptAgent 执行层制定改编策略时，THE ScriptAgent 执行层 SHALL 在改编策略中明确声明竖屏短视频平台约束：单句台词不超过 20 字、开场 30 秒内必须有冲突或悬念建立点、每集结尾必须有集末钩子；这些约束须在改编策略阶段确立，而非仅在剧本编写阶段执行。

8. WHEN ScriptAgent 执行层编写剧本时，THE ScriptAgent 执行层 SHALL 在自查清单中包含「付费卡点落地」检查项，验证当前集是否为骨架中标注的付费卡点集，若是则确认付费卡点内容（悬念、情感高潮或世界观揭示）已在对应位置实现。

---

### 需求 15：资产管理增强

**用户故事：** 作为短剧创作者，我希望资产提取和管理系统能够预判衍生资产需求、对资产进行重要性分级，减少后续阶段的重复读取，提升整体流水线效率。

#### 验收标准

1. WHEN 资产提取 Agent 处理剧本时，THE 资产提取 Agent SHALL 在提取主资产（角色/场景/道具）的同时，对每个主资产标注「衍生潜力」字段（高/中/低），判断依据为：剧本中是否出现该资产的明显视觉状态变化描写（服装变化、伤势、场景时间变体等）；「高」表示剧本中有明确描写，「中」表示有暗示，「低」表示无变化迹象。

2. WHEN 资产提取 Agent 完成提取时，THE 资产提取 Agent SHALL 对所有资产按重要性分级：主要角色（直接推动主线剧情的角色）、次要角色（辅助叙事的角色）、背景角色（群演/路人）；分级结果写入资产的 `importance` 字段，供后续分镜构建时优先引用主要角色资产。

3. WHEN ProductionAgent 执行衍生资产分析时，THE ProductionAgent SHALL 优先读取资产提取阶段标注的「衍生潜力」为「高」的资产，减少对完整剧本的重复读取；仅当「衍生潜力」标注不足以判断时，才补读对应剧本窗口。

4. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 在 `associateAssetsIds` 字段中优先引用主要角色资产（`importance: 主要角色`），确保主角在每个出现的分镜中都被正确关联；次要角色和背景角色在画面中可辨识时也须关联，但优先级低于主要角色。

---

### 需求 16：视频提示词质量增强

**用户故事：** 作为短剧创作者，我希望视频提示词生成系统能够处理情绪与音色的联动、批量生成时的角色一致性，以及空镜/过渡镜头的专项处理，使生成的视频在情绪表达和视觉连贯性上更加专业。

#### 验收标准

1. WHEN 视频提示词生成 Agent 处理 Seedance 2.0 模型的含台词分镜时，THE 视频提示词生成 Agent SHALL 根据角色当前情绪状态动态调整 9 维度音色描述中的语速、气息和音调参数：愤怒/急促情绪对应语速偏快、气息急促、音调偏高；悲伤/深情情绪对应语速偏慢、气息绵长、音调偏低；正常对话情绪使用角色类型默认音色；禁止对所有情绪状态使用相同的默认音色描述。

2. WHEN 视频提示词生成 Agent 批量处理多条分镜的视频提示词时，THE 视频提示词生成 Agent SHALL 在处理前建立「角色外观一致性基准表」，记录每个角色在首次出现分镜中的外观描述（服饰、发型、体型等关键特征），后续分镜中同一角色的外观描述必须与基准表一致，禁止同一角色在不同分镜的提示词中出现外观描述不一致的情况。

3. WHEN 视频提示词生成 Agent 处理空镜分镜（`action` 字段为 `空镜` 或无角色出现的环境镜头）时，THE 视频提示词生成 Agent SHALL 应用空镜专项处理规则：不添加角色一致性约束语句，重点描述环境氛围、光影变化和与前后镜头的情绪衔接关系；空镜提示词须包含「承接前镜氛围」和「引导后镜情绪」的过渡描述。

4. WHEN 视频提示词生成 Agent 处理通用多参模式的批量分镜时，THE 视频提示词生成 Agent SHALL 确保同一角色在所有分镜的 `[Instruction]` 中使用相同的 `@图N` 编号引用，禁止同一角色在不同分镜中被分配不同的 `@图N` 编号。

5. WHEN 视频提示词生成 Agent 处理 Seedance 2.0 模型的无台词分镜时，THE 视频提示词生成 Agent SHALL 在动作描述后明确标注「无台词」，禁止省略该标注或用空白代替，确保模型不会误生成口型动作。

---

### 需求 17：执行层健壮性

**用户故事：** 作为平台运营者，我希望执行层在面对边界情况时能够稳健处理，包括长剧本的扩读策略、跨批次连续性保障、videoDesc 质量规范，以及用户主动要求重新生成分镜图时的处理逻辑。

#### 验收标准

1. WHEN ProductionAgent 执行层生成 `videoDesc` 字段时，THE ProductionAgent 执行层 SHALL 确保 `videoDesc` 包含以下维度：画面描述（15-50 字）、场景名称、关联资产名称、时长（秒）、景别、运镜、角色动作（首帧预备状态）、情绪（具象可感描述）、光影氛围（含光源方向+色调+明暗关系）、台词（原文或「无台词」）、音效（或「无音效」）、关联资产 ID；禁止 `videoDesc` 中出现「感到悲伤」等抽象情绪词或「柔光」等模糊光影描述。

2. WHEN ProductionAgent 执行层读取剧本进行衍生资产分析时，THE ProductionAgent 执行层 SHALL 默认读取 `lineStart:1, lineEnd:48` 的剧本窗口；WHEN 当前窗口内容不足以判断所有资产的衍生需求时（如剧本超过 48 行且后半段有明显视觉状态变化描写），THE ProductionAgent 执行层 SHALL 按需补读下一个窗口（`lineStart:49, lineEnd:96`），直至覆盖完整剧本；禁止在信息已足够时继续扩读。

3. WHEN ProductionAgent 执行层处理超过一个窗口（8 行）的分镜表时，THE ProductionAgent 执行层 SHALL 在切换到下一批分镜窗口前，记录上一批最后一条分镜的角色位置、情绪状态和动作终态，并在下一批首条分镜的 `action` 字段中标注与上一批末镜的衔接关系，确保跨批次的视觉连续性。

4. WHEN 用户明确要求重新生成特定分镜图时，THE ProductionAgent 执行层 SHALL 识别用户指定的分镜 ID 列表，对这些分镜执行重新生成流程（即使这些分镜已有 `src` 图片结果），调用 `generate_storyboard({ ids: [用户指定的分镜ID列表] })`；禁止因分镜已有图片而拒绝重新生成请求。

5. WHEN 事件提取 Agent 处理章节原文时，THE 事件提取 Agent SHALL 在 7 个标准字段之外，为每个章节额外输出「场景可制作性」评估（格式：`可制作性:{高/中/低}({1-3字原因})`），评估依据为：特效复杂度（高复杂度如大规模战争场面降低可制作性）、同场人物数量（超过 5 人降低可制作性）、场景切换频率（单章超过 3 次场景切换降低可制作性）。

6. WHEN 事件提取 Agent 处理章节原文时，THE 事件提取 Agent SHALL 在 7 个标准字段之外，为每个章节额外输出「付费卡点潜力」标注（格式：`付费潜力:{有/无}({1-5字类型})`），判断依据为：章节末尾是否存在悬念未解、情感高潮、世界观揭示或重大转折；「有」时标注类型（悬念/情感/世界观/转折），供骨架设计阶段直接引用，减少重复判断的 token 消耗。

---

### 需求 18：决策层错误处理与重试机制漏洞

**用户故事：** 作为平台运营者，我希望决策层在执行层失败时有明确的重试上限和降级策略，避免无限重试消耗 token，同时确保失败信息能准确传达给用户。

#### 验收标准

1. WHEN ProductionAgent 决策层收到执行层返回错误时，THE ProductionAgent 决策层 SHALL 最多重试 2 次（当前文件已有此规则），但须在每次重试前调整派发指令（修正可能导致失败的参数或约束），禁止用完全相同的指令重试；第 3 次仍失败时，必须向用户汇报具体失败原因并终止当前阶段，不得继续重试。

2. WHEN ScriptAgent 决策层收到执行层返回错误时，THE ScriptAgent 决策层 SHALL 向用户汇报失败原因并终止当前阶段；当前文件规定「不得触发后续审核」，但缺少「不得重试」的明确约束——THE ScriptAgent 决策层 SHALL 在执行层失败后禁止自动重试，必须等待用户明确指示后才能重新派发。

3. WHEN 任意决策层向监督层派发审核任务时，THE 决策层 SHALL 在派发指令中携带执行层返回的原始确认消息（不超过 50 字摘要），供监督层作为审核上下文；禁止监督层在没有执行层产出物确认的情况下开始审核。

4. WHEN ProductionAgent 决策层的 `deepRetrieve` 检索无结果时，THE ProductionAgent 决策层 SHALL 向用户明确说明「无法确认当前进度，请告知当前所处阶段」，禁止基于猜测自行判断进度并派发任务；当前文件「记忆检索无结果 → 请求用户提供必要上下文」的规则需补充：必须列出流水线六个阶段供用户选择，而非开放式询问。

5. WHEN ProductionAgent 决策层在阶段5询问用户写入模式时，THE ProductionAgent 决策层 SHALL 在询问消息中同时说明三种模式的适用场景（纯文本多参模式适用于后续手动配图、分镜图辅助多参模式适用于已有分镜图、首位帧模式适用于首尾帧视频生成），禁止仅列出模式名称而不说明区别，避免用户无法做出有效选择。

---

### 需求 19：分镜表执行流程编号错误与逻辑漏洞

**用户故事：** 作为平台开发者，我希望技能文件中的执行流程步骤编号正确、逻辑无歧义，避免 Agent 因步骤编号混乱而跳过关键步骤或重复执行。

#### 验收标准

1. WHEN 剧本编写执行层按执行流程运行时，THE 剧本编写执行层 SHALL 按正确的步骤顺序执行；当前 `script_execution_script.md` 执行流程存在步骤编号重复错误（步骤 1-4 后跳回步骤 2、3、4），THE System SHALL 修正执行流程步骤编号为连续递增（1→2→3→4→5），确保 Agent 不会因编号混乱而重复执行或跳过步骤。

2. WHEN 分镜面板写入执行层按执行流程运行时，THE 分镜面板写入执行层 SHALL 在步骤 1 中优先使用派发指令中的 `storyboardIds` 精确读取，而非默认窗口读取；当前文件步骤 1 描述「识别写入模式」的逻辑放在窗口读取之后，THE System SHALL 将写入模式识别逻辑前置到步骤 1 开始处，确保在任何数据读取之前先确认写入模式，避免为不需要提示词的「纯文本多参模式」加载不必要的技法文件。

3. WHEN 导演规划执行层执行步骤 4（上游监督要求 `check_assets`）时，THE 导演规划执行层 SHALL 在资产核对完成后明确判断「缺口是否闭合」，若缺口未闭合（存在规划中引用但资产库中不存在的资产），THE 导演规划执行层 SHALL 向决策层返回「资产缺口未闭合：{缺失资产列表}」，禁止在资产缺口未闭合时继续生成 `scriptPlan`。

4. WHEN 分镜图生成执行层执行步骤 2（筛选缺帧镜头）时，THE 分镜图生成执行层 SHALL 同时检查 `shouldGenerateImage=true` 且 `src` 为空两个条件；当前文件描述「没有 `src` / 图片结果」表述模糊，THE System SHALL 明确定义：`src` 为 `null`、空字符串、或图片生成状态为 `failed` 的镜头均视为缺帧镜头，需要重新生成。

---

### 需求 20：监督层审核数据准备的边界情况

**用户故事：** 作为平台运营者，我希望监督层在审核时能够正确处理数据量超出单次读取限制的情况，避免因数据截断导致审核结论不准确。

#### 验收标准

1. WHEN ProductionAgent 监督层审核导演规划时，THE ProductionAgent 监督层 SHALL 使用 `get_flowData({ key: "scriptPlan", maxChars: 2200 })` 读取规划数据；当导演规划内容超过 2200 字时（执行层规定总字数不超过 1200 词，约 2400 字），THE ProductionAgent 监督层 SHALL 检测到截断并补读剩余内容，禁止基于截断数据给出「完整性」相关的审核结论。

2. WHEN ProductionAgent 监督层审核分镜表时，THE ProductionAgent 监督层 SHALL 默认读取首批 8 行；当分镜表超过 8 行时，THE ProductionAgent 监督层 SHALL 在审核报告中明确标注「已审核前 N 行，共 M 行，剩余行未审核」，禁止基于部分数据给出「全表通过」的审核结论；若需全表审核，须逐窗口读取直至覆盖全部行。

3. WHEN ScriptAgent 监督层审核故事骨架时，THE ScriptAgent 监督层 SHALL 在读取骨架数据时使用 `maxChars` 参数；当骨架内容（特别是模式B的分集总览表，可能超过 3000 字）超过 `maxChars` 限制时，THE ScriptAgent 监督层 SHALL 分批读取并合并审核，禁止因数据截断遗漏对分集总览表后半部分的审核。

4. WHEN ScriptAgent 监督层执行「章节全覆盖」审核时，THE ScriptAgent 监督层 SHALL 将骨架中的章节列表与事件表中的章节列表逐一比对；当前审核维度只检查「骨架中的章节是否在事件表中存在」，缺少反向检查——THE ScriptAgent 监督层 SHALL 同时检查「事件表中的章节是否全部出现在骨架中」，标注事件表有但骨架未分配的章节。

5. WHEN ProductionAgent 监督层执行「资产匹配」审核时，THE ProductionAgent 监督层 SHALL 不仅检查「规划中引用的资产是否在 assets 中存在」，还须检查「规划中引用的衍生资产状态是否已在阶段1写入」；若规划引用了某角色的特定衍生状态（如「染血版」），但该衍生资产尚未在 `assets.derive` 中创建，THE ProductionAgent 监督层 SHALL 将其标注为严重问题。

---

### 需求 21：剧本编写输出格式规范漏洞

**用户故事：** 作为短剧创作者，我希望生成的剧本格式严格统一，不出现章节编号跳跃、缺失「出场角色表」和「场景表」等格式问题，确保后续资产提取和分镜制作能够顺利进行。

#### 验收标准

1. WHEN 剧本编写执行层按输出格式规范生成剧本时，THE 剧本编写执行层 SHALL 在「剧情梗概」之后、「剧本正文」之前输出「出场角色表」和「场景表」；当前 `script_execution_script.md` 的执行流程第 4 步提到「文件头 → 剧情梗概 → 出场角色表 → 场景表 → 剧本正文」，但「输出格式规范」章节只定义了「一、文件头」「二、剧情梗概」「三、剧本内容结构」，缺少「出场角色表」和「场景表」的格式定义，THE System SHALL 补充这两个章节的格式规范。

2. WHEN 剧本编写执行层生成「出场角色表」时，THE 剧本编写执行层 SHALL 按格式输出本集出场的所有角色，包含角色名、身份简介（10 字以内）、本集戏份比重（主要/次要/客串）；出场角色表须与资产包中的角色名称保持一致，禁止使用资产包中不存在的角色名称。

3. WHEN 剧本编写执行层生成「场景表」时，THE 剧本编写执行层 SHALL 按格式输出本集涉及的所有场景，包含场景名、时间（日/夜/晨/黄昏）、光线（内/外）、出现集数中的场次编号；场景名须与资产包中的场景名称保持一致，禁止使用资产包中不存在的场景名称。

4. WHEN 剧本编写执行层的自查清单包含「角色外貌描写符合资产包」和「场景描写符合资产包」时，THE 剧本编写执行层 SHALL 将这两项自查的具体校验方法明确化：逐一检查剧本中出现的角色名称是否在出场角色表中，逐一检查场景名称是否在场景表中；发现不一致时直接修正剧本，而非仅标注问题。

5. WHEN 剧本编写执行层的「禁止输出的内容」规则与「输出格式规范」存在冲突时（如「禁止输出幕/节拍时间标注」但格式规范中有「节拍概要」字段），THE System SHALL 明确优先级：「禁止输出」规则优先于格式规范中的可选字段，「节拍概要」字段仅输出简短标签（如「三幕式」「情绪意境型」），禁止展开为带时间戳的幕结构。

---

### 需求 22：资产提取 Agent 输出规范漏洞

**用户故事：** 作为短剧创作者，我希望资产提取 Agent 的输出格式严格统一，特别是 `resultTool` 调用的时机和完整性，避免分批调用导致资产列表不完整。

#### 验收标准

1. WHEN 资产提取 Agent 完成剧本分析时，THE 资产提取 Agent SHALL 一次性将所有资产放入 `assetsList` 数组中调用 `resultTool`，禁止分多次调用；当前文件已有此规则，但缺少「调用 `resultTool` 前的完整性自查」约束——THE 资产提取 Agent SHALL 在调用 `resultTool` 前自查：角色数量是否覆盖剧本中所有有名字的角色、场景数量是否覆盖所有出现的地点、道具数量是否覆盖所有有独立剧情功能的物件。

2. WHEN 资产提取 Agent 生成角色 `prompt` 时，THE 资产提取 Agent SHALL 在提示词中包含角色的性别、年龄段、发型发色、服饰风格、体型气质等至少 5 个视觉维度；当前文件只给出示例格式，缺少最低维度数量约束，可能导致生成过于简短的提示词（如仅「a young man, black hair」）无法支撑 AI 图片生成。

3. WHEN 资产提取 Agent 生成场景 `prompt` 时，THE 资产提取 Agent SHALL 在提示词中包含空间类型（室内/室外）、建筑风格、光照条件、色调基调、关键陈设至少 5 个视觉维度；缺少最低维度约束可能导致场景提示词过于简短，无法生成风格统一的场景图。

4. WHEN 资产提取 Agent 处理同一角色有多个称呼时，THE 资产提取 Agent SHALL 使用「最常用称呼」作为 `name` 字段，并在 `desc` 字段中注明其他称呼（格式：`又称{称呼1}/{称呼2}`）；当前文件只规定「取最常用的作为 name」，缺少「其他称呼记录」的要求，可能导致后续分镜中使用别称时无法匹配到对应资产。

5. WHEN 资产提取 Agent 判断道具是否需要提取时，THE 资产提取 Agent SHALL 使用明确的判断标准：道具在剧本中被角色持有/使用超过 1 次、或道具是推动剧情的关键物件（如信物、武器、证据）、或道具有独特外观需要 AI 图片生成保持一致性；禁止仅凭「通用物品」的主观判断跳过道具提取，导致后续分镜中出现无法关联资产的重要道具。

---

### 需求 23：跨 Agent 数据传递完整性

**用户故事：** 作为平台运营者，我希望各阶段 Agent 之间的数据传递是完整且可验证的，特别是项目配置在整个流水线中的传递，以及监督层审核结论对下一阶段的影响。

#### 验收标准

1. WHEN ScriptAgent 决策层向执行层派发任务时，THE ScriptAgent 决策层 SHALL 在派发指令头部附带完整的【项目配置】（集数、单集时长、原著范围、章节ID列表、平台规格、风格定位、付费策略）；当前文件已有此规则，但缺少「画风技能包」和「故事风格技能包」两个配置项——THE ScriptAgent 决策层 SHALL 在【项目配置】模板中增加这两个字段，确保执行层能够自动加载对应风格规范。

2. WHEN ProductionAgent 决策层向执行层派发任务时，THE ProductionAgent 决策层 SHALL 在派发指令中携带当前项目的「画风技能包路径」和「故事风格技能包路径」；当前 `production_agent_decision.md` 的派发指令模板中没有风格技能包路径字段，导致执行层无法确定加载哪个风格技能包，THE System SHALL 在派发指令模板中增加风格配置字段。

3. WHEN ProductionAgent 监督层在 `reviewSummary` 中输出 `nextAction="revise_storyboardTable"` 时，THE ProductionAgent 决策层 SHALL 在向执行层派发修复指令时，将 `reviewSummary` 中的 `storyboardIds` 字段传递给执行层，确保执行层只修复监督层指定的分镜行，禁止执行层重新读取整张分镜表后自行判断修复范围。

4. WHEN ScriptAgent 监督层在 `reviewSummary` 中输出 `nextAction="check_novel_events"` 时，THE ScriptAgent 决策层 SHALL 向执行层派发「核对事件表」任务，并在派发指令中携带监督层报告中指出的具体问题（如「第X章章节覆盖缺失」），禁止执行层在没有具体问题描述的情况下重新读取整个事件表。

5. WHEN 任意阶段的执行层完成任务并返回确认消息时，THE 决策层 SHALL 将该确认消息原文（不超过 50 字）展示给用户，禁止决策层对执行层的确认消息进行改写或扩充；当前 `production_agent_decision.md` 规定「将执行层返回的确认消息展示给用户」，但 `script_agent_decision.md` 缺少对应规则，THE System SHALL 在 ScriptAgent 决策层中补充相同的规则。

---

### 需求 24：提示词模板与技能文件的版本管理

**用户故事：** 作为平台运营者，我希望当技能文件或提示词模板发生变更时，能够追踪变更历史，并在质量下降时快速回滚到上一个有效版本。

#### 验收标准

1. WHEN 技能文件（`backend/data/skills/` 下的任意 `.md` 文件）发生变更时，THE System SHALL 在变更提交时自动记录变更元数据到 `app_skill_versions` 表（或等效存储），包含：文件路径、变更时间戳、变更摘要（不超过 100 字）、变更前 SHA256 哈希、变更后 SHA256 哈希；禁止技能文件变更后无任何版本记录。

2. WHEN 提示词模板（`backend/data/prompt_defaults/` 下的任意 `.txt` 文件）发生变更时，THE System SHALL 使用与技能文件相同的版本记录机制，确保提示词模板的变更历史可追溯。

3. WHEN 用户在质量评审工作台查看某条评审记录时，THE System SHALL 展示该评审记录对应的技能文件版本信息（文件路径 + 变更时间戳），并提供「与当前版本对比」功能，高亮显示评审时使用的版本与当前版本之间的差异。

4. WHEN 平台管理员需要回滚某个技能文件到历史版本时，THE System SHALL 提供 `POST /api/v1/skill-versions/rollback` 接口，接受文件路径和目标版本时间戳，将文件内容恢复到指定版本；回滚操作须记录操作日志（操作人、回滚时间、从哪个版本回滚到哪个版本）。

5. WHEN 技能文件版本发生变更后，THE System SHALL 自动触发「影响范围分析」：检查哪些正在进行中的项目使用了该技能文件，并在工作台向相关项目的用户发送通知「技能文件已更新，建议重新审核相关阶段产出物」。

---

### 需求 25：分镜面板写入的 track 分组边界情况

**用户故事：** 作为短剧创作者，我希望分镜面板的 track 分组逻辑在各种边界情况下都能正确处理，特别是当单条分镜时长超过 15 秒时，以及跨场景分镜的分组策略。

#### 验收标准

1. WHEN 分镜面板写入执行层遇到单条分镜 `duration` 超过 15 秒时（如一镜到底镜头，上限 12 秒，但分镜表中可能存在超时记录），THE 分镜面板写入执行层 SHALL 将该分镜单独作为一组（独立 track），并在 `videoDesc` 中标注「超时镜头，建议拆分」；禁止将超时镜头与其他镜头合并到同一 track 导致分组累计时长超过 15 秒。

2. WHEN 分镜面板写入执行层处理跨场景的分镜时（相邻两条分镜的 `scene` 字段不同），THE 分镜面板写入执行层 SHALL 在场景切换处强制开启新的 track 分组，禁止将不同场景的分镜合并到同一 track；当前文件只规定「累计时长 ≤ 15s」，缺少「跨场景强制换组」的约束。

3. WHEN 分镜面板写入执行层在「纯文本多参模式」下处理 track 分组时，THE 分镜面板写入执行层 SHALL 使用与「分镜图辅助多参模式」相同的分组规则（累计时长 ≤ 15s + 跨场景强制换组）；当前文件对纯文本多参模式的 track 分组规则描述为「同分镜图辅助多参模式」，但缺少明确的跨场景换组约束，需要补充。

4. WHEN 分镜面板写入执行层完成全部分镜写入后，THE 分镜面板写入执行层 SHALL 在返回确认消息前执行「行数一致性自查」：统计写入的 `storyboardItem` 数量，与 `storyboardTable` 的分镜数据行数量对比，若不一致则返回「写入行数不一致：分镜表 N 行，实际写入 M 行，请检查」，禁止在行数不一致时返回「已完成」。

5. WHEN 分镜面板写入执行层在「首位帧模式」下处理 track 时，THE 分镜面板写入执行层 SHALL 确保每条分镜的 `track` 值严格等于该分镜在分镜表中的行序号（第1行 track=1，第2行 track=2，以此类推），禁止因跳过 `shouldGenerateImage=false` 的行而导致 track 编号不连续；`shouldGenerateImage=false` 的行仍须分配连续的 track 编号。

---

### 需求 26：art_prompt 资产生成提示词与流水线的集成漏洞

**用户故事：** 作为短剧创作者，我希望资产图片生成时能自动加载对应画风的 art_prompt 规范，确保角色、场景、道具的生成提示词符合画风约束，而不是使用通用提示词。

#### 验收标准

1. WHEN ProductionAgent 执行层执行衍生资产图片生成（阶段2）时，THE ProductionAgent 执行层 SHALL 加载当前项目配置的画风技能包中 `art_prompt/` 目录下对应类型的规范文件（角色衍生加载 `art_character_derivative.md`、场景衍生加载 `art_scene_derivative.md`、道具衍生加载 `art_prop_derivative.md`）；当前执行层只调用 `generate_deriveAsset` 但没有加载任何 art_prompt 规范，导致生成的衍生资产图片可能不符合画风约束。

2. WHEN 资产提取 Agent 生成资产 `prompt` 字段时，THE 资产提取 Agent SHALL 加载当前项目配置的画风技能包中 `art_prompt/` 目录下对应类型的规范文件（角色加载 `art_character.md`、场景加载 `art_scene.md`、道具加载 `art_prop.md`），确保生成的提示词符合画风的面容约束、体型约束、服饰约束等规范；当前 `scriptAssetExtraction.txt` 使用通用提示词格式，未与画风技能包联动。

3. WHEN ProductionAgent 执行层生成分镜提示词时，THE ProductionAgent 执行层 SHALL 加载当前项目配置的画风技能包中的 `art_prompt/art_storyboard_video.md` 文件，将其中定义的视觉风格标签（如 `Chinese period drama, photorealistic, cinematic` 或 `古风写实摄影，电影风格`）注入到对应模式的视频提示词中；当前 `videoPromptGeneration.txt` 的「视觉风格约束」部分引用了 Assistant 中的内容，但没有明确说明从哪个文件加载。

4. WHEN 画风技能包的 `art_character.md` 定义了角色的「四视图设定图规范」时，THE 资产提取 Agent SHALL 在生成角色 `prompt` 时包含四视图输出要求（`character design sheet, character turnaround, 同一画面左至右并排：人像特写+正视图+侧视图+后视图`），确保生成的角色参考图包含多视角，而非单一正面图。

5. WHEN 画风技能包的 `art_character_derivative.md` 定义了「L1 妆容决策」规则时，THE ProductionAgent 执行层在生成衍生资产描述（`add_deriveAsset` 的 `desc` 字段）时 SHALL 包含妆容强度信息（基础妆/轻妆/正式妆），供后续图片生成时正确应用妆容约束；当前 `add_deriveAsset` 的 `desc` 字段格式为「与默认态的差异 · 视觉特征」，缺少妆容维度。

---

### 需求 27：故事风格技能包覆盖不完整

**用户故事：** 作为短剧创作者，我希望所有已有的故事风格技能包（12 个）都有完整的导演技能文件，而不是只有甜宠言情有内容，其他风格包的 `driector_skills/` 目录为空。

#### 验收标准

1. THE System SHALL 确保所有故事风格技能包（`Comedy_humor`、`Coming_of_age`、`Family_warmth`、`Historical_epic`、`Horror_supernatural`、`Hot_blooded_action`、`Mystery_thriller`、`Psychological_drama`、`Scifi_post_apocalypse`、`Sweet_romance_novel`、`Urban_workplace_drama`、`Xianxia_fantasy`）的 `driector_skills/` 目录下均包含 `director_planning_narrative.md` 和 `director_storyboard_table_narrative.md` 两个文件；当前只有 `Sweet_romance_novel`、`Xianxia_fantasy`、`Horror_supernatural` 等少数风格包有内容，其余风格包的 `driector_skills/` 目录为空。

2. WHEN 用户为项目选择了某个故事风格技能包时，THE System SHALL 在加载该风格包的导演技能文件前检查文件是否存在；IF 文件不存在，THEN THE System SHALL 向用户提示「当前风格包（{风格名称}）的导演技能文件尚未配置，将使用通用叙事规范」，禁止静默降级而不通知用户。

3. WHEN 新增故事风格技能包时，THE System SHALL 要求该风格包至少包含以下内容：`director_planning_narrative.md`（定义主题立意、叙事结构、情绪设计、声音方向）和 `director_storyboard_table_narrative.md`（定义景别选择、运镜节奏、时长把控、转场设计）；缺少任一文件的风格包不得被用户选择为项目配置。

4. WHERE 故事风格技能包的 `director_planning_narrative.md` 已配置，THE System SHALL 验证该文件包含以下必填章节：主题立意与情感内核、叙事结构与节奏规划、分场景情绪设计、声音与音乐方向；缺少任一章节的文件视为不完整，加载时记录警告日志。

---

### 需求 28：画风技能包的 art_prompt 目录结构不统一

**用户故事：** 作为平台开发者，我希望所有画风技能包的 art_prompt 目录结构完全一致，确保系统能够统一加载各类型的资产生成规范。

#### 验收标准

1. THE System SHALL 定义统一的画风技能包 `art_prompt/` 目录文件结构规范，要求每个画风技能包的 `art_prompt/` 目录必须包含以下 7 个文件：`art_character.md`（角色基础形象）、`art_character_derivative.md`（角色衍生服化）、`art_scene.md`（场景基础）、`art_scene_derivative.md`（场景衍生状态）、`art_prop.md`（道具基础）、`art_prop_derivative.md`（道具衍生状态）、`art_storyboard_video.md`（视频提示词风格标签）。

2. WHEN 系统加载画风技能包的 `art_prompt/` 文件时，THE System SHALL 检查 7 个必需文件是否全部存在；IF 任一文件缺失，THEN THE System SHALL 记录警告日志并降级使用通用资产生成规范，同时在工作台向用户显示「画风包 {画风名称} 的 {缺失文件名} 未配置，已使用通用规范」。

3. WHEN 画风技能包的 `art_storyboard_video.md` 定义了视频提示词风格标签时，THE System SHALL 确保该文件为三种视频生成模式（通用多参模式英文、通用首尾帧模式英文、Seedance 2.0 中文）分别定义风格标签；IF 某种模式的风格标签缺失，THEN THE System SHALL 使用通用基础技法中的默认风格标签。

4. WHEN 资产提取 Agent 或 ProductionAgent 执行层需要加载 `art_prompt/` 文件时，THE System SHALL 优先加载当前项目配置的画风技能包中的对应文件；IF 画风技能包未配置或文件不存在，THEN THE System SHALL 降级使用 `scriptAssetExtraction.txt` 或 `videoPromptGeneration.txt` 中的通用规范，并记录降级日志。

---

### 需求 29：分镜表「单镜头动作数量」与「节拍密度」规则冲突

**用户故事：** 作为短剧创作者，我希望分镜表中的动作数量约束在执行层和故事风格技能包之间保持一致，避免 Agent 因规则冲突而产生不合理的分镜设计。

#### 验收标准

1. WHEN ProductionAgent 执行层构建分镜表时，THE ProductionAgent 执行层 SHALL 遵循「节拍密度约束」：2~3s 镜头最多 1 拍、4~6s 镜头最多 2 拍、7s+ 镜头最多 3 拍；WHEN 故事风格技能包（如甜宠言情）规定「单镜头动作不超过两个」时，THE System SHALL 以「节拍密度约束」为优先规则（因为它更精确），故事风格技能包的「两个动作」规则作为补充说明，两者不冲突时同时遵守，冲突时以节拍密度约束为准。

2. WHEN 故事风格技能包的 `director_storyboard_table_narrative.md` 定义了与执行层技能文件不同的时长约束时（如甜宠言情规定「单镜头不超过 6s」，而执行层规定「单镜不超过 8s」），THE System SHALL 以故事风格技能包的约束为优先（更严格的约束优先），并在执行层技能文件中明确声明「当故事风格技能包有更严格的时长约束时，以风格包约束为准」。

3. WHEN 画风技能包的 `director_storyboard_table_style.md` 规定「古风动作要慢，所有人物动作默认慢速」时，THE ProductionAgent 执行层 SHALL 在构建分镜表的 `action` 字段时，对古风画风的动作描述添加速度修饰词（「缓缓」「徐徐」「轻轻」等），禁止使用「猛然」「急速」「快速」等与古风气质冲突的速度词；当前执行层的 `action` 字段规范没有与画风技能包的动作节奏约束联动。

4. WHEN 画风技能包的 `director_storyboard_table_style.md` 规定「每 3-4 个镜头至少安排一个有环境动态的镜头」时，THE ProductionAgent 监督层 SHALL 在分镜表审核中增加「环境动态密度」审核项，检查是否每 3-4 个镜头中有至少 1 个包含环境动态描述（花瓣飘落、烟雾升腾、水波荡漾、纱帘飘动等）；当前监督层没有此审核项。

---

### 需求 30：视频提示词生成中「视觉风格约束」来源不明确

**用户故事：** 作为短剧创作者，我希望视频提示词生成时能明确知道视觉风格约束来自哪个文件，避免因来源不明导致风格约束被遗漏或错误应用。

#### 验收标准

1. WHEN 视频提示词生成 Agent 处理分镜时，THE 视频提示词生成 Agent SHALL 按以下优先级加载视觉风格约束：①当前项目配置的画风技能包 `art_prompt/art_storyboard_video.md`（最高优先级）→ ②`videoPromptGeneration.txt` 中的通用基础规范（兜底）；当前文件中「视觉风格约束」部分描述为「参考 Assistant 中的视觉风格约束部分内容」，来源不明确，THE System SHALL 将此描述替换为明确的文件加载路径。

2. WHEN 视频提示词生成 Agent 在「通用首尾帧模式」下生成 `[Visual]` 段落时，THE 视频提示词生成 Agent SHALL 在视觉风格标签中包含画风技能包 `art_storyboard_video.md` 中定义的「通用首尾帧模式（英文）」风格标签；当前示例输出中使用了 `Cinematic, photorealistic, 4K, high contrast, desaturated tones, shallow depth of field`，但这是硬编码的通用标签，未从画风技能包动态加载。

3. WHEN 视频提示词生成 Agent 处理 Seedance 2.0 模式时，THE 视频提示词生成 Agent SHALL 在 `画面风格和类型` 字段中使用画风技能包 `art_storyboard_video.md` 中定义的「Seedance 2.0（中文）」风格标签；当前示例输出中使用了 `真人写实, 电影风格, 冷调, 古风`，但这是硬编码示例，未说明如何从画风技能包动态获取。

4. WHEN 视频提示词生成 Agent 未收到画风技能包配置时，THE 视频提示词生成 Agent SHALL 使用以下通用兜底风格标签：通用多参模式英文 `cinematic, photorealistic, high detail`、通用首尾帧模式英文 `cinematic, photorealistic, high detail, shallow depth of field`、Seedance 2.0 中文 `电影风格，写实，高细节`；禁止在没有风格标签的情况下生成视频提示词。

---

### 需求 31：衍生资产分析的「已存在衍生」去重逻辑漏洞

**用户故事：** 作为短剧创作者，我希望衍生资产分析时能正确识别已存在的衍生资产，避免重复创建相同的衍生状态，浪费 token 和存储空间。

#### 验收标准

1. WHEN ProductionAgent 执行层执行衍生资产分析时，THE ProductionAgent 执行层 SHALL 在读取候选资产时包含 `derive` 字段（当前工具调用已包含 `fields: ["id", "name", "type", "desc", "derive"]`），并在分析前遍历每个资产的 `derive` 数组，建立「已存在衍生状态名称集合」；在识别新衍生资产时，须将候选衍生状态名称与该集合比对，禁止创建名称或描述与已存在衍生资产高度相似（相似度 > 80%）的新衍生资产。

2. WHEN ProductionAgent 执行层识别出候选衍生资产时，THE ProductionAgent 执行层 SHALL 按以下规则判断是否需要新建：①若 `derive` 数组中已存在完全相同的状态名称 → 跳过，不调用 `add_deriveAsset`；②若 `derive` 数组中存在描述高度相似的状态 → 在说明中注明「已存在近似衍生：{已有衍生名称}」，询问用户是否需要新建；③若确实是新状态 → 调用 `add_deriveAsset` 写入；当前执行层只规定「已存在于 derive 数组中的状态不重复」，但缺少具体的比对逻辑。

3. WHEN ProductionAgent 执行层在多集剧本的不同集次执行衍生资产分析时，THE ProductionAgent 执行层 SHALL 每次分析前重新读取最新的 `assets.derive` 数组（不使用缓存），确保跨集次的衍生资产去重基于最新数据；禁止基于上一次分析时读取的 `derive` 数组进行去重判断。

4. WHEN 用户在阶段1确认衍生资产清单后选择「调整清单」时，THE ProductionAgent 决策层 SHALL 将用户的调整意见（删除某条/修改某条描述）传递给执行层，执行层须在调用 `add_deriveAsset` 前应用这些调整；当前决策层的「调整清单」分支只说明「将调整后清单传递给阶段2」，但阶段2是图片生成而非信息写入，THE System SHALL 明确「调整清单」分支应重新派发阶段1执行层（而非直接进入阶段2）。

---

### 需求 32：导演规划「执行计划」章节缺失与监督层审核不匹配

**用户故事：** 作为短剧创作者，我希望导演规划的输出格式与监督层的审核维度完全对应，不出现执行层输出了某个章节但监督层不审核的情况。

#### 验收标准

1. WHEN ProductionAgent 执行层生成导演规划时，THE ProductionAgent 执行层 SHALL 按「创作规划（①~⑥）」顺序输出六个维度；当前监督层的「创作规划完整性」审核只检查「五个维度（①~⑤）」，缺少对「⑥转场与视觉连续性」维度的完整性检查——THE ProductionAgent 监督层 SHALL 将审核维度从「五个维度」更新为「六个维度（①~⑥）」，并在「创作规划完整性」审核项中增加⑥的必填项检查（场间转场策略、段落间过渡手法、视觉连续性锚点）。

2. WHEN ProductionAgent 监督层审核导演规划的「总字数控制」时，THE ProductionAgent 监督层 SHALL 使用「总字数不超过 1200 词」作为审核标准（与执行层输出要求一致）；当前监督层审核标准为「总字数不超过 1000 词」，与执行层规定的「1200 词」不一致，THE System SHALL 统一为 1200 词。

3. WHEN ProductionAgent 执行层生成导演规划时，THE ProductionAgent 执行层 SHALL 在「创作规划」之后输出「执行计划」（步骤列表，含依赖关系）；当前执行层的「输出要求」章节只提到「按创作规划（①~⑥）顺序输出」，没有明确要求输出「执行计划」章节，但监督层的审核维度包含「依赖关系正确」审核项——THE System SHALL 在执行层输出要求中明确补充「执行计划」章节的格式规范。

4. WHEN ProductionAgent 监督层审核「风格一致性」时，THE ProductionAgent 监督层 SHALL 加载当前项目配置的画风技能包 `director_planning_style.md` 和故事风格技能包 `director_planning_narrative.md` 作为审核基准；当前监督层只说明「加载 director_planning.md 风格技法参考」，文件名不明确（实际文件名为 `director_planning_style.md` 和 `director_planning_narrative.md`），THE System SHALL 在监督层技能文件中明确这两个文件的加载路径。

---

### 需求 33：记忆分层与最小上下文检索

**用户故事：** 作为平台运营者，我希望自动化记忆真正降低 token 消耗，而不是把更多历史上下文再次塞给模型；同时记忆必须能精准命中当前任务范围，避免跨项目、跨集、跨角色污染。

#### 验收标准

1. THE System SHALL 将自动化记忆拆分为至少 3 层：`StyleBible`（项目长期稳定约束）、`StageSummary`（阶段结果摘要）、`DeltaMemory`（局部连续性补丁）；禁止将所有历史信息混写为单一长摘要。

2. WHEN ScriptAgent 或 ProductionAgent 检索记忆时，THE Agent SHALL 先检索与当前任务直接匹配的最小层级：风格/设定问题优先查 `StyleBible`，阶段承接问题优先查 `StageSummary`，相邻场景连续性问题优先查 `DeltaMemory`；禁止默认同时读取全部层级。

3. WHEN System 写入 `StyleBible` 时，THE System SHALL 仅收录高稳定、跨阶段复用的信息，如角色核心性格、固定外观锚点、人物关系、画风禁忌、故事风格禁忌；禁止将一次性场景动作、临时台词、单镜头情绪波动写入 `StyleBible`。

4. WHEN System 写入 `DeltaMemory` 时，THE System SHALL 仅记录「发生了变化」的信息，包含变化前状态、变化后状态、作用范围和失效条件；禁止重复写入与前一版本完全相同的状态描述。

5. WHEN Agent 检索记忆时，THE Agent SHALL 先按 `user_id + project_id + episode_id + stage + agent_type + scope signature` 过滤，再按相关度排序；禁止仅按 `project_id` 粗粒度召回全部历史记忆。

6. WHEN 当前任务仅涉及局部返工（如单集、单场、单条分镜）时，THE Agent SHALL 只读取该范围相关的 `StageSummary` 与 `DeltaMemory`，禁止为局部返工加载全剧项目历史。

7. WHEN 记忆检索命中条目超过 3 条时，THE System SHALL 在返回模型前先进行规则化压缩，输出不超过 220 字的结构化检索结果（固定字段：`must_keep`、`must_avoid`、`latest_change`、`scope`）；禁止将原始多条记忆全文直接拼接进模型上下文。

8. IF 当前任务所需信息已完整存在于工作区结构化字段（如 `videoDesc`、`associateAssetsIds`、`duration`、项目配置）中，THEN THE Agent SHALL 优先读取结构化字段而非记忆；记忆仅用于补充结构化字段中不存在的高价值上下文。

---

### 需求 34：角色表演真实感与反 AI 穿帮约束

**用户故事：** 作为短剧创作者，我希望生成的人物不是“念稿机器”，而是真像演员在表演，既有可识别的个人风格，也有随着剧情变化的情绪、呼吸、停顿和动作逻辑，并尽量避免常见 AI 穿帮。

#### 验收标准

1. WHEN ScriptAgent 编写剧本或 ProductionAgent 构建分镜表时，THE Agent SHALL 为主要角色维护「表演锚点卡」，至少包含：默认气质、情绪表达方式、肢体习惯、小动作习惯、说话节奏禁忌；同一角色后续场景须沿用该卡片，禁止每场都像新角色。

2. WHEN ScriptAgent 编写台词时，THE ScriptAgent SHALL 使主要角色具备可区分的话语风格，至少在措辞、句长、礼貌度、攻击性或隐喻习惯中形成 2 项以上稳定差异；禁止多角色台词高度同质化。

3. WHEN ProductionAgent 生成含台词分镜的 `videoDesc` 或提示词时，THE ProductionAgent SHALL 在情绪描述外补充至少 1 项表演细节，如呼吸变化、停顿位置、眼神落点、下意识动作、嘴角/眉眼微表情；禁止只写抽象情绪标签而无表演指令。

4. WHEN ProductionAgent 处理强情绪镜头时，THE ProductionAgent SHALL 确保情绪通过「动作 + 微表情 + 发声状态」三者共同体现；禁止仅靠台词内容表达情绪。

5. WHEN ProductionAgent 构建分镜表时，THE ProductionAgent SHALL 对每条人物镜头执行「反穿帮检查」，至少检查以下 8 项：手部数量与姿态合理、肢体朝向连续、视线落点合理、口型与台词状态一致、服饰配件连续、伤势/污渍连续、主光源方向连续、背景群众/环境动态不过度随机；任一项明显异常须标记为待修正。

6. WHEN 视频提示词生成 Agent 处理多人对话镜头时，THE 视频提示词生成 Agent SHALL 明确当前主说话者、旁听者反应和镜头关注主体，禁止多人同时高强度表演导致视觉重心混乱。

7. WHEN ProductionAgent 处理无台词镜头时，THE ProductionAgent SHALL 使用「内在意图 + 外在动作」方式描述角色状态，如“强压怒气地整理袖口，目光避开对方”，禁止输出仅有氛围而没有人物内在驱动力的空表演镜头。

8. WHEN 监督层审核人物表现时，THE 监督层 SHALL 增加「角色辨识度与表演真实感」维度，标注台词同质化、情绪只停留在字面、角色像朗读文本、或出现典型 AI 穿帮的镜头与场景。

---

### 需求 35：质量优先的局部返工与分级模型策略

**用户故事：** 作为平台运营者，我希望系统在保证质量的前提下，用最少的 token 完成修正工作，避免因为一处问题而整集、整阶段重跑；同时把高成本模型只用在真正必要的难点上。

#### 验收标准

1. THE System SHALL 支持 `PatchRegeneration` 能力，返工粒度至少覆盖：单集故事骨架、单集剧本、单场、单条分镜、单条视频提示词、单个衍生资产；禁止默认整阶段全量重生成。

2. WHEN 监督层或用户指出问题时，THE 决策层 SHALL 先生成「最小修复范围」判断，明确问题属于全局问题、集级问题、场级问题还是镜头级问题；只有判定为全局约束错误时才允许升级为整阶段重跑。

3. WHEN 问题仅影响局部连续性或单条提示词质量时，THE 决策层 SHALL 仅重派受影响的最小对象 ID 列表（如 `storyboardIds`、`assetIds`、`sceneIds`），禁止因单条失败而重新读取整表或整剧本。

4. WHEN System 选择模型时，THE System SHALL 采用分级策略：结构化提取、格式修复、范围压缩等低创造性任务优先使用低成本模型；剧情改写、情绪强化、关键镜头提示词、高风险修复等高创造性任务使用高质量模型；禁止所有任务一律使用最高成本模型。

5. IF 低成本模型的输出未通过监督层或规则校验，THEN THE System SHALL 仅对失败对象升级到更高质量模型重试；禁止把已通过对象与失败对象一起升级重跑。

6. WHEN 进入高质量模型重试时，THE 决策层 SHALL 在派发指令中仅附带失败原因、目标修复项、必要最小上下文和相关记忆摘要，禁止重复附带整段历史产物。

7. WHEN 同一对象连续 2 次局部返工仍未达标时，THE System SHALL 升级为「问题归因模式」，先输出失败原因分类（设定冲突、情绪不足、动作不合理、提示词不够具体、风格约束缺失等），再决定是否扩大返工范围；禁止无归因地持续重试。

8. THE System SHALL 记录每次局部返工的 token 成本、修复范围、是否通过和最终采用模型，供后续按问题类型优化默认策略，优先减少无效重试。

---

### 需求 36：生成前质量资产沉淀与流程补完

**用户故事：** 作为短剧创作者，我希望在真正开始大量生成之前，系统先沉淀少量高价值的“质量基座”信息，让后续各阶段更稳、更省 token，也减少反复返工。

#### 验收标准

1. WHEN 项目初始化完成后且正式进入故事骨架前，THE System SHALL 生成并持久化项目级 `StyleBible`，至少包含：主角卡、核心人物关系、视觉禁忌、叙事禁忌、世界观硬约束、目标平台节奏约束；后续所有 Agent 阶段优先引用该 `StyleBible`，禁止每阶段重新从自然语言长描述中猜测这些规则。

2. WHEN ScriptAgent 完成故事骨架后，THE System SHALL 自动沉淀「分集情绪曲线表」和「集末钩子计划表」两个结构化产物，供剧本编写和监督层直接引用；禁止后续阶段再次从长文本骨架中重复提取同类信息。

3. WHEN 资产提取阶段完成后，THE System SHALL 为主要角色自动生成「角色一致性卡」，至少包含固定外观锚点、禁改项、可变项、常用情绪表现、常用动作习惯；ProductionAgent 与视频提示词生成 Agent 后续须优先读取该卡片，而非反复扫描整本剧本。

4. WHEN ProductionAgent 完成导演规划后，THE System SHALL 自动沉淀「镜头语言基线」，至少包含本项目优先景别、默认运镜强度、转场禁忌、空镜使用原则、情绪高潮镜头策略；后续分镜表构建和监督层审核须共用这份基线。

5. WHEN 监督层首次发现某项目存在重复性问题（同类问题在同一项目出现至少 3 次）时，THE System SHALL 将其提升为项目级临时禁忌，写入该项目的 `DeltaMemory` 或 `StyleBible` 补丁，例如“该主角哭戏容易木，需要明确呼吸与停顿”“该画风下避免复杂手部特写”；禁止同类 bad case 在同一项目中反复被指出但没有沉淀。

6. WHEN 项目结束或用户显式归档项目时，THE System SHALL 将项目级记忆封存为只读，并禁止其自动参与其他项目的记忆召回；若用户创建新项目，即使为同一用户，也不得默认复用旧项目的 `StyleBible`，除非用户明确选择“复制某项目设定”。

7. WHEN 用户选择“复制某项目设定”创建新项目时，THE System SHALL 仅复制用户确认的高稳定层内容（`StyleBible`、角色一致性卡、画风/故事风格配置），禁止复制阶段摘要、局部返工记录、失败样例、临时连续性补丁等易污染信息。

8. THE System SHALL 为每个项目提供「记忆成本概览」，至少展示 `StyleBible` 条目数、阶段摘要条目数、局部补丁条目数和近 30 次任务的平均记忆注入字数，供平台判断该项目的记忆是否已经过度膨胀并需要压缩整理。

---

### 需求 37：工程实现约束与可维护性护栏

**用户故事：** 作为平台开发者，我希望在持续优化短剧质量和降低 token 消耗时，不会因为追求功能速度而牺牲代码可维护性，避免把核心模块继续堆成超大文件或平铺结构，导致后续优化越来越贵。

#### 验收标准

1. IF 为实现新功能或优化现有功能需要修改 `backend/` 或 `frontend/` 代码，THEN THE System SHALL 以“直接修改当前实现”为默认策略，禁止为了尚未上线项目的向后兼容而保留旧实现与新实现并存的双轨逻辑，除非该双轨逻辑是同一轮开发中短期过渡且有明确移除计划。

2. WHEN 任一 `backend/` 或 `frontend/` 源文件在修改后预计超过 800 行时，THE System SHALL 在提交前按职责拆分该文件，禁止继续把新逻辑直接堆进原文件。

3. WHEN 拆分超过 800 行的大文件时，THE System SHALL 建立与职责对应的目录结构后再拆分，例如按 `query/`、`persist/`、`selection/`、`optimization/`、`widgets/`、`sections/`、`actions/` 等分组；禁止把拆出的多个文件直接平铺在原目录下形成新的“文件堆”。

4. WHEN 后端模块被拆分为目录时，THE System SHALL 保留唯一明确的入口文件（如 `mod.rs` 或同级聚合入口），入口文件只负责导出与装配，不得继续承载大段业务逻辑。

5. WHEN 前端工作台或对话框视图被拆分时，THE System SHALL 将视图骨架、状态模型、交互回调、分区组件和纯展示 helper 分离到不同文件或子目录中；禁止在单一 UI 文件中同时长期堆放布局、状态转换、格式化工具和网络交互逻辑。

6. WHEN 新增专项优化能力（如记忆压缩、局部返工、质量诊断）时，THE System SHALL 优先复用现有分层目录模式（如 `meta/generate/` 的分块结构），禁止在历史超大文件中继续横向追加同类逻辑。

7. WHEN 某模块已经出现明显的“过渡态拆分”迹象（已有若干子文件，但主文件仍显著超阈值）时，THE System SHALL 在后续同域需求中优先继续完成该模块的目录化收敛，而不是无限期维持“超大主文件 + 少量附属文件”的状态。

8. WHEN 增加新的工程规则或结构约束时，THE System SHALL 同步把这些约束补入对应需求文档或开发规范，确保后续 Agent 和人工开发遵循相同规则，禁止规则只停留在口头约定。

---

### 需求 38：视频提示词记忆模块的架构收敛

**用户故事：** 作为平台开发者，我希望视频提示词记忆系统在持续增强后仍保持清晰边界，避免 `selected memory`、`auto scope`、`rejected negative`、`style refresh`、`observation`、`optimization` 等逻辑长期混杂在单一超大模块里，影响后续质量优化效率。

#### 验收标准

1. THE System SHALL 将视频提示词记忆能力按职责至少拆分为以下模块域：记忆构建（build）、记忆持久化（persist/clear）、记忆查询选择（select/query）、记忆压缩优化（optimize/compact）、派生摘要刷新（refresh/summary）、坏例反馈（rejected/observation）；禁止将这些域长期混写在单一超大实现文件中。

2. WHEN 视频提示词生成链路读取 `app_agent_memory` 时，THE System SHALL 只查询当前阶段白名单内的记忆名称，并限制最大返回行数；禁止为了图省事而对当前项目的全部 `summary` 记忆做无差别扫描。

3. WHEN 新增一种视频记忆类型时，THE System SHALL 在同一轮实现中明确补齐其生命周期：写入规则、查询白名单、压缩策略、清理策略、作用范围、以及对应测试；禁止只加写入不加读取/清理，或只加读取不加作用域限制。

4. WHEN 系统维护脚本级或项目级派生风格记忆时，THE System SHALL 优先从已确认的高价值记忆中刷新派生摘要，并在提示词生成阶段优先读取派生摘要；禁止每次生成提示词都回扫大量原始明细记忆重新聚合。

5. WHEN 自动范围记忆（如按 `storyboardIds` 写入的局部连续性记忆）被引入时，THE System SHALL 保证其仅服务于对应分镜或紧邻分镜的提示词生成，且可被独立清理；禁止局部范围记忆无边界地漂移为项目全局风格记忆。

6. WHEN 视频记忆优化执行去重、压缩或淘汰时，THE System SHALL 优先保留对人物一致性、情绪传达、光影连续性和口型/表演风险最有帮助的锚点信息；禁止为了进一步压缩 token 而优先删除这些高价值记忆。

7. WHEN 同域逻辑需要新增测试时，THE System SHALL 采用与实现目录相对应的测试组织方式，优先按职责分组测试（如 selection、optimization、auto_scope、rejected），禁止把大部分新增测试继续堆入单一超大测试文件。

8. WHEN 视频提示词记忆模块完成目录化拆分后，THE System SHALL 确保入口导出命名保持清晰、语义稳定，避免上层调用方必须了解底层文件布局细节才能使用相关能力。
