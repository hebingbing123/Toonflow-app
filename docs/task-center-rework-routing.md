# Task Failure Rework Routing (H3)

This document defines the task-center failure card action mapping for short-video workflows.

## Three-way Rework Actions

- `重新生成`: retry failed task via existing jobs retry API.
- `局部返工`: deep-link to owning workspace context (project/script/storyboard/publish).
- `回写补偿`: keep task in task center, preload UUID detail probe for writeback diagnostics and compensation.

## Route Mapping Rules

All workspace/project restore below follows **UUID-first** context recovery. Numeric task / storyboard / script identifiers may still participate as domain-specific compat keys, but project scope should prefer `project_uuid` and only fall back to `project_numeric_id` when needed.

- `publish*` task kinds or payload with `publish_draft_id`
  - Partial rework route: Short-video Space (`ProductWorkspacePane.shortVideoSpace`)
  - Compensation: UUID detail + inspect `error_details` writeback keys
- `storyboard*` task kinds or payload/deep-links with `storyboard_numeric_id`
  - Partial rework route: Production Workspace (`ProductWorkspacePane.productionWorkspace`)
- `script*` task kinds or payload/deep-links with `script_numeric_id`
  - Partial rework route: Script Workspace (`ProductWorkspacePane.scriptWorkspace`)
- Fallback project-scoped tasks (prefer `project_uuid`, allow `project_numeric_id` legacy fallback)
  - Partial rework route: Short-video Space (`ProductWorkspacePane.shortVideoSpace`)

## Writeback Compensation Trigger Heuristics

The compensation button is shown when:

- task kind contains `export` or `publish`, or
- `error_details.code` contains `writeback` / `persist`.

These heuristics keep the action focused on "task completed but business object not fully written back" failures.
