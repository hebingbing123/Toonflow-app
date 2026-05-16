# 短视频 Space

## 目标

把 Toonflow 已有的项目、小说、剧本、分镜、资产、任务、质量评审和 Agent 工作区，收敛成一个面向短视频生产的上层入口。

这条线的重点不是重做底层生产域，而是补上两个更像产品特色的层：

1. 借鉴开源短视频项目里已经验证过的高价值流程能力。
2. 在生成完成后补上“分发”这一环，支持可选自动发布到国内与海外平台。

## 这轮建议的定位

短视频 Space 后续建议拆成四段：

1. 选题与目标配置：题材、模式、画幅、平台、时长、创作手册。
2. 生产编排：脚本、素材、分镜、旁白、字幕、成片装配。
3. 质检与回写：就绪态、坏例、返工、版本确认。
4. 分发与复投：平台映射、发布排程、文案改写、发布结果回流。

其中前 3 段主要复用现有 Toonflow 能力，第 4 段是本轮新增特色。

## 文档索引

- [`open-source-borrowing.md`](./open-source-borrowing.md)：已补充 `MoneyPrinterTurbo` 与 `Jellyfish` 的源码核对结论
- [`auto-publishing-platforms.md`](./auto-publishing-platforms.md)
- [`implementation-breakdown.md`](./implementation-breakdown.md)：把借鉴结论和自动发布方案拆成可执行实施项
