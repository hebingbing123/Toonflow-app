# 实现计划：short-video-space-consistency

## A. Project config 输入归一化

- [x] A1. `PATCH /api/v1/projects/{id}`：所有 text fields 做 trim + empty->null（与 CREATE 对齐）
- [x] A2. `PATCH`：`target_platforms` 元素 trim + 过滤空；字段出现时必须非空并通过 `validate_target_platforms`
- [x] A3. `POST /api/v1/projects`：`target_platforms` 元素 trim + 过滤空；字段出现时必须非空并通过 `validate_target_platforms`

## B. candidateStatus gate 一致性

- [x] B1. `short_video_export_check`：candidateStatus trim 后比较 pending，避免空格绕过

## C. 门禁

- [x] C1. `yarn refactor:check`
