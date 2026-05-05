# 需求文档：short-video-space-consistency

## 概述

本 spec 作为 `short-video-space` 的下一轮 review 输出，目标是解决“同一概念在不同端点/模块中语义漂移、输入归一化不一致、门槛可被弱输入绕过”的问题。

重点聚焦：

- 项目短视频配置（`app_project.*`）在 **CREATE vs PATCH** 的写入语义一致性
- readiness / production overview / assembly / export-check 等只读聚合对关键字段（如 `candidateStatus`）的比较规则一致
- 将“trim / empty -> null / enum canonicalization”收敛为可复用的工具函数，避免重复实现漂移

## 需求 1：输入归一化（Project config）

### 1.1 PATCH 与 CREATE 一致

- 所有文本类字段在 PATCH 与 CREATE 中应采用一致规则：
  - 先 `trim`
  - trim 后为空视为 `null`（清空）

### 1.2 target_platforms 归一化与校验

- `target_platforms`：
  - 对数组元素逐个 `trim`
  - 过滤掉空元素
  - 若提供该字段（非 null），则 **必须非空** 且均为合法 platform id

## 需求 2：门槛字段的比较语义一致

### 2.1 candidateStatus

- readiness 与 production overview 的 `candidateStatus` gate 已采用 `TRIM(... ) <> 'pending'`
- export-check 需要同样采用 trim 后比较，避免空格绕过 blocking

## 需求 3：回归测试与门禁

- 为本 spec 涉及的关键归一化/门槛逻辑补充单测（若缺失）
- 变更提交前需通过 `yarn refactor:check`

## 非目标

- 不在本 spec 内引入大规模状态机/allowlist 变更（例如把 unknown candidateStatus 一律视为 pending）；如需更严格 gate，将另起 spec 并明确产品语义变更与迁移策略。
