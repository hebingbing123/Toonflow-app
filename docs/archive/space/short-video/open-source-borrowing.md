# 短视频 Space 可借鉴的开源能力

## 结论

Openflow 不该照搬开源项目的技术栈或单体任务实现，但很适合借它们已经验证过的产品路径。

这份文档已按源码做过一轮核对，当前主要参考：

- `MoneyPrinterTurbo`
- `Jellyfish`

源码核对后的结论是：

- `MoneyPrinterTurbo` 更值得借的是“单入口流水线”和“集中参数配置”
- `Jellyfish` 更值得借的是“候选确认、readiness、任务回跳、结果回写”这一整套生产工作台能力
- Openflow 不该重做成轻量单体生成器，而应把这些长处迁入现有 Rust + Flutter + PG 的工作流体系

## 已核对的源码范围

### MoneyPrinterTurbo

已查看：

- `app/controllers/v1/video.py`
- `app/services/task.py`
- `app/services/video.py`
- `README.md`

确认到的核心事实：

- 它的后端核心是围绕“生成一条短视频任务”展开
- 主链路是线性的：脚本 -> 关键词 -> 音频 -> 字幕 -> 素材 -> 合成成片
- 参数配置高度集中在单次视频任务里
- 任务状态与输出仍然偏向单任务目录、文件路径和轻量任务管理

### Jellyfish

已查看：

- `backend/app/services/studio/shot_preparation_state.py`
- `backend/app/services/studio/shot_video_readiness.py`
- `backend/app/services/studio/shot_extracted_candidates.py`
- `backend/app/services/studio/shot_assets_overview.py`
- `backend/app/core/task_manager/manager.py`
- `backend/app/services/worker/task_executor.py`
- `README.md`

确认到的核心事实：

- 它不是单点“出图/出视频”工具，而是围绕短剧生产工作台设计
- 它把候选提取、候选确认、镜头就绪、视频生成前检查做成了独立服务层
- 它把异步任务当成正式基础设施，而不是一个临时后台线程
- 它的任务中心和项目/章节/镜头上下文是有明确回跳关系的

## 源码核对后的借鉴优先级

### 优先借 Jellyfish 的部分

1. `shot preparation -> candidate confirmation -> ready for generation`
2. 镜头级 readiness 聚合
3. 任务中心与业务对象回跳
4. 候选资产与已确认资产的统一总览
5. 生成结果回写到镜头/媒体上下文

### 优先借 MoneyPrinterTurbo 的部分

1. 单入口流水线
2. 目标配置集中收口
3. 成片导向的结果体验
4. 快速批量出候选成片

### 不建议照搬的部分

`MoneyPrinterTurbo`：

- 单体 Python MVC 结构
- 以单视频任务为中心的状态组织
- 本地任务目录式输出管理

`Jellyfish`：

- 直接照搬其前后端技术栈没有必要
- 若没有结合 Openflow 现有项目/剧本/分镜/资产模型，孤立搬 readiness 也会失真

## 1. 单入口流水线

源码依据：

- `MoneyPrinterTurbo/app/services/task.py` 明确把视频生成组织成线性链路
- `MoneyPrinterTurbo/app/controllers/v1/video.py` 也体现了视频、字幕、音频围绕同一类任务入口展开

适合借鉴：

- 从主题到成片的顺序式入口
- 把脚本、素材、旁白、字幕、成片组织成一条可见主链
- 把“下一步该做什么”直接显示出来，而不是让用户自己在多个工作台之间判断

落到 Openflow：

- 让 `短视频 Space` 成为项目级总入口
- 统一跳转 Script Workspace、Production Workspace、任务中心、质量评审
- 在 Space 首页显示当前项目卡在哪一环

## 2. 集中式视频目标配置

源码依据：

- `MoneyPrinterTurbo` 的任务参数集中驱动脚本、素材、字幕、音频、画幅与合成行为
- 这证明“短视频目标配置集中管理”对创作型产品是高价值的

适合借鉴：

- 画幅
- 时长
- 平台
- 配音声线
- 字幕风格
- BGM 策略
- 真人 / 动漫模式

落到 Openflow：

- 这些配置应写回项目级元数据，而不是散落在单次任务参数里
- 后续脚本、分镜、导出、发布都读取同一套目标配置

## 3. 明确的中间就绪态

源码依据：

- `Jellyfish/backend/app/services/studio/shot_preparation_state.py`
- `Jellyfish/backend/app/services/studio/shot_video_readiness.py`

这两个服务已经把“准备完成”拆成可计算字段，而不是只靠用户自己判断。

适合借鉴：

- script breakdown
- shot preparation
- candidate confirmation
- ready for generation
- export ready

落到 Openflow：

- 给分镜建立更明确的 readiness 计算
- 让 Space 能直接显示“为什么还不能生成”
- 把候选角色、候选场景、候选视频和最终确认结果区分开

更具体地说，Jellyfish 已验证下面这组检查很有价值：

- 基础信息是否齐全
- 语义默认值是否齐全
- action beats 是否齐全
- 待确认候选是否清空
- 视频 prompt 是否可渲染
- 参考帧是否齐全
- 默认模型和 provider 是否可用
- 是否已有进行中的视频任务

## 4. 成片装配优先于重型剪辑

源码依据：

- `MoneyPrinterTurbo/app/services/video.py` 的重点是把现有素材、音频、字幕装配成最终视频
- 它不是重型剪辑器，但它验证了“先完成成片装配”是有效产品路径
- `Jellyfish` README 也强调 export 与 generation workspace，而不是先做复杂 NLE

适合借鉴：

- 先解决批量成片输出
- 先把旁白、字幕、BGM 和已选镜头装配成 rough cut
- 导出前做缺失项检查

不建议一开始就照搬：

- 重型时间线编辑器
- 多轨精细剪辑
- 帧级转场编辑

落到 Openflow：

- 先补“成片装配”和“导出校验”
- 再考虑轻量粗剪
- 最后才评估复杂 NLE

## 5. 结果导向的任务回路

源码依据：

- `Jellyfish/backend/app/core/task_manager/manager.py`
- `Jellyfish/backend/app/services/worker/task_executor.py`
- `Jellyfish` README 中对 task center 的描述

它们说明真正有用的不是“能跑异步任务”，而是任务状态、取消、结果、应用回写和业务上下文之间的闭环。

适合借鉴：

- 任务完成后自动回写上下文
- 从任务能回跳到项目、剧本、分镜
- 失败后不是只给一个报错，而是给返工入口

落到 Openflow：

- 任务中心按 `project / script / storyboard / publish` 四类对象回跳
- 失败重试拆成重新生成、局部返工、回写补偿
- 生成结果和发布结果都进入项目级生产概览

## 6. 候选确认与资产总览

源码依据：

- `Jellyfish/backend/app/services/studio/shot_extracted_candidates.py`
- `Jellyfish/backend/app/services/studio/shot_assets_overview.py`

这部分很关键，因为它证明“AI 先抽候选，用户再确认，系统再进入生成”是比直接把抽取结果当最终结果更稳的模式。

适合借鉴：

- 候选角色 / 场景 / 道具 / 服装先进入候选池
- 已确认资产和候选资产在同一视图里统一展示
- pending / linked / ignored 应是正式状态，而不是临时 UI 标记

落到 Openflow：

- 给分镜准备态补候选确认层
- 给资产工作台补统一总览
- 让 readiness 计算依赖候选确认是否完成

## 建议新增到 Space 的功能块

优先级 P0：

- 项目级短视频目标配置
- 项目生产概览
- 分镜 readiness 摘要
- 候选确认摘要
- 成片装配入口
- 发布准备状态

优先级 P1：

- 旁白、字幕、BGM 的项目级配置
- 导出前质量检查
- 任务中心的短视频阶段过滤
- 平台文案改写

优先级 P2：

- 轻量粗剪
- 候选版本对比
- 平台效果数据回流

## 和 Openflow 现有架构的关系

这条线应继续沿用当前仓库主路线：

- Rust `backend/` 负责项目配置、任务编排、发布作业、平台适配
- Flutter `frontend/` 负责 Space 编排界面
- Supabase/Postgres 记录发布配置、排程、状态、审计
- Harness/Agent 用于文案改写、标签生成、平台适配建议和失败诊断

## 最终判断

如果只选一个开源方向深借，当前更应该深借 `Jellyfish` 的工作台式生产模型。

如果只选一个开源方向做首屏体验优化，则更应该借 `MoneyPrinterTurbo` 的单入口成片路径。

Openflow 最合适的组合方式不是二选一，而是：

- 用 `MoneyPrinterTurbo` 的入口感
- 接 `Jellyfish` 的准备态和任务闭环
- 再叠加 Openflow 自己的自动发布能力
