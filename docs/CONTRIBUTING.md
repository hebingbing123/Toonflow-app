# 文档贡献指南

感谢你为 OpenFlow 文档做出贡献！本指南将帮助你了解如何创建和维护高质量的文档。

## 📋 目录

- [文档类型](#文档类型)
- [文档结构](#文档结构)
- [写作规范](#写作规范)
- [提交流程](#提交流程)
- [文档模板](#文档模板)

---

## 文档类型

OpenFlow 文档分为以下几类：

### 1. 技术文档
- **API 文档**：REST API、WebSocket、Webhooks
- **架构文档**：系统设计、技术选型、数据模型
- **开发指南**：后端、前端、测试、调试

### 2. 运维文档
- **Runbooks**：操作手册、故障排查、应急响应
- **监控文档**：日志、指标、告警
- **部署文档**：环境配置、发布流程

### 3. 产品文档
- **功能规格**：需求、设计、验收标准
- **用户指南**：使用说明、最佳实践
- **UX 文档**：设计系统、交互规范

### 4. 决策文档
- **ADR**：架构决策记录
- **RFC**：技术提案
- **路线图**：产品规划、技术演进

---

## 文档结构

### 目录组织

```
docs/
├── README.md                    # 文档总索引
├── CONTRIBUTING.md              # 本文件
├── templates/                   # 文档模板
├── getting-started/             # 快速开始
├── architecture/                # 架构文档
├── api/                         # API 文档
├── features/                    # 功能文档
├── development/                 # 开发指南
├── operations/                  # 运维文档
├── roadmaps/                    # 路线图
├── security/                    # 安全文档
├── product/                     # 产品文档
├── quality/                     # 质量文档
├── migration/                   # 迁移文档
└── legacy/                      # 历史文档
```

### 文件命名

- 使用小写字母和连字符：`my-document.md`
- 避免使用空格和特殊字符
- 使用描述性名称：`workspace-billing-guide.md` 而不是 `guide.md`
- README 文件用于目录索引

---

## 写作规范

### 1. 文档元数据

每个文档应包含 YAML front matter：

```yaml
---
title: 文档标题
status: draft | review | active | deprecated
created: 2026-05-19
updated: 2026-05-19
authors:
  - 张三
reviewers:
  - 李四
tags:
  - workspace
  - billing
related:
  - ../other-doc.md
---
```

### 2. 文档结构

#### 标题层级
- 使用 `#` 作为文档标题（H1）
- 使用 `##` 作为主要章节（H2）
- 使用 `###` 作为子章节（H3）
- 避免超过 4 级标题

#### 必需章节
根据文档类型，包含以下章节：

**技术文档**：
- 概述
- 前置条件
- 使用方法
- 示例
- 故障排查
- 参考资料

**Runbook**：
- 问题描述
- 前置条件
- 操作步骤
- 验证方法
- 回滚方案
- 常见问题

**ADR**：
- 状态
- 背景
- 决策
- 后果
- 备选方案

### 3. 写作风格

#### 语言
- 使用简洁、清晰的语言
- 避免行话和缩写（首次使用时解释）
- 使用主动语态
- 使用现在时态

#### 格式
- 使用列表组织信息
- 使用表格展示结构化数据
- 使用代码块展示代码和命令
- 使用引用块强调重要信息

#### 示例

✅ **好的写法**：
```markdown
## 安装步骤

1. 克隆仓库：
   ```bash
   git clone https://github.com/HBAI-Ltd/Openflow-app.git
   ```

2. 安装依赖：
   ```bash
   cd Openflow-app
   yarn install
   ```

3. 启动开发服务器：
   ```bash
   yarn dev
   ```
```

❌ **不好的写法**：
```markdown
## 安装

首先你需要克隆仓库，然后安装依赖，最后启动服务器。
```

### 4. 代码示例

#### Bash 命令
```bash
# 使用注释说明命令用途
cd backend
cargo run --bin openflow-server
```

#### 代码块
- 指定语言以启用语法高亮
- 添加注释说明关键部分
- 保持代码简洁，专注于要点

```rust
// 创建新项目
let project = Project::new(
    name: "My Project",
    workspace_id: workspace.id,
);
```

### 5. 链接

#### 内部链接
使用相对路径：
```markdown
详见 [API 文档](../api/rest-api.md)
```

#### 外部链接
包含描述性文本：
```markdown
参考 [PostgreSQL 全文搜索文档](https://www.postgresql.org/docs/current/textsearch.html)
```

### 6. 图片和图表

#### 图片
- 存放在 `docs/images/` 目录
- 使用描述性文件名
- 添加 alt 文本

```markdown
![架构图](../images/architecture-overview.png)
```

#### 图表
优先使用 Mermaid 图表：

```markdown
\`\`\`mermaid
graph LR
    A[用户] --> B[API Gateway]
    B --> C[Backend Service]
    C --> D[Database]
\`\`\`
```

---

## 提交流程

### 1. 创建分支

```bash
git checkout -b docs/add-workspace-guide
```

### 2. 编写文档

- 使用合适的模板
- 遵循写作规范
- 添加必要的元数据

### 3. 本地预览

```bash
# 使用 Markdown 预览工具
# 或在 IDE 中预览
```

### 4. 检查清单

- [ ] 文档包含 YAML front matter
- [ ] 标题层级正确
- [ ] 代码示例可运行
- [ ] 链接有效
- [ ] 拼写和语法正确
- [ ] 图片和图表清晰

### 5. 提交 PR

```bash
git add docs/
git commit -m "docs: add workspace billing guide"
git push origin docs/add-workspace-guide
```

PR 描述应包含：
- 文档的目的和范围
- 主要变更
- 相关 Issue 或 PR

### 6. 代码审查

- 至少一人审核
- 解决审核意见
- 更新文档

### 7. 合并

- 审核通过后合并
- 删除分支
- 更新相关索引

---

## 文档模板

使用以下模板创建新文档：

### ADR 模板
[templates/adr-template.md](./templates/adr-template.md)

### Runbook 模板
[templates/runbook-template.md](./templates/runbook-template.md)

### 技术规格模板
[templates/spec-template.md](./templates/spec-template.md)

### 路线图模板
[templates/roadmap-template.md](./templates/roadmap-template.md)

---

## 文档维护

### 定期审查

- **每月**：检查并更新文档状态
- **每季度**：审核并归档过时文档
- **每半年**：全面审计文档结构

### 更新文档

更新文档时：
1. 修改 `updated` 日期
2. 在文档底部添加变更日志（可选）
3. 更新相关链接

### 废弃文档

废弃文档时：
1. 将状态改为 `deprecated`
2. 添加废弃原因和替代文档链接
3. 移动到 `legacy/deprecated/` 目录

---

## 工具和资源

### Markdown 编辑器
- [VS Code](https://code.visualstudio.com/) + Markdown 插件
- [Typora](https://typora.io/)
- [Mark Text](https://marktext.app/)

### Markdown Linter
```bash
# 安装 markdownlint
npm install -g markdownlint-cli

# 检查文档
markdownlint docs/**/*.md
```

### 链接检查
```bash
# 安装 markdown-link-check
npm install -g markdown-link-check

# 检查链接
markdown-link-check docs/**/*.md
```

---

## 常见问题

### Q: 我应该在哪里添加新文档？

A: 根据文档类型选择合适的目录：
- API 文档 → `docs/api/`
- 功能文档 → `docs/features/`
- 运维手册 → `docs/operations/runbooks/`
- 架构决策 → `docs/architecture/adr/`

### Q: 如何处理敏感信息？

A: 不要在文档中包含：
- 密码、密钥、令牌
- 生产环境配置
- 个人身份信息

使用占位符代替：
```bash
export API_KEY="your-api-key-here"
```

### Q: 文档应该多详细？

A: 遵循"刚好够用"原则：
- 提供足够的信息让读者完成任务
- 避免过度详细导致难以维护
- 链接到相关文档而不是重复内容

### Q: 如何处理多语言文档？

A: 目前优先维护中文文档，英文文档可选：
- 核心文档提供英文版本
- 文件名添加语言后缀：`guide.en.md`
- 在主文档中链接到翻译版本

---

## 联系方式

如有问题或建议，请：
- 提交 Issue：https://github.com/HBAI-Ltd/Openflow-app/issues
- 发送邮件：ltlctools@outlook.com

---

**感谢你的贡献！** 🎉
