# ui-ux-audit（Agent Skill 索引）

Flutter 产品壳 **只读** UI/UX 截图审计：integration_test 多视口 PNG + 结构化 `issues.json`。

## Cursor 自动发现

```bash
./scripts/link-cursor-skills.sh   # 若仓库提供；将 .cursor/skills 链到本机
```

Skill 主文件：[`.cursor/skills/ui-ux-audit/SKILL.md`](../../.cursor/skills/ui-ux-audit/SKILL.md)

## Codex

- 配置：`.codex/skills/ui-ux-audit/skill.json`
- 长流程：`.codex/skills/ui-ux-audit/prompt.md`

## 一键截图

```bash
bash scripts/run-ui-ux-audit-e2e.sh
```

输出：`.codex/skills/ui-ux-audit/output/e2e/{desktop,mobile}/`

## 问题清单

- Schema：`.codex/skills/ui-ux-audit/issues.schema.json`
- 示例：`.codex/skills/ui-ux-audit/examples.md`
- 写入：`.codex/skills/ui-ux-audit/output/issues.json`
