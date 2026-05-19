# 文档模板

本目录包含 OpenFlow 项目的标准文档模板。使用这些模板可以确保文档的一致性和完整性。

## 📋 可用模板

### 1. ADR 模板 (Architecture Decision Record)

**文件**：[adr-template.md](./adr-template.md)

**用途**：记录重要的架构决策

**何时使用**：
- 需要做出影响系统架构的重要决策时
- 需要在多个技术方案中选择时
- 需要记录决策理由和权衡时

**使用步骤**：
1. 复制模板到 `docs/architecture/adr/` 目录
2. 按顺序编号（如 005-new-decision.md）
3. 填写所有必需部分
4. 提交 PR 进行审核

### 2. Runbook 模板

**文件**：[runbook-template.md](./runbook-template.md)

**用途**：创建运维操作手册

**何时使用**：
- 需要记录常见运维操作时
- 需要创建故障排查指南时
- 需要标准化运维流程时

**使用步骤**：
1. 复制模板到 `docs/operations/runbooks/` 目录
2. 使用描述性文件名（如 database-backup.md）
3. 填写所有必需部分
4. 在实际环境中验证步骤
5. 提交 PR 进行审核

### 3. 技术规格模板

**文件**：[spec-template.md](./spec-template.md)

**用途**：编写功能或特性的技术规格文档

**何时使用**：
- 开发新功能前需要详细设计时
- 需要跨团队协作时
- 需要记录技术实现细节时

**使用步骤**：
1. 复制模板到相应目录（如 `docs/product/specs/`）
2. 使用描述性文件名（如 user-authentication.md）
3. 填写所有必需部分
4. 与团队讨论和审核
5. 提交 PR

## 📝 文档编写最佳实践

### 通用原则

1. **清晰简洁**：使用简单明了的语言
2. **结构化**：使用标题、列表、表格组织内容
3. **可操作**：提供具体的步骤和示例
4. **保持更新**：定期审核和更新文档

### YAML Front Matter

所有文档应包含 YAML front matter：

```yaml
---
title: 文档标题
status: draft | review | active | deprecated
created: YYYY-MM-DD
updated: YYYY-MM-DD
authors:
  - 作者名
reviewers:
  - 审核人
tags:
  - 标签1
  - 标签2
---
```

### 文档状态

| 状态 | 说明 | 标记 |
|------|------|------|
| `draft` | 草稿，内容未完成 | 🚧 |
| `review` | 审核中，等待反馈 | 👀 |
| `active` | 已完成，当前有效 | ✅ |
| `deprecated` | 已废弃，仅供参考 | ⚠️ |

### 代码块

使用语法高亮的代码块：

````markdown
```bash
# Bash 命令
command --option value
```

```typescript
// TypeScript 代码
interface Example {
  field: string;
}
```

```sql
-- SQL 查询
SELECT * FROM table WHERE condition;
```
````

### 图表

使用 ASCII 图表或 Mermaid：

```
┌─────────┐      ┌─────────┐
│ 组件 A  │─────▶│ 组件 B  │
└─────────┘      └─────────┘
```

### 链接

- 使用相对路径链接其他文档
- 为外部链接提供描述性文本
- 定期检查链接有效性

示例：
```markdown
- [相关文档](../path/to/doc.md)
- [外部资源](https://example.com)
```

## 🔍 文档审核清单

在提交文档前，检查以下项目：

- [ ] 包含完整的 YAML front matter
- [ ] 标题层级正确（H1 → H2 → H3）
- [ ] 代码块有语法高亮
- [ ] 所有链接有效
- [ ] 拼写和语法正确
- [ ] 格式一致
- [ ] 包含必要的示例
- [ ] 更新了相关索引文件

## 📚 相关资源

- [文档贡献指南](../CONTRIBUTING.md)
- [文档总索引](../README.md)
- [Markdown 语法指南](https://www.markdownguide.org/)

## 💡 提示

- 从模板开始，但根据实际需要调整
- 不是所有部分都必须填写，删除不适用的部分
- 添加图表和示例可以提高文档可读性
- 定期审核和更新文档，保持其准确性

---

**维护者**：文档团队  
**最后更新**：2026-05-19
