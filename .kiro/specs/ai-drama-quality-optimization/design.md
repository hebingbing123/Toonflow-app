# 设计文档：AI 短剧生成质量优化

## 概述

本功能在 OpenFlow平台上，通过优化 Agent 技能文件、提示词工程、记忆系统和生成流水线，使生成的短剧视频达到"不穿帮"的质量标准。核心目标是：人物有风格与情绪、画面真实自然、叙事节奏有起伏，同时在保证质量的前提下尽量减少大模型 token 消耗。

平台技术栈：Rust 后端（Axum + SQLx + Tokio）+ Flutter 前端，Agent 编排通过 Harness WebSocket 协议运行，技能文件为 Markdown 格式存储于 `backend/data/skills/`，提示词模板存储于 `backend/data/prompt_defaults/`。


## 架构

本功能横跨多个现有模块，不引入全新的顶层服务，而是在现有分层架构上做精准增强。

```mermaid
graph TD
    subgraph "Agent 编排层（Harness WS）"
        SA[ScriptAgent<br/>决策/执行/监督]
        PA[ProductionAgent<br/>决策/执行/监督]
        VPA[视频提示词生成 Agent]
        EEA[事件提取 Agent]
        AEA[资产提取 Agent]
    end

    subgraph "技能文件层（backend/data/skills/）"
        CORE[核心技能文件<br/>script_agent_*.md<br/>production_agent_*.md]
        ART[画风技能包<br/>art_skills/{style}/]
        STORY[故事风格技能包<br/>story_skills/{genre}/]
    end

    subgraph "后端服务层（Rust/Axum）"
        MEM[记忆模块<br/>settings/agent_memory<br/>+ 新增分层记忆]
        QR[质量评审模块<br/>prompting/quality]
        SKILL[技能文件 API<br/>prompting/skills]
        VER[版本管理<br/>新增 app_skill_versions]
        PROJ[项目配置<br/>projects/]
    end

    subgraph "数据层（PostgreSQL）"
        AMT[app_agent_memory<br/>+ memory_tier 字段]
        AQR[app_quality_review<br/>+ stage/grade 字段]
        ASV[app_skill_versions<br/>新增表]
        PROJ_T[projects 表<br/>+ art_style/story_style 字段]
    end

    SA --> CORE
    PA --> CORE
    SA --> STORY
    PA --> ART
    VPA --> ART
    AEA --> ART

    SA --> MEM
    PA --> MEM
    MEM --> AMT

    SA --> QR
    PA --> QR
    QR --> AQR

    SKILL --> VER
    VER --> ASV

    PROJ --> PROJ_T
```

### 关键设计决策

1. **技能文件优先，代码兜底**：风格约束优先从技能包 Markdown 文件加载，文件缺失时降级到代码内置默认值并记录警告日志，不中断流程。
2. **记忆分层而非单一长摘要**：引入 `StyleBible`、`StageSummary`、`DeltaMemory` 三层，通过 `memory_tier` 字段区分，避免全量历史上下文注入。
3. **局部返工优先于全量重跑**：`PatchRegeneration` 能力以最小对象 ID 列表为粒度，只有全局约束错误才升级为整阶段重跑。
4. **版本管理通过文件哈希追踪**：技能文件和提示词模板变更时自动记录 SHA256 哈希到 `app_skill_versions` 表，支持质量回归对比。


## 组件与接口

### 1. 技能文件规范化（Skill File Normalization）

**涉及文件**：`backend/data/skills/` 下所有核心技能文件

**变更内容**：

| 文件 | 变更类型 | 核心变更 |
|------|----------|----------|
| `script_execution_script.md` | 修改 | 修正步骤编号重复（1→2→3→4→5），补充「出场角色表」和「场景表」格式规范，修正旁白格式（OS/V.O.），增加自查清单项 |
| `script_execution_skeleton.md` | 修改 | 增加「角色弧推进」标注，增加「钩子类型多样性」自查项，增加「付费卡点落地」检查项 |
| `script_execution_adaptation.md` | 修改 | 明确声明竖屏短视频平台约束（20字台词、30秒冲突、集末钩子） |
| `production_agent_execution.md` | 修改 | 增加 videoDesc 12 维度规范，增加跨批次连续性记录，增加反穿帮检查 8 项 |
| `production_agent_decision.md` | 修改 | 派发指令模板增加「画风技能包路径」和「故事风格技能包路径」字段，增加 deepRetrieve 无结果时的六阶段选择提示 |
| `production_agent_supervision.md` | 修改 | 增加「视觉连续性」「情绪渐进」「台词-时长匹配」「定场镜头数量」「转场策略」「环境动态密度」审核维度，统一字数上限为 1200 词 |
| `script_agent_decision.md` | 修改 | 增加执行层确认消息展示规则，增加禁止自动重试约束 |
| `script_agent_supervision.md` | 修改 | 增加「情绪具象化」「钩子类型多样性」「短剧平台适配」审核维度 |

**画风技能包必需文件结构**（每个 `art_skills/{style}/` 目录）：
```
{style}/
├── prefix.md                          # 全局约束规则（必守规则 R1-R5 + 严禁项 X1-X5）
├── README.md
├── driector_skills/
│   ├── director_planning_style.md     # 导演规划风格基准
│   ├── director_storyboard_table_style.md  # 分镜表光影规范
│   └── director_storyboard.md         # 分镜面板提示词技法
└── art_prompt/
    ├── art_character.md               # 角色基础形象（含四视图规范）
    ├── art_character_derivative.md    # 角色衍生服化（含 L1 妆容决策）
    ├── art_scene.md                   # 场景基础
    ├── art_scene_derivative.md        # 场景衍生状态
    ├── art_prop.md                    # 道具基础
    ├── art_prop_derivative.md         # 道具衍生状态
    └── art_storyboard_video.md        # 视频提示词风格标签（三模式）
```

**故事风格技能包必需文件结构**（每个 `story_skills/{genre}/` 目录）：
```
{genre}/
├── README.md
└── driector_skills/
    ├── director_planning_narrative.md          # 主题立意、叙事结构、情绪设计、声音方向
    └── director_storyboard_table_narrative.md  # 景别选择、运镜节奏、时长把控、转场设计
```

### 2. 记忆分层系统（Tiered Memory System）

**涉及模块**：`backend/src/settings/agent_memory/`

**新增 `memory_tier` 字段**到 `app_agent_memory` 表，取值：`style_bible` | `stage_summary` | `delta_memory` | `message`（兼容旧值）。

**三层记忆语义**：

| 层级 | `memory_tier` 值 | 内容 | 稳定性 | 最大字数 |
|------|-----------------|------|--------|---------|
| StyleBible | `style_bible` | 角色核心性格、固定外观锚点、人物关系、画风禁忌、故事风格禁忌 | 高（项目级） | 800 |
| StageSummary | `stage_summary` | 阶段结果摘要（阶段名称、完成状态、关键决策点） | 中（阶段级） | 320 |
| DeltaMemory | `delta_memory` | 局部连续性补丁（变化前/后状态、作用范围、失效条件） | 低（场景/镜头级） | 200 |

**检索压缩规则**：命中条目 > 3 条时，压缩为不超过 220 字的结构化结果，固定字段：`must_keep`、`must_avoid`、`latest_change`、`scope`。

**新增 API 端点**：
- `POST /api/v1/agents/memory/append`：增加 `memoryTier` 字段（可选，默认 `message`）
- `POST /api/v1/agents/memory/query`：增加 `memoryTier` 过滤字段
- `GET /api/v1/agents/memory/cost-overview`：返回项目记忆成本概览（StyleBible 条目数、StageSummary 条目数、DeltaMemory 条目数、近 30 次任务平均记忆注入字数）

### 3. 技能文件版本管理（Skill Version Tracking）

**涉及模块**：`backend/src/prompting/skills/`，新增 `backend/src/prompting/skill_versions/`

**新增表** `app_skill_versions`：
```sql
CREATE TABLE app_skill_versions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path   TEXT NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    summary     TEXT,                    -- 变更摘要，不超过 100 字
    hash_before TEXT,                    -- SHA256 of previous content
    hash_after  TEXT NOT NULL,           -- SHA256 of new content
    changed_by  UUID REFERENCES auth.users(id)
);
CREATE INDEX ON app_skill_versions (file_path, changed_at DESC);
```

**新增 API 端点**：
- `GET /api/v1/skill-versions?path=` — 查询某文件的版本历史
- `POST /api/v1/skill-versions/rollback` — 回滚到指定版本（记录操作日志）

**触发时机**：`PUT /api/v1/skills/content` 和 `POST /api/v1/skills/content` 写入成功后，自动计算 SHA256 并插入 `app_skill_versions`。

### 4. 质量评审增强（Quality Review Enhancement）

**涉及模块**：`backend/src/prompting/quality/`

**现有 `app_quality_review` 表新增字段**：
- `stage TEXT` — 阶段名称（`story_skeleton` | `adaptation_strategy` | `director_planning` | `storyboard_table` | `storyboard_panel` | `video_prompt`）
- `grade TEXT` — 评分等级（`A` | `B` | `C` | `D`）
- `skill_file_path TEXT` — 对应技能文件路径
- `skill_version_hash TEXT` — 对应技能文件版本哈希

**现有 API 增强**：
- `GET /api/v1/quality/stage-pass-rate` — 已存在，确认返回各阶段 A/B/C/D 分布和通过率（A+B 占比）

### 5. 项目配置增强（Project Config Enhancement）

**涉及模块**：`backend/src/projects/`

**`projects` 表新增字段**：
- `art_style_pack TEXT` — 画风技能包路径（如 `art_skills/realpeople_ancient_chinese`）
- `story_style_pack TEXT` — 故事风格技能包路径（如 `story_skills/Sweet_romance_novel`）

**新增 API 端点**：
- `PATCH /api/v1/projects/{id}/style-config` — 更新项目风格配置

### 6. 局部返工能力（Patch Regeneration）

**涉及模块**：`backend/src/production/`，新增 `backend/src/production/patch/`

**返工粒度**：
- `episode` — 单集故事骨架或剧本
- `scene` — 单场
- `storyboard_item` — 单条分镜
- `video_prompt` — 单条视频提示词
- `derive_asset` — 单个衍生资产

**新增 API 端点**：
- `POST /api/v1/production/patch` — 接受 `{ scope: string, ids: number[], reason: string, model_tier: "low" | "high" }`

**分级模型策略**：
- `low`：结构化提取、格式修复、范围压缩
- `high`：剧情改写、情绪强化、关键镜头提示词


## 数据模型

### app_agent_memory（现有表，新增字段）

```sql
ALTER TABLE app_agent_memory
    ADD COLUMN memory_tier TEXT NOT NULL DEFAULT 'message'
        CHECK (memory_tier IN ('style_bible', 'stage_summary', 'delta_memory', 'message')),
    ADD COLUMN scope_signature JSONB;
-- scope_signature 示例：
-- {"storyboardIds": [1,2,3], "assetIds": [10], "focusSections": ["ep3_scene2"], "episodeId": 3}
```

### app_skill_versions（新增表）

```sql
CREATE TABLE app_skill_versions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path   TEXT NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    summary     TEXT CHECK (char_length(summary) <= 100),
    hash_before TEXT,
    hash_after  TEXT NOT NULL,
    changed_by  UUID REFERENCES auth.users(id),
    rollback_of UUID REFERENCES app_skill_versions(id)
);
CREATE INDEX ON app_skill_versions (file_path, changed_at DESC);
```

### app_quality_review（现有表，新增字段）

```sql
ALTER TABLE app_quality_review
    ADD COLUMN stage TEXT
        CHECK (stage IN ('story_skeleton','adaptation_strategy','director_planning',
                         'storyboard_table','storyboard_panel','video_prompt')),
    ADD COLUMN grade TEXT CHECK (grade IN ('A','B','C','D')),
    ADD COLUMN skill_file_path TEXT,
    ADD COLUMN skill_version_hash TEXT;
```

### projects（现有表，新增字段）

```sql
ALTER TABLE projects
    ADD COLUMN art_style_pack TEXT,    -- e.g. 'art_skills/realpeople_ancient_chinese'
    ADD COLUMN story_style_pack TEXT;  -- e.g. 'story_skills/Sweet_romance_novel'
```

### StyleBible 结构（存储于 app_agent_memory，memory_tier='style_bible'）

```json
{
  "characters": [
    {
      "name": "角色名",
      "default_temperament": "默认气质",
      "emotion_expression": "情绪表达方式",
      "body_habits": ["肢体习惯1", "肢体习惯2"],
      "speech_rhythm_taboos": ["禁忌1"],
      "fixed_appearance": "固定外观锚点",
      "forbidden_changes": ["禁改项"]
    }
  ],
  "visual_taboos": ["视觉禁忌1"],
  "narrative_taboos": ["叙事禁忌1"],
  "world_constraints": ["世界观硬约束1"],
  "platform_rhythm": "目标平台节奏约束",
  "core_relationships": "核心人物关系描述"
}
```

### DeltaMemory 结构（存储于 app_agent_memory，memory_tier='delta_memory'）

```json
{
  "before": "变化前状态描述",
  "after": "变化后状态描述",
  "scope": "作用范围（如 ep3_scene2_shot5）",
  "expires_after": "失效条件（如 scene_end）"
}
```

### 记忆成本概览响应（GET /api/v1/agents/memory/cost-overview）

```json
{
  "projectId": 1,
  "styleBibleCount": 3,
  "stageSummaryCount": 12,
  "deltaMemoryCount": 45,
  "avgInjectedCharsLast30": 1840
}
```


## 正确性属性

*属性（Property）是在系统所有有效执行中都应成立的特征或行为——本质上是对系统应做什么的形式化陈述。属性是人类可读规范与机器可验证正确性保证之间的桥梁。*

---

### 属性 1：情绪强度渐进性

*对于任意*同一角色的连续分镜序列，不得出现连续 3 条或以上具有完全相同情绪强度标签的分镜。

**验证：需求 1.3、需求 12.2**

---

### 属性 2：情绪曲线层次覆盖

*对于任意*一集剧本，其情绪强度标签集合必须包含至少 3 个不同强度层次（低/中/高），且高强度场景不得出现在前 20% 的场景中。

**验证：需求 1.5、需求 14.3**

---

### 属性 3：画质降级词禁止

*对于任意*生成的分镜提示词字符串，均不得包含画质降级词黑名单中的任何词汇（`film grain`、`imperfect focus`、`柔焦`、`朦胧感` 等）。

**验证：需求 2.2**

---

### 属性 4：景别连续性约束

*对于任意*分镜序列，不得出现连续 3 条或以上使用完全相同景别（shot type）的分镜。

**验证：需求 2.4、需求 11.1**

---

### 属性 5：定场镜头数量约束

*对于任意*场景（scene），其定场镜头（establishing shot）数量不得超过 2 个。

**验证：需求 2.7、需求 12.5**

---

### 属性 6：无台词镜头时长约束

*对于任意*无台词分镜（`dialogue` 字段为空或「无台词」），其 `duration` 不得超过 6 秒（一镜到底镜头上限 12 秒）。

**验证：需求 2.8**

---

### 属性 7：记忆隔离性

*对于任意*两个不同 `user_id` 或不同 `project_id` 的记忆查询，其返回结果集必须完全不相交——即不存在任何记忆条目同时出现在两个查询结果中。

**验证：需求 4.1、需求 4.2**

---

### 属性 8：记忆范围签名完整性

*对于任意*写入 `app_agent_memory` 的 `stage_summary` 类型记忆条目，其 `scope_signature` 字段必须包含至少一个非空的范围维度（`storyboardIds`、`assetIds`、`focusSections` 或 `episodeId` 之一）。

**验证：需求 4.6**

---

### 属性 9：开场冲突约束

*对于任意*一集剧本，其前 3 个场景中必须包含至少一个冲突或悬念建立点标记，不得以纯环境描写或人物介绍开场。

**验证：需求 5.1、需求 14.2**

---

### 属性 10：集末钩子类型多样性

*对于任意*连续 3 集或以上的集末钩子序列，不得全部使用同一类型的钩子（悬念/情感/智识/世界观）。

**验证：需求 5.2、需求 14.6**

---

### 属性 11：台词字数约束

*对于任意*剧本中的单句台词，其字符数不得超过 20 字。

**验证：需求 5.3**

---

### 属性 12：含台词分镜时长下限

*对于任意*含台词的分镜，其 `duration`（秒）必须满足：`duration >= ceil(dialogue_length / speech_rate) + 1`，其中 `speech_rate` 根据情绪状态取值（愤怒 4 字/秒、正常 3 字/秒、悲伤 2 字/秒）。

**验证：需求 5.4、需求 12.3**

---

### 属性 13：监督层审核摘要结构完整性

*对于任意*监督层输出的审核摘要，其 XML `<reviewSummary />` 必须包含 `grade`（A/B/C/D）、`severeCount`、`mediumCount`、`minorCount`、`nextAction` 全部 5 个字段，且 `grade` 值必须是 A/B/C/D 之一；当 `severeCount > 0` 时，`nextAction` 中必须包含至少 2 个可选修复方案。

**验证：需求 6.1、需求 6.2**

---

### 属性 14：质量评审筛选一致性

*对于任意*按 `project_id`、`stage` 或 `grade` 筛选的质量评审查询，返回的所有记录必须满足筛选条件——即不存在不符合筛选条件的记录出现在结果中。

**验证：需求 6.6**

---

### 属性 15：技能文件版本记录完整性

*对于任意*技能文件（`.md`）或提示词模板（`.txt`）的写入操作，操作成功后必须在 `app_skill_versions` 表中存在对应的版本记录，且该记录的 `hash_after` 必须等于写入内容的 SHA256 哈希值。

**验证：需求 6.5、需求 24.1、需求 24.2**

---

### 属性 16：视频提示词台词保留

*对于任意*含台词的分镜，其生成的视频提示词必须包含台词原文（不得翻译或改写），且台词类型标注（`dialogue` / `inner monologue OS` / `voiceover VO`）必须存在。

**验证：需求 7.1**

---

### 属性 17：Seedance 2.0 音色维度完整性

*对于任意* Seedance 2.0 模式下含台词的分镜提示词，必须包含 9 个音色维度描述（性别、年龄音色、音调、音色质感、声音厚度、发音方式、气息、语速、特殊质感），且语速/气息/音调参数必须与角色情绪状态一致（愤怒→语速偏快/气息急促/音调偏高；悲伤→语速偏慢/气息绵长/音调偏低）。

**验证：需求 7.2、需求 16.1**

---

### 属性 18：多参模式资产编号顺序性

*对于任意*多参模式的视频提示词批次，资产编号必须从 `@图1` 开始连续递增，同一角色在所有分镜中必须使用相同的 `@图N` 编号，`shouldGenerateImage="false"` 的分镜不分配编号。

**验证：需求 7.3、需求 16.4**

---

### 属性 19：事件提取格式合规性

*对于任意*章节原文输入，事件提取 Agent 的每条输出行必须严格符合管道分隔格式（以 `|` 开头、以 `|` 结尾、恰好 7 个字段），且集长字段必须以「X秒」格式输出（不得使用分钟单位）。

**验证：需求 10.1、需求 10.3**

---

### 属性 20：记忆分层合规性

*对于任意*写入 `app_agent_memory` 的记忆条目，其 `memory_tier` 字段必须是 `style_bible`、`stage_summary`、`delta_memory`、`message` 之一；`style_bible` 层不得包含一次性场景动作、临时台词或单镜头情绪波动；`delta_memory` 层必须包含 `before`、`after`、`scope`、`expires_after` 四个字段。

**验证：需求 33.1、需求 33.3、需求 33.4**

---

### 属性 21：记忆检索压缩约束

*对于任意*返回超过 3 条命中条目的记忆检索，系统必须在注入模型上下文前将其压缩为不超过 220 字的结构化结果，且压缩结果必须包含 `must_keep`、`must_avoid`、`latest_change`、`scope` 四个字段。

**验证：需求 33.7**

---

### 属性 22：分镜面板 track 跨场景换组

*对于任意*相邻两条 `scene` 字段不同的分镜，它们必须属于不同的 `track` 分组；同一 `track` 内所有分镜的累计 `duration` 不得超过 15 秒。

**验证：需求 25.2、需求 25.3**

---

### 属性 23：衍生资产去重

*对于任意*候选衍生资产，若其名称或描述与已存在的衍生资产相似度超过 80%，则不得调用 `add_deriveAsset` 创建新条目。

**验证：需求 31.1、需求 31.2**


## 错误处理

### 技能文件加载失败

| 场景 | 处理策略 |
|------|----------|
| 画风技能包必需文件缺失 | 记录 `WARN` 日志，降级使用通用规范，在工作台向用户显示「画风包 {名称} 的 {文件名} 未配置，已使用通用规范」 |
| 故事风格技能包导演技能文件缺失 | 记录 `WARN` 日志，向用户提示「当前风格包（{名称}）的导演技能文件尚未配置，将使用通用叙事规范」，不静默降级 |
| 技能文件路径包含 `..` 段 | 返回 `400 Bad Request`，拒绝访问 |
| 技能文件超过 2MB | 返回 `413 Payload Too Large` |

### 记忆系统错误

| 场景 | 处理策略 |
|------|----------|
| 记忆检索无结果 | Agent 向用户明确说明「无法确认当前进度，请告知当前所处阶段」，并列出流水线六个阶段供用户选择 |
| 跨用户/跨项目记忆访问尝试 | 返回 `403 Forbidden`，记录安全审计日志 |
| StyleBible 写入超过 800 字 | 返回 `400 Bad Request`，提示「StyleBible 内容超过上限，请精简后重试」 |
| 记忆压缩失败 | 降级返回原始条目（最多 3 条），记录 `ERROR` 日志 |

### 质量评审错误

| 场景 | 处理策略 |
|------|----------|
| `grade` 字段值不在 A/B/C/D 范围内 | 返回 `422 Unprocessable Entity` |
| 技能文件版本哈希不匹配 | 记录警告，允许写入但标记 `skill_version_mismatch=true` |

### 决策层重试上限

| 场景 | 处理策略 |
|------|----------|
| ProductionAgent 执行层连续失败 2 次 | 第 3 次失败时向用户汇报具体失败原因并终止当前阶段，不再重试 |
| ScriptAgent 执行层失败 | 禁止自动重试，必须等待用户明确指示后才能重新派发 |
| 同一对象连续 2 次局部返工未达标 | 升级为「问题归因模式」，输出失败原因分类后再决定是否扩大返工范围 |

### 版本回滚错误

| 场景 | 处理策略 |
|------|----------|
| 目标版本不存在 | 返回 `404 Not Found` |
| 回滚目标文件当前不存在 | 返回 `409 Conflict`，提示需要先创建文件 |
| 回滚操作本身失败 | 事务回滚，返回 `500 Internal Server Error`，不写入操作日志 |

---

## 测试策略

### 双轨测试方法

本功能采用单元测试与属性测试互补的双轨策略：

- **单元测试**：验证具体示例、边界情况、错误条件和 API 契约
- **属性测试**：验证跨所有输入的普遍属性，使用随机生成的输入覆盖大量场景

两者缺一不可：单元测试捕获具体 bug，属性测试验证通用正确性。

### 属性测试配置

使用 Rust 的 `proptest` 库（后端）进行属性测试，每个属性测试最少运行 100 次迭代。

每个属性测试必须包含注释标签，格式：
```
// Feature: ai-drama-quality-optimization, Property {N}: {property_text}
```

### 属性测试实现计划

| 属性 | 测试模块 | 生成器策略 |
|------|----------|-----------|
| 属性 1（情绪强度渐进性） | `production/storyboard/tests` | 生成随机情绪强度序列，检查无连续 3 个相同值 |
| 属性 2（情绪曲线层次覆盖） | `scripting/scripts/tests` | 生成随机场景列表，检查强度层次 >= 3 且高潮不在前 20% |
| 属性 3（画质降级词禁止） | `production/flow_data/tests` | 生成随机提示词字符串，检查黑名单词汇不存在 |
| 属性 4（景别连续性约束） | `production/storyboard/tests` | 生成随机景别序列，检查无连续 3 个相同景别 |
| 属性 5（定场镜头数量约束） | `production/storyboard/tests` | 生成随机场景分镜列表，检查定场镜头 <= 2 |
| 属性 6（无台词镜头时长约束） | `production/storyboard/tests` | 生成随机无台词分镜，检查 duration <= 6 |
| 属性 7（记忆隔离性） | `settings/agent_memory/tests` | 生成两组不同 user_id/project_id 的记忆，检查结果集不相交 |
| 属性 8（记忆范围签名完整性） | `settings/agent_memory/tests` | 生成随机 stage_summary 记忆，检查 scope_signature 非空 |
| 属性 9（开场冲突约束） | `scripting/scripts/tests` | 生成随机剧本场景列表，检查前 3 场有冲突标记 |
| 属性 10（集末钩子类型多样性） | `scripting/scripts/tests` | 生成随机钩子类型序列，检查无连续 3 个相同类型 |
| 属性 11（台词字数约束） | `scripting/scripts/tests` | 生成随机台词字符串，检查字符数 <= 20 |
| 属性 12（含台词分镜时长下限） | `production/storyboard/tests` | 生成随机含台词分镜，检查 duration >= ceil(len/rate)+1 |
| 属性 13（监督层审核摘要结构完整性） | `harness/supervision/tests` | 生成随机审核输出，解析 XML 检查必填字段 |
| 属性 14（质量评审筛选一致性） | `prompting/quality/tests` | 生成随机评审记录集，检查筛选结果全部满足条件 |
| 属性 15（技能文件版本记录完整性） | `prompting/skills/tests` | 写入随机内容，检查版本记录 hash_after 匹配 |
| 属性 16（视频提示词台词保留） | `production/flow_data/tests` | 生成随机台词，检查提示词包含原文 |
| 属性 17（Seedance 2.0 音色维度完整性） | `production/flow_data/tests` | 生成随机情绪+台词组合，检查 9 维度存在且情绪一致 |
| 属性 18（多参模式资产编号顺序性） | `production/flow_data/tests` | 生成随机资产列表，检查编号从 @图1 连续递增 |
| 属性 19（事件提取格式合规性） | `narrative/events/tests` | 生成随机章节文本，检查输出行格式和集长单位 |
| 属性 20（记忆分层合规性） | `settings/agent_memory/tests` | 生成随机记忆条目，检查 memory_tier 合法且内容约束满足 |
| 属性 21（记忆检索压缩约束） | `settings/agent_memory/tests` | 生成 > 3 条命中记忆，检查压缩结果 <= 220 字且含 4 字段 |
| 属性 22（分镜面板 track 跨场景换组） | `production/workbench/tests` | 生成跨场景分镜序列，检查 track 分组规则 |
| 属性 23（衍生资产去重） | `assets/generate/tests` | 生成相似衍生资产候选，检查高相似度时不创建新条目 |

### 单元测试重点

- **API 契约测试**：`GET /api/v1/quality/stage-pass-rate` 返回结构验证（需求 6.4）
- **记忆写入示例**：阶段完成后自动写入 StageSummary 的完整流程（需求 4.5）
- **质量评审创建示例**：`POST /api/v1/quality/reviews` 写入 `app_quality_review` 表（需求 6.3）
- **版本回滚示例**：`POST /api/v1/skill-versions/rollback` 恢复文件内容并记录操作日志（需求 24.4）
- **默认模型选择示例**：未指定模型时视频提示词生成使用模式 A（需求 7.6）
- **边界情况**：空内容章节事件提取返回零条结果（需求 17.5 edge case）
- **边界情况**：非 HTML 内容的解析错误处理（需求 17.2 edge case）
- **边界情况**：特殊字符/非 ASCII 字符在提示词中的正确处理（需求 17.4 edge case）

### 工程可维护性测试

- 所有新增后端模块文件行数不超过 800 行（需求 37.2）
- 新增模块目录结构符合职责分组规范（需求 37.3）

