# 需求文档：short-video-space-hardening

## 概述

本 spec 聚焦对 `short-video-space` 相关链路进行**安全性、数据一致性与可观测性加固**，避免因“弱约束输入（尤其 JSON payload / metadata）”导致：

- readiness/概览等聚合接口在极端数据下 **SQL cast 崩溃**（500）
- 通过空格/大小写等方式 **绕过状态机/门槛**（例如 `candidateStatus`）
- publish / job 回流信息缺失，导致“任务成功但业务对象无状态”的 **隐性失败**

本 spec 的原则是：

- **对外契约保持兼容**（尽量不破坏现有 API 字段）
- **对内数据更严格**：输入归一化（trim/enum）、payload schema 校验、落库后可审计
- **统一语义**：同一概念（readiness gate / pending gate / in-flight job gate）跨端点一致

## 需求 1：readiness / 概览聚合的鲁棒性

### 1.1 生成任务 payload cast 防护

- readiness / production overview / workbench meta 等所有依赖 `payload->>'storyboard_numeric_id'::int` 的 SQL，必须：
  - 使用 `payload ? 'storyboard_numeric_id'`
  - 使用正则 `~ '^[0-9]+$'` 再 cast
- 验收：任意 job payload 写入非数字（例如 `"abc"`）不会导致聚合接口 500。

### 1.2 gate 字段归一化

- `candidateStatus` 等门槛字段的比较必须：
  - `TRIM(COALESCE(...,''))` 后再比较
- 验收：`" pending "` 与 `"pending"` 行为一致。

## 需求 2：publish 回流与输入校验加固

### 2.1 publish job 结果回写

- publish job 完成后：
  - draft 能记录 `last_publish_result`（job id、聚合计数、错误摘要、更新时间）
  - target 能记录每平台 `last_publish_result`（attempt_no、状态、错误摘要、更新时间）
- 验收：失败/部分失败后，用户能在 draft/target 看到最近一次投递结果摘要。

### 2.2 publish target 输入校验

- `platform_id`：trim 后不能为空
- `platform_id`：同一 draft 内不允许重复
- `serial_order`：不允许负数
- 验收：prepare checklist 能返回明确的 blocking issue codes。

## 需求 3：一致性测试与契约锁定

### 3.1 跨端点一致性

- `production-overview.ready_storyboard_count` 与 `/short-video-readiness` 的 `ready_for_generation` 规则保持一致（candidate gate、in-flight gate、prompt gate、reference gate）。

### 3.2 单测覆盖

- 为关键 gate/归一化规则补充单测：
  - candidateStatus trim
  - payload 非数字时不 panic / 不 500（通过 SQL predicate 结构 + 单测锁定）

## 非目标

- 不在本 spec 内大规模重构 jobs payload schema（可另起 spec）。
- 不引入破坏性迁移（如强制清洗历史数据）。
