# 实现计划：short-video-space-hardening

## A. readiness / 概览鲁棒性

- [x] A1. `/short-video-readiness`：job payload cast 前加 `payload ? ...` + `~ '^[0-9]+$'` 防护；`candidateStatus` gate 加 `TRIM`
- [x] A2. `/production-overview`：ready_storyboard_count 规则与 readiness 对齐（同上）

## B. publish 回流与校验

- [x] B1. publish job 完成后回写 draft/target `last_publish_result` 摘要
- [x] B2. publish prepare：`platform_id` trim/非空、重复平台、负数 serial_order 校验 + 单测

## C. 验收与门禁

- [x] C1. `yarn refactor:check`

## 备注

- 本 spec 为 `short-video-space` 的加固补丁：不引入破坏性迁移。
