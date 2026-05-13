---
name: 短视频轻量成片剪辑台 Spec
status: draft
owner: codex
last-updated: 2026-05-05
---

# 1. 目标

本 spec 解决的不是“做一个完整 NLE”，而是把 Toonflow 当前已经存在的分镜、候选视频、字幕/旁白文案、导出 sidecar，收束成一个真正可用的“成片装配 + 轻量粗剪”工作台。

目标顺序：

1. 先减少用户从“镜头生成完成”到“导出成片”之间的人工跳转和手工核对。
2. 在不降低视频质量的前提下，提供最常见的粗剪能力。
3. 给后续是否引入更完整剪辑能力留接口，但当前阶段不承担重型编辑器复杂度。

# 2. 为什么现在不直接做完整剪辑

虽然 `Jellyfish` 开源且值得借鉴，但 Toonflow 当前更适合先做轻量剪辑台，而不是直接照搬完整剪辑器。

原因：

- 当前仓库已经具备“装配基础”，但不具备“完整时间线编辑器”的完整底层模型。
- 我们现有强项是短剧生产链和分镜资产沉淀，不是实时多轨编辑器。
- 如果现在强行上完整剪辑，主成本会落在时间线模型、回写一致性、导出渲染、交互复杂度，而不是页面本身。
- 当前更高 ROI 仍然是让用户更快拿到可发的短剧成片，而不是做一个通用后期软件。

# 3. 当前仓库已有基础

## 3.1 后端已有成片装配 sidecar

[backend/src/production/workbench/storyboard_ops/export/zip_export.rs](/Users/clive/Documents/source/cousor/Toonflow-app/backend/src/production/workbench/storyboard_ops/export/zip_export.rs) 已经产出：

- `manifest.json`
- `storyboard.csv`
- `timeline.json`
- `subtitles.srt`
- `voiceover_script.txt`
- `voiceover_segments.json`
- `assembly_plan.json`

这说明系统已经有“镜头顺序、时长、字幕/旁白、导出装配”的雏形。

## 3.2 前端已有视频候选与当前采用版本

[frontend/lib/storyboard_editor/video_section.dart](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/storyboard_editor/video_section.dart) 已经存在：

- 当前选中视频
- 候选视频
- 轨道字段
- 导出结果显示
- 字幕/旁白文案保存入口

所以“轻量剪辑台”不需要从零创造镜头媒体模型，而应复用现有分镜媒体状态。

## 3.3 当前配音现状

当前项目对“配音”的解决方式，严格来说还是“配音准备链路”，不是“完整自动 TTS 成片链路”。

现状包括：

- 分镜可保存显式 `字幕/旁白文案`
- 导出时可生成 `voiceover_script.txt` 与 `voiceover_segments.json`
- `voiceover_ready` 的判定来自“有显式旁白文案”或“可回退到 prompt”
- 系统设置里存在 `ttsDubbing`，但当前是 disabled，见 [backend/src/settings/agent_deploy/storage.rs](/Users/clive/Documents/source/cousor/Toonflow-app/backend/src/settings/agent_deploy/storage.rs)

因此当前仓库更接近：

1. 先准备好可配音文本和时间段
2. 再导出给后续 TTS / 成片装配使用

而不是已经内建：

- 声线选择
- 情绪化 TTS 合成
- 音频资产回写
- 旁白音频与镜头自动拼装

# 4. 产品定义

## 4.1 本阶段要做什么

新增“成片剪辑台（轻量版）”，定位为：

- 成片装配台
- 导出前检查台
- 粗剪操作台

支持项目/脚本范围内的短剧成片整理，但不承担复杂精修任务。

## 4.2 本阶段不做什么

明确不做：

- 完整时间线编辑器
- 帧级裁切
- 复杂转场编辑
- 深度多轨混音
- 通用视频编辑器式自由拖拽系统

# 5. MVP 范围

## 5.1 只读成片总览

先新增只读总览，按剧本或分镜顺序展示：

- 镜头顺序
- 当前采用视频
- 候选视频数量
- 分镜时长
- 字幕/旁白文案
- `voiceover_ready`
- 导出可用性
- 缺失项诊断

这是第一步，因为它能立刻减少用户手动在多个界面来回核对。

## 5.2 轻量粗剪操作

在只读总览稳定后，开放以下操作：

- 调整镜头顺序
- 启用 / 禁用镜头
- 切换当前采用的视频版本
- 标记镜头“待返工”

这些操作都应回写到现有分镜/生产上下文，而不是建立平行状态。

## 5.3 项目级成片配置

把零散配置收束成项目级或导出级设置：

- BGM
- 字幕样式
- 旁白声线
- 旁白输出模式（仅脚本 / 脚本+TTS / 静音）

这样可以减少用户每个分镜重复设置。

## 5.4 导出前总校验

新增成片导出前诊断，至少提示：

- 未选当前视频
- 时长缺失或异常
- 字幕/旁白缺失
- `voiceover_ready=false`
- 轨道信息不完整

# 6. 数据设计原则

## 6.1 不新建平行剪辑资产系统

当前阶段不单独创建一套重量级 timeline domain model。

优先复用现有：

- storyboard rows
- production storyboard items
- selected video / candidate video
- `assembly_plan.json`
- `voiceover_segments.json`

必要时只补一层“成片装配快照”或“导出配置”。

## 6.2 当前建议的数据最小新增

建议优先只考虑下面两类新增对象：

1. `assembly configuration`
   - project_uuid / script scope id
   - bgm
   - subtitle_style
   - voiceover_mode
   - voice_profile
2. `assembly shot overrides`
   - storyboard_id
   - enabled
   - order_override
   - selected_video_override

这样能满足粗剪，不会一下子把系统带进复杂 timeline 编辑。

# 7. 配音接入策略

## 7.1 当前结论

目前 Toonflow 的“配音”主要停在：

- 文案准备
- 时序准备
- 导出 sidecar

还没有正式的内建 TTS 成片交付链路。

补充：对照 `master` 后可以确认，旧仓库并非完全没有配音相关能力，而是已经存在：

- `AiAudio` 入口
- `ttsRequest` 供应商适配函数
- `ttsDubbing` 部署位
- 供应商模型定义中对 `tts` / `audio` 的预留

但现有证据更像“能力接口与配置壳子”，并不能证明旧仓库已经完成了稳定的“旁白生成 -> 音频资产回写 -> 成片装配”闭环。

因此在重构分支里，这件事不应继续视为低优先级，而应提升为最高优先级补齐项。

## 7.2 推荐接法

如果后续要补配音，建议按三步做，而不是一步做满：

### Phase A：先把旁白当成正式资产

- 明确区分“字幕文本”和“旁白文本”
- 给镜头/项目增加声线配置来源
- 导出时稳定生成 TTS request payload

### Phase B：接入单一 TTS 供应商

先只接一个供应商，要求：

- 可控声线
- 基础情绪/语速
- 成本可控
- 失败可重试

并把产物回写为音频资产，而不是只返回一次性 URL。

### Phase C：并入成片装配

- 成片装配优先使用已生成旁白音频
- 没有音频时退回文本 sidecar
- 导出诊断里明确区分“可配音”和“已具备音频”

## 7.3 为什么不现在直接上多供应商 TTS

因为当前更缺的是：

- 配音资产回写
- 配音与镜头时长的契约
- 配音失败重试与状态可见性

这些没收住之前，多供应商只会放大复杂度。

## 7.4 优先级调整

在对照 `master` 之后，这一节的优先级需要上调：

- 配音不再属于“有空再补的体验增强”
- 它属于短剧成片链路缺失的核心功能
- 优先级应高于低优先级后期剪辑台扩展

执行顺序应调整为：

1. 先补正式配音链路
2. 再补成片装配消费音频资产
3. 最后再做更丰富的轻量剪辑交互

# 8. 与 Jellyfish 的借鉴边界

可以借鉴的：

- 从脚本到成片的单入口工作流
- 把后期装配显式纳入主流程
- 把导出上下文做成稳定的中间产物

不建议直接照搬的：

- 完整 UI 交互模型
- 其具体技术栈实现
- 假设已经存在完整编辑时间线的数据结构

正确的借鉴方式是：

1. 借工作流
2. 借装配理念
3. 借导出产物设计
4. 不直接硬搬完整编辑器复杂度

# 9. 实施顺序

## Wave A：成片只读总览

- 新增成片剪辑台入口
- 展示镜头顺序、视频、字幕/旁白、时长、导出状态
- 增加缺失项诊断

## Wave B：轻量粗剪

- 调整镜头顺序
- 启用 / 禁用镜头
- 切换当前采用视频版本

## Wave C：成片级配置

- BGM
- 字幕样式
- 旁白模式
- 声线配置

## Wave D：配音补齐

- 先补 TTS payload 与音频资产回写
- 再补单供应商 TTS
- 再接成片装配

## Wave E：再评估是否需要更完整剪辑

只有在下面几件事都稳定后，才评估更重的剪辑能力：

- readiness 明确
- 回写稳定
- 导出稳定
- 配音资产稳定
- 用户主要痛点已从“装配麻烦”转向“需要更精细手工编辑”

# 10. 成功标准

满足下面几点，就说明这个方向是对的：

- 用户从“镜头生成完成”到“导出成片”的步骤明显减少
- 用户不需要在多个页面手工核对字幕/旁白/视频是否齐全
- 成片导出前就能看出缺什么
- 配音从“脚本文本准备”逐步升级到“可落地音频资产”
- 不用引入完整重型剪辑器，也能解决大部分短剧粗剪需求
