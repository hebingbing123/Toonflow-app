# 实现计划：AI 短剧生成质量优化

## 概述

本计划将设计文档中的各项增强拆分为可逐步执行的编码任务。

## 任务

- [x] 1. 修正核心技能文件：script_execution_script.md
  - 修正执行流程步骤编号重复（1→2→3→4→5 连续递增）
  - 补充「出场角色表」格式规范（角色名、身份简介≤10字、戏份比重）
  - 补充「场景表」格式规范（场景名、时间、光线、场次编号）
  - 修正旁白格式：`OS（{人物名}，{情绪}）：` 和 `V.O.（{人物名}，{情绪}）：`，移除 `V.S.` 用法
  - 在自查清单中增加「开场冲突」「情绪曲线」「资产一致性」「付费卡点落地」检查项
  - 明确「禁止输出」规则优先级：节拍概要仅输出简短标签
  - _需求: 14.1, 14.2, 14.3, 14.4, 14.8, 19.1, 21.1, 21.2, 21.3, 21.4, 21.5_

- [x] 2. 修正核心技能文件：script_execution_skeleton.md
  - 在分集决策中增加「角色弧推进」逐集标注
  - 在骨架自查清单中增加「钩子类型多样性」检查项
  - 在骨架自查清单中增加「付费卡点落地」检查项
  - 增加「分集情绪曲线表」和「集末钩子计划表」两个结构化产物输出要求
  - _需求: 14.5, 14.6, 36.2_

- [x] 3. 修正核心技能文件：script_execution_adaptation.md
  - 在改编策略中明确声明竖屏短视频平台约束
  - _需求: 14.7, 12.8_

- [x] 4. 修正核心技能文件：script_agent_decision.md
  - 增加执行层确认消息展示规则
  - 增加禁止自动重试约束
  - 在【项目配置】模板中增加风格技能包路径字段
  - _需求: 18.2, 23.1, 23.5_

- [x] 5. 修正核心技能文件：script_agent_supervision.md
  - 增加「情绪具象化」审核维度
  - 增加「钩子类型多样性」审核维度
  - 增加「短剧平台适配」审核维度
  - 增加「章节全覆盖」双向检查
  - _需求: 12.6, 12.7, 12.8, 20.4_

- [x] 6. 修正核心技能文件：production_agent_execution.md
  - 增加 videoDesc 12 维度规范
  - 增加跨批次连续性记录规则
  - 增加反穿帮检查 8 项
  - 增加「表演锚点卡」维护规则
  - 增加衍生资产去重逻辑
  - _需求: 17.1, 17.2, 17.3, 17.4, 19.2, 25.4, 25.5, 31.1, 31.2, 31.3, 34.1, 34.3, 34.4, 34.5_

- [x] 7. 修正核心技能文件：production_agent_decision.md
  - 在派发指令模板中增加风格技能包路径字段
  - 增加 deepRetrieve 无结果时的六阶段选择提示
  - _需求: 18.4, 18.5, 23.2, 23.3_

- [x] 8. 修正核心技能文件：production_agent_supervision.md
  - 增加「视觉连续性」专项审核维度（7条铁律逐项检查）
  - 增加「情绪渐进」专项审核维度
  - 增加「台词-时长匹配」审核维度
  - 增加「转场策略」审核维度
  - 增加「定场镜头数量」审核维度
  - 增加「环境动态密度」审核维度
  - 将「创作规划完整性」审核从五个维度更新为六个维度
  - 统一导演规划字数上限为 1200 词
  - 明确监督层加载 director_planning_style.md 和 director_planning_narrative.md 的文件路径
  - 增加「角色辨识度与表演真实感」审核维度
  - 增加分镜表超过8行时的分批审核标注规则
  - 增加导演规划内容超过2200字时的截断检测与补读规则
  - 增加衍生资产状态检查
  - _需求: 12.1, 12.2, 12.3, 12.4, 12.5, 20.1, 20.2, 20.5, 29.4, 32.1, 32.2, 32.3, 32.4, 34.8_

- [x] 9. 检查点 — 技能文件修改完成
  - 确认所有 8 个核心技能文件已按需求修改，ask the user if questions arise.

- [x] 10. 数据库迁移：app_agent_memory 新增字段
  - 在 `supabase/migrations/` 下创建新迁移文件
  - 为 `app_agent_memory` 表添加 `memory_tier TEXT NOT NULL DEFAULT 'message' CHECK (memory_tier IN ('style_bible','stage_summary','delta_memory','message'))`
  - 为 `app_agent_memory` 表添加 `scope_signature JSONB`
  - _需求: 4.1, 4.6, 33.1_

- [x] 11. 数据库迁移：新增 app_skill_versions 表
  - 在同一迁移文件中创建 `app_skill_versions` 表（id, file_path, changed_at, summary, hash_before, hash_after, changed_by, rollback_of）
  - 创建索引 `(file_path, changed_at DESC)`
  - _需求: 24.1, 24.2_

- [x] 12. 数据库迁移：app_quality_review 新增字段
  - 为 `app_quality_review` 表添加 `stage TEXT CHECK (stage IN ('story_skeleton','adaptation_strategy','director_planning','storyboard_table','storyboard_panel','video_prompt'))`
  - 添加 `grade TEXT CHECK (grade IN ('A','B','C','D'))`
  - 添加 `skill_file_path TEXT` 和 `skill_version_hash TEXT`
  - _需求: 6.3, 6.5_

- [x] 13. 数据库迁移：projects 表新增风格配置字段
  - 为 `projects` 表添加 `art_style_pack TEXT` 和 `story_style_pack TEXT`
  - _需求: 9.6, 13.8_

- [x] 14. 实现记忆分层系统：数据访问层
  - [x] 14.1 在 `backend/src/settings/agent_memory/` 中新增 `memory_tier.rs`，定义 `MemoryTier` 枚举及其序列化
    - _需求: 33.1, 4.1_
  - [x] 14.2 为 MemoryTier 枚举写属性测试
    - **属性 20：记忆分层合规性**
    - **验证：需求 33.1, 33.3, 33.4**
  - [x] 14.3 修改 `app_agent_memory` 查询函数，支持按 `memory_tier` 过滤；修改写入函数，接受 `memory_tier` 和 `scope_signature` 参数
    - _需求: 4.2, 33.2, 33.5_
  - [x] 14.4 实现记忆检索压缩逻辑：命中条目 > 3 条时压缩为不超过 220 字的结构化结果（must_keep / must_avoid / latest_change / scope）
    - _需求: 33.7_
  - [x] 14.5 为记忆检索压缩写属性测试
    - **属性 21：记忆检索压缩约束**
    - **验证：需求 33.7**

- [x] 15. 实现记忆分层系统：API 端点
  - [x] 15.1 修改 `POST /api/v1/agents/memory/append` 端点，增加可选 `memoryTier` 字段（默认 `message`）和 `scopeSignature` 字段
    - _需求: 4.5, 4.6_
  - [x] 15.2 修改 `POST /api/v1/agents/memory/query` 端点，增加 `memoryTier` 过滤字段
    - _需求: 33.2_
  - [x] 15.3 新增 `GET /api/v1/agents/memory/cost-overview` 端点，返回各层记忆条目数和近30次任务平均注入字数
    - _需求: 36.8_
  - [x] 15.4 为记忆隔离性写属性测试
    - **属性 7：记忆隔离性**
    - **验证：需求 4.1, 4.2**
  - [x] 15.5 为记忆范围签名完整性写属性测试
    - **属性 8：记忆范围签名完整性**
    - **验证：需求 4.6**

- [x] 16. 检查点 — 记忆分层系统完成
  - 确认迁移文件、数据访问层、API 端点均已实现，ask the user if questions arise.


- [x] 17. 实现技能文件版本管理模块
  - [x] 17.1 在 `backend/src/prompting/` 下新建 `skill_versions/` 目录，创建 `mod.rs`、`models.rs`、`persist.rs`、`rollback.rs`
    - _需求: 24.1, 37.2, 37.3_
  - [x] 17.2 在 `persist.rs` 中实现：写入技能文件内容时自动计算 SHA256 哈希并插入 `app_skill_versions` 记录
    - _需求: 24.1, 24.2_
  - [x] 17.3 在 `rollback.rs` 中实现回滚逻辑：恢复文件内容到指定版本，记录操作日志
    - _需求: 24.4_
  - [x] 17.4 新增 `GET /api/v1/skill-versions` 端点（按 file_path 查询版本历史）
    - _需求: 24.3_
  - [x] 17.5 新增 `POST /api/v1/skill-versions/rollback` 端点
    - _需求: 24.4_
  - [x] 17.6 为技能文件版本记录完整性写属性测试
    - **属性 15：技能文件版本记录完整性**
    - **验证：需求 6.5, 24.1, 24.2**

- [x] 18. 增强质量评审模块
  - [x] 18.1 修改 `backend/src/prompting/quality/` 中的模型定义，增加 `stage`、`grade`、`skill_file_path`、`skill_version_hash` 字段
    - _需求: 6.3_
  - [x] 18.2 修改质量评审写入逻辑，在写入时关联当前技能文件版本哈希
    - _需求: 6.5_
  - [x] 18.3 确认 `GET /api/v1/quality/stage-pass-rate` 端点返回各阶段 A/B/C/D 分布和通过率（A+B 占比）
    - _需求: 6.4_
  - [x] 18.4 为质量评审筛选一致性写属性测试
    - **属性 14：质量评审筛选一致性**
    - **验证：需求 6.6**

- [x] 19. 增强项目配置模块
  - [x] 19.1 修改 `backend/src/projects/` 中的项目模型，增加 `art_style_pack` 和 `story_style_pack` 字段（DB 迁移已完成，需补充 Rust 模型和 API 层）
    - _需求: 9.6, 13.8_
  - [x] 19.2 新增 `PATCH /api/v1/projects/{id}/style-config` 端点，更新项目风格配置
    - _需求: 9.6_

- [x] 20. 实现局部返工能力（Patch Regeneration）
  - [x] 20.1 在 `backend/src/production/` 下新建 `patch/` 目录，创建 `mod.rs`、`models.rs`（PatchScope 枚举）、`dispatch.rs`（最小修复范围判断逻辑）
    - _需求: 35.1, 35.2, 37.2, 37.3_
  - [x] 20.2 在 `dispatch.rs` 中实现分级模型策略（low / high）
    - _需求: 35.4_
  - [x] 20.3 实现连续2次局部返工未达标时的「问题归因模式」
    - _需求: 35.7_
  - [x] 20.4 新增 `POST /api/v1/production/patch` 端点，接受 `{ scope, ids, reason, model_tier }`
    - _需求: 35.1_

- [x] 21. 检查点 — 后端核心模块完成
  - 确认版本管理、质量评审、项目配置、局部返工模块均已实现，ask the user if questions arise.

- [x] 22. 补全画风技能包文件结构（9 个画风包）
  - [x] 22.1 检查所有 9 个画风技能包，对缺少 `art_prompt/art_storyboard_video.md` 的包创建该文件（三模式风格标签）
    - _需求: 13.6, 28.1, 28.3_
  - [x] 22.2 对缺少 `driector_skills/director_planning_style.md` 的画风包创建该文件
    - _需求: 9.1, 13.1_
  - [x] 22.3 对缺少 `driector_skills/director_storyboard_table_style.md` 的画风包创建该文件
    - _需求: 9.2, 13.2_
  - [x] 22.4 对缺少 `driector_skills/director_storyboard.md` 的画风包创建该文件
    - _需求: 9.3, 13.3_
  - [x] 22.5 对缺少 `art_prompt/art_character.md`（含四视图规范）的画风包创建该文件
    - _需求: 26.4, 28.1_
  - [x] 22.6 对缺少 `art_prompt/art_character_derivative.md`（含 L1 妆容决策）的画风包创建该文件
    - _需求: 26.5, 28.1_
  - [x] 22.7 对缺少 `art_prompt/art_scene.md`、`art_scene_derivative.md`、`art_prop.md`、`art_prop_derivative.md` 的画风包创建这些文件
    - _需求: 28.1_

- [x] 23. 补全故事风格技能包文件结构（12 个风格包）
  - [x] 23.1 为 Comedy_humor、Coming_of_age、Family_warmth、Historical_epic、Hot_blooded_action、Mystery_thriller、Psychological_drama、Scifi_post_apocalypse、Urban_workplace_drama 这 9 个缺少内容的风格包创建 `driector_skills/director_planning_narrative.md`（主题立意、叙事结构、情绪设计、声音方向四个必填章节）
    - _需求: 27.1, 27.3, 27.4_
  - [x] 23.2 为上述 9 个风格包创建 `driector_skills/director_storyboard_table_narrative.md`（景别选择、运镜节奏、时长把控、转场设计）
    - _需求: 27.1, 27.3_
  - [x] 23.3 为所有 12 个风格包创建 `script_execution_skeleton_narrative.md`（三幕结构划分、分集策略、付费卡点设计）
    - _需求: 13.4_
  - [x] 23.4 为所有 12 个风格包创建 `script_execution_script_narrative.md`（台词风格、场景描写、情绪表达）
    - _需求: 13.5_

- [x] 24. 检查点 — 技能包补全完成
  - 确认所有画风包和故事风格包的必需文件均已创建，ask the user if questions arise.


- [x] 25. 实现技能包加载与校验逻辑（后端）
  - [x] 25.1 在 `backend/src/prompting/skills/` 中实现画风技能包加载函数：按优先级加载 `art_prompt/` 下各文件，文件缺失时记录 WARN 日志并降级使用通用规范
    - _需求: 9.4, 26.1, 26.2, 28.2_
  - [x] 25.2 实现故事风格技能包加载函数：加载 `driector_skills/` 下各文件，文件缺失时向用户提示（不静默降级）
    - _需求: 27.2_
  - [x] 25.3 实现技能包完整性校验：检查画风包必需 7 个 art_prompt 文件和 3 个 driector_skills 文件是否存在
    - _需求: 13.7, 28.2_
  - [x] 25.4 在技能文件写入成功后自动触发版本记录（调用 skill_versions persist 逻辑）
    - _需求: 24.1, 24.2_

- [x] 26. 增强提示词模板：videoPromptGeneration.txt
  - 将「视觉风格约束」来源描述替换为明确的文件加载路径（优先 `art_prompt/art_storyboard_video.md`，兜底通用规范）
  - 增加通用兜底风格标签（三模式各自的默认值）
  - 增加空镜专项处理规则（不添加角色一致性约束，重点描述环境氛围和情绪衔接）
  - 增加无台词分镜「无台词」标注规则
  - 增加批量处理时「角色外观一致性基准表」建立规则
  - _需求: 16.2, 16.3, 16.5, 30.1, 30.4_

- [x] 27. 增强提示词模板：eventExtraction.txt
  - 增加「场景可制作性」评估输出规范（格式：`可制作性:{高/中/低}({1-3字原因})`）
  - 增加「付费卡点潜力」标注输出规范（格式：`付费潜力:{有/无}({1-5字类型})`）
  - _需求: 17.5, 17.6_

- [x] 28. 增强提示词模板：scriptAssetExtraction.txt
  - 增加角色 prompt 最低 5 个视觉维度约束
  - 增加场景 prompt 最低 5 个视觉维度约束
  - 增加多称呼角色处理规则
  - 增加道具提取判断标准
  - 增加「衍生潜力」字段标注规则和资产重要性分级规则
  - 增加 resultTool 调用前完整性自查规则
  - _需求: 15.1, 15.2, 22.1, 22.2, 22.3, 22.4, 22.5_

- [x] 29. 检查点 — 提示词模板增强完成
  - 确认三个提示词模板文件均已按需求修改，ask the user if questions arise.

- [x] 30. 属性测试：分镜表规则（production/storyboard）
  - [x] 30.1 写属性测试：情绪强度渐进性
    - **属性 1：情绪强度渐进性**
    - 生成随机情绪强度序列，验证同一角色连续分镜中不出现连续 3 条相同情绪强度
    - **验证：需求 1.3, 12.2**
  - [x] 30.2 写属性测试：景别连续性约束
    - **属性 4：景别连续性约束**
    - 生成随机景别序列，验证不出现连续 3 条相同景别
    - **验证：需求 2.4, 11.1**
  - [x] 30.3 写属性测试：定场镜头数量约束
    - **属性 5：定场镜头数量约束**
    - 生成随机场景分镜列表，验证每场景定场镜头 ≤ 2 个
    - **验证：需求 2.7, 12.5**
  - [x] 30.4 写属性测试：无台词镜头时长约束
    - **属性 6：无台词镜头时长约束**
    - 生成随机无台词分镜，验证 duration ≤ 6 秒（一镜到底 ≤ 12 秒）
    - **验证：需求 2.8**
  - [x] 30.5 写属性测试：含台词分镜时长下限
    - **属性 12：含台词分镜时长下限**
    - 生成随机含台词分镜（含情绪状态），验证 duration >= ceil(字数/语速)+1
    - **验证：需求 5.4, 12.3**
  - [x] 30.6 写属性测试：分镜面板 track 跨场景换组
    - **属性 22：分镜面板 track 跨场景换组**
    - 生成跨场景分镜序列，验证不同场景必须属于不同 track，同一 track 累计时长 ≤ 15 秒
    - **验证：需求 25.2, 25.3**

- [x] 31. 属性测试：剧本规则（scripting/scripts）
  - [x] 31.1 写属性测试：情绪曲线层次覆盖
    - **属性 2：情绪曲线层次覆盖**
    - 生成随机场景列表，验证强度层次 ≥ 3 且高强度场景不在前 20%
    - **验证：需求 1.5, 14.3**
  - [x] 31.2 写属性测试：开场冲突约束
    - **属性 9：开场冲突约束**
    - 生成随机剧本场景列表，验证前 3 场中有冲突或悬念标记
    - **验证：需求 5.1, 14.2**
  - [x] 31.3 写属性测试：集末钩子类型多样性
    - **属性 10：集末钩子类型多样性**
    - 生成随机钩子类型序列，验证不出现连续 3 个相同类型
    - **验证：需求 5.2, 14.6**
  - [x] 31.4 写属性测试：台词字数约束
    - **属性 11：台词字数约束**
    - 生成随机台词字符串，验证字符数 ≤ 20
    - **验证：需求 5.3**

- [x] 32. 属性测试：视频提示词规则（production/flow_data）
  - [x] 32.1 写属性测试：画质降级词禁止
    - **属性 3：画质降级词禁止**
    - 生成随机提示词字符串，验证不包含黑名单词汇（film grain、imperfect focus、柔焦、朦胧感等）
    - **验证：需求 2.2**
  - [x] 32.2 写属性测试：视频提示词台词保留
    - **属性 16：视频提示词台词保留**
    - 生成随机台词，验证生成的视频提示词包含台词原文且有类型标注
    - **验证：需求 7.1**
  - [x] 32.3 写属性测试：Seedance 2.0 音色维度完整性
    - **属性 17：Seedance 2.0 音色维度完整性**
    - 生成随机情绪+台词组合，验证 9 个音色维度存在且与情绪状态一致
    - **验证：需求 7.2, 16.1**
  - [x] 32.4 写属性测试：多参模式资产编号顺序性
    - **属性 18：多参模式资产编号顺序性**
    - 生成随机资产列表，验证编号从 @图1 连续递增，同一角色编号一致
    - **验证：需求 7.3, 16.4**

- [x] 33. 属性测试：事件提取与资产（narrative/events, assets/generate）
  - [x] 33.1 写属性测试：事件提取格式合规性
    - **属性 19：事件提取格式合规性**
    - 生成随机章节文本，验证输出行格式（|开头|结尾|7字段）且集长以「X秒」格式输出
    - **验证：需求 10.1, 10.3**
  - [x] 33.2 写属性测试：衍生资产去重
    - **属性 23：衍生资产去重**
    - 生成相似衍生资产候选，验证相似度 > 80% 时不创建新条目
    - **验证：需求 31.1, 31.2**

- [x] 34. 属性测试：监督层审核摘要（harness/supervision）
  - [x] 34.1 写属性测试：监督层审核摘要结构完整性
    - **属性 13：监督层审核摘要结构完整性**
    - 生成随机审核输出，解析 XML 验证 grade/severeCount/mediumCount/minorCount/nextAction 五个字段均存在，severeCount>0 时 nextAction 含至少 2 个修复方案
    - **验证：需求 6.1, 6.2**

- [x] 35. 最终检查点 — 确认所有测试通过
  - 确认所有属性测试和单元测试通过，ask the user if questions arise.

## 备注

- 标注 `*` 的子任务为可选测试任务，可在 MVP 阶段跳过
- 每个任务均引用具体需求编号，便于追溯
- 技能文件（Markdown）和提示词模板（.txt）修改不触发 `refactor:check`；数据库迁移和 Rust 后端修改需在提交前运行 `bash scripts/refactor-check.sh`
- 属性测试使用 Rust `proptest` 库，每个测试最少运行 100 次迭代，注释格式：`// Feature: ai-drama-quality-optimization, Property {N}: {property_text}`
