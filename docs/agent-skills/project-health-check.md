# project-health-check（Agent Skill 索引）

跨 **Rust / Flutter / Supabase** 的只读工程体检：依赖与安全、API 契约、配置、RLS、观测、权限边界。

## Cursor

Skill：[`.cursor/skills/project-health-check/SKILL.md`](../../.cursor/skills/project-health-check/SKILL.md)

## 一键采集

```bash
bash scripts/run-project-health-check.sh
```

产物：

- `.codex/skills/project-health-check/output/run-manifest.json`
- `.codex/skills/project-health-check/output/raw/*`
- 审计结论（Agent 写入）：`.codex/skills/project-health-check/output/issues.json`

## Codex

- `.codex/skills/project-health-check/skill.json`
- `.codex/skills/project-health-check/prompt.md`
- Schema：`.codex/skills/project-health-check/issues.schema.json`

## 与 refactor 门禁的关系

`yarn refactor:agent` 覆盖 fmt/clippy/test/analyze/OpenAPI，**不替代**本 skill 的 6 维清单（RLS 静态审计、secrets 扫描、权限边界等）。
