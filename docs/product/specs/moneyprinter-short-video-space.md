# MoneyPrinterTurbo 优点迁移到 Openflow 的建议

## 结论

可以结合，但不建议照搬 `MoneyPrinterTurbo` 的 Python MVC 和单体视频任务实现。

更适合 Openflow 的做法是：

1. 保留现有 Rust + Flutter + Supabase 架构。
2. 借用它最成功的产品形态：把“主题 -> 脚本 -> 素材 -> 旁白 -> 字幕 -> 成片”组织成单入口流水线。
3. 先新增一个 `短视频 Space`，作为现有项目、脚本工作区、制作工作区、任务中心、质量评审的上层编排入口。

## MoneyPrinterTurbo 真正值得借的点

- 单入口：用户不需要先理解很多模块，再开始生成第一条视频。
- 流水线完整：脚本、关键词、配音、字幕、素材、成片是一条可见链路。
- 参数集中：画幅、语音、字幕、BGM、素材来源都在同一段流程里调整。
- 结果导向：用户目标是“快速做出一条能发的视频”，不是维护复杂工程对象。

## Openflow 当前更强的地方

- 已有项目、小说、剧本、分镜、资产、任务、质量评审等完整生产域模型。
- 已有 Harness Agent 工作区、WS 事件、回写机制、任务作业体系。
- 已有 production/script 双工作区，适合承载比 `MoneyPrinterTurbo` 更复杂的内容生产链。

所以迁移方向不该是“重做一个 MoneyPrinterTurbo”，而应是“在 Openflow 上做一个更产品化的短视频生产入口”。

## 建议的 Space 定位

`短视频 Space` 先做编排层，不急着新增新的重后端链路。

并且不应默认只有动漫模式。

Space 第一屏就应该让用户显式选择：

- `动漫短剧`
- `真人短剧`

两者共用同一条生产主链，但前置准备和验收重点不同。

第一阶段只做四件事：

- 项目入口收口：题材、风格、创作手册、目标平台。
- 脚本入口收口：主题生成、脚本编辑、分段检查。
- 制作入口收口：素材准备、分镜出图、旁白文案草稿。
- 结果入口收口：任务状态、失败重试、质量复核。

## 推荐分两波推进

### Wave 1：入口编排

- 新增 `短视频 Space`
- 支持用户切换 `动漫短剧 / 真人短剧`
- 支持在 Space 内选择项目，并将 `projectType=short_drama`、`mode`、`videoRatio` 写回项目
- 从 Space 跳转到：
  - 项目
  - 脚本工作区
  - 制作工作区
  - 任务中心
  - 质量评审
- 明确一条标准路径，先把已有能力串起来

### Wave 2：补齐 MoneyPrinterTurbo 风格能力

- 统一的“视频目标配置”
  - 平台
  - 画幅
  - 时长
  - 创作模式
  - 语音
  - 字幕样式
  - BGM
- 一键批量生成候选成片
- 将旁白、字幕、BGM 变成可追踪的任务阶段
- 给成片增加可比对的质量验收摘要

其中真人模式建议额外补齐：

- 真人参考图 / 参考镜头素材
- 角色与场景真实感约束
- 偏口播、表演、纪实感的脚本模板
- 与动漫模式不同的质量验收维度

## 不建议直接照搬的部分

- Python 单体任务实现：与 Openflow 现有 Rust jobs / workbench 不同路。
- 本地文件任务目录式状态管理：Openflow 已经有更正式的任务、资产、项目模型。
- 以“一个 API 完成全部视频生成”为中心的结构：对你们现有多阶段生产域不够细。

## 这次增量的意义

本轮先落 `短视频 Space` 入口，是为了把后续“借鉴 MoneyPrinterTurbo”这件事收束成明确产品面，而不是散落到脚本、资产、任务、字幕几个模块里各改一点。

## 结合 Jellyfish 后建议补充的任务

参考 `Jellyfish` 之后，更值得借鉴的不是“再做一个大而全工作台”，而是把短剧生产里的几个关键中间状态做得更清楚：

- `script breakdown -> shot preparation -> candidate confirmation -> shot ready -> generation workspace`
- 统一任务中心可回跳到项目 / 剧本 / 分镜
- 生成结果能稳定回写到分镜 / 媒体上下文
- export 不是单次下载，而是带上下文的成片输出

对应到 Openflow，建议在 `短视频 Space` 后续新增下面这批任务。

### Wave 3：把“可生成”前的准备态做实

- [x] 给分镜增加更明确的 `ready for generation` 视图状态 — `GET …/short-video-readiness` + `short_video/storyboard_readiness.rs` + 分镜工作台 readiness UI
- [x] 在 Space 中增加“未就绪原因”摘要 — Space 就绪面板消费 readiness rollup / reason codes
- [x] 给分镜补一个候选确认流 — `confirm_storyboard_candidates` + `candidateStatus` 写入 metadata
- [x] 把“候选确认完成”纳入分镜 readiness — readiness 计算含 `candidate_pending` / 确认门禁

### Wave 4：把生成结果真正沉淀成可复用资产

- [x] 给分镜建立更清晰的媒体槽位 — storyboard metadata `shortVideo` 槽位 + 候选/当前视频字段（非完整 NLE 轨）
- [x] 把“设为当前视频 / 局部返工 / 导出”统一视为分镜媒体操作 — workbench select/delete video + export-check 对齐
- [x] 给批量生成结果增加回写摘要 — `short_video/writeback.rs` + 任务 result `writeback` 块
- [x] 增加“生成结果回写失败 / 回写不完整”的显式诊断 — video/voiceover worker `error_details` + 任务中心写回补偿入口

### Wave 5：把任务中心变成短视频生产调度台

- [x] 给任务中心增加按 `project / script / storyboard` 的快捷回跳入口 — `task_center/support.dart` deep links
- [x] 给视频、出图、导出任务增加更清晰的阶段标签 — `taskCenterShortVideoStageLabel`（prep/image/video/export/quality）
- [x] 给 Space 增加“当前项目生产概览” — `GET …/production-overview` + Space 生产指标卡
- [x] 把“失败重试”细分成重新生成、局部返工、回写补偿 — 失败任务区三分动作 + 按 job kind / writeback code 区分重试文案

### Wave 6：补真正有价值的后期输出，而不是上来做完整剪辑器

`Jellyfish` 的 README 能确认它强调 export 和媒体上下文，但没有足够证据说明它已经做了完整时间线剪辑器。所以 Openflow 更适合先补“成片装配”而不是直接做一个复杂 NLE。

- [x] 新增“成片装配”阶段 — `GET …/short-video-assembly` 只读 rough cut 快照（非时间线编辑器）
- [x] 给每个分镜补导出所需的最小字段校验 — `GET …/short-video-export-check` + 装配镜头 `export_gap` facets
- [x] 支持按剧本 / 分镜顺序导出预组装结果 — `POST …/short-video-pre-assembly` → job `short_video.pre_assembly` 产出 manifest JSON
- [x] 给导出结果增加质量摘要 — export-check `storyboard_gaps` + Space 导出前检查 UI
- [x] 把 BGM、字幕样式、旁白声线收成项目级 / 成片级配置 — `app_project` 列 + assembly `effective_short_video_defaults`

### Wave 7：低优先级引入后期剪辑能力

`Jellyfish` 现在已经把 “后期剪辑” 放进整体短剧工作台叙事里，所以 Openflow 也可以立相关任务，但应放在较低优先级，并按“先装配、后编辑”的顺序进入。

- [ ] 低优先级：新增“成片剪辑台”只读版，先展示镜头顺序、时长、字幕、旁白、BGM 和当前成片预览，不急着开放复杂编辑
- [ ] 低优先级：支持对镜头级成片做基础重排、启停、替换当前视频版本，先覆盖最常见的粗剪需求
- [ ] 低优先级：支持字幕样式与 BGM 的成片级统一调整，而不是逐分镜重复修改
- [ ] 低优先级：支持导出前总校验，提示缺少视频、字幕、旁白或时长异常的镜头
- [ ] 低优先级：评估是否引入简单时间线视图，用于镜头顺序调整、时长对齐和字幕检查
- [ ] 低优先级：评估是否需要多轨能力（视频 / 字幕 / 旁白 / BGM），若只是短剧批量拼装则先限制为轻量轨道模型

### 暂不建议一开始就做成重型编辑器

下面这些方向可以放在更后面，不建议作为当前阶段主目标：

- [ ] 完整时间线编辑器
- [ ] 多轨精细剪辑
- [ ] 帧级别转场编辑
- [ ] 复杂音频混流台

原因不是这些没价值，而是当前 Openflow 的更高 ROI 仍然是：

1. 先把“分镜是否就绪”
2. “结果是否回写”
3. “任务是否可回跳”
4. “是否能批量装配成片”

这四件事做实之后，再决定是否真的要上复杂后期剪辑层。
