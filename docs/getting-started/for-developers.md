---
title: 开发者快速开始
status: active
created: 2026-05-19
updated: 2026-05-19
tags:
  - getting-started
  - developers
---

# 开发者快速开始指南

欢迎加入 OpenFlow 开发团队！本指南将帮助你快速上手项目开发。

> **许可说明**：OpenFlow 为**闭源专有软件**（见仓库根目录 [LICENSE](../../LICENSE)）。本仓库仅供经授权成员使用，不得对外公开或分发源码。

## 📋 前置要求

### 必需工具

- **Rust** (>= 1.75)
- **Flutter** (>= 3.16)
- **Node.js** (>= 18)
- **PostgreSQL** (>= 14)
- **Git**

### 推荐工具

- **VS Code** 或 **Cursor** (推荐使用 Cursor)
- **Docker** (用于本地数据库)
- **Postman** 或 **Insomnia** (API 测试)

## 🚀 快速开始

### 1. 获取源码

由负责人授予 Git 权限后，从**授权远程**克隆：

```bash
git clone <your-authorized-remote-url>
cd Openflow-app
```

### 2. 设置后端

```bash
cd backend

# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，配置数据库连接等

# 安装依赖并构建
cargo build

# 运行测试
cargo test

# 启动开发服务器
cargo run
```

后端服务将在 `http://localhost:8080` 启动。

### 3. 设置前端

```bash
cd frontend

# 获取依赖
flutter pub get

# 运行代码生成
flutter pub run build_runner build

# 运行测试
flutter test

# 启动开发服务器
flutter run -d chrome
```

前端应用将在浏览器中打开。

### 4. 设置数据库

```bash
# 使用 Docker 启动本地 PostgreSQL
docker run -d \
  --name openflow-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=openflow \
  -p 5432:5432 \
  postgres:14

# 或者使用 Supabase 本地开发
# 参考 docs/migration/sqlite-to-supabase.md
```

## 📚 核心文档

### 架构与设计

- [主路线图](../roadmaps/master-roadmap.md) - 项目整体规划
- [架构决策记录](../architecture/adr/README.md) - 重要架构决策
- [技术栈](../roadmaps/master-roadmap.md#技术栈) - 使用的技术

### API 文档

- [REST API](../api/websocket-events.md) - HTTP API 文档
- [WebSocket 事件](../api/websocket-events.md) - 实时通信协议
- [OpenAPI 规格](../../backend/src/openapi_spec/) - API 规格定义

### 开发流程

- [Git 工作流](../../AGENTS.md#git_safety) - 分支和提交规范
- [代码审查](../quality/quality-rubric.md) - 代码质量标准
- [测试策略](../../AGENTS.md#重构栈门禁) - 测试要求

## 🏗️ 项目结构

```
Openflow-app/
├── backend/              # Rust 后端
│   ├── src/
│   │   ├── api/         # API 路由
│   │   ├── domain/      # 业务逻辑
│   │   ├── db/          # 数据库层
│   │   └── openapi_spec/ # OpenAPI 定义
│   └── tests/           # 后端测试
│
├── frontend/            # Flutter 前端
│   ├── lib/
│   │   ├── features/    # 功能模块
│   │   ├── shared/      # 共享组件
│   │   └── core/        # 核心功能
│   └── test/            # 前端测试
│
├── docs/                # 文档
│   ├── architecture/    # 架构文档
│   ├── api/            # API 文档
│   ├── features/       # 功能文档
│   └── operations/     # 运维文档
│
└── scripts/            # 工具脚本
```

## 💻 开发工作流

### 1. 创建功能分支

```bash
# 从 master 创建新分支
git checkout master
git pull origin master
git checkout -b feature/your-feature-name
```

### 2. 开发与测试

```bash
# 后端开发
cd backend
cargo watch -x run  # 自动重载

# 前端开发
cd frontend
flutter run -d chrome  # 热重载

# 运行测试
yarn refactor:agent  # 运行增量检查
```

### 3. 提交代码

```bash
# 暂存变更
git add .

# 提交（使用规范的提交信息）
git commit -m "feat: add user authentication

- Implement JWT token generation
- Add login/logout endpoints
- Add user session management

Ref: #123"

# 推送到远程
git push -u origin feature/your-feature-name
```

### 4. 创建 Pull Request

```bash
# 使用 GitHub CLI
gh pr create --title "feat: add user authentication" \
  --body "Description of changes..."

# 或在 GitHub 网页上创建 PR
```

## 🧪 测试

### 后端测试

```bash
cd backend

# 运行所有测试
cargo test

# 运行特定测试
cargo test test_name

# 运行测试并显示输出
cargo test -- --nocapture

# 代码覆盖率
cargo tarpaulin
```

### 前端测试

```bash
cd frontend

# 运行所有测试
flutter test

# 运行特定测试
flutter test test/path/to/test.dart

# 运行集成测试
flutter test integration_test/
```

### 门禁检查

```bash
# 开发过程中的增量检查
yarn refactor:agent

# 提交前的快速检查
yarn refactor:agent --quick

# 完整检查（提交前）
yarn refactor:agent --full
```

## 🐛 调试

### 后端调试

```bash
# 使用 rust-lldb
rust-lldb target/debug/openflow-backend

# 或使用 VS Code 调试配置
# 参考 .vscode/launch.json
```

### 前端调试

```bash
# 使用 Flutter DevTools
flutter pub global activate devtools
flutter pub global run devtools

# 或在 VS Code 中使用 F5 启动调试
```

### 日志查看

```bash
# 后端日志
RUST_LOG=debug cargo run

# 前端日志
flutter run --verbose
```

## 🔧 常用命令

### 后端

```bash
# 格式化代码
cargo fmt

# 代码检查
cargo clippy

# 更新依赖
cargo update

# 导出 OpenAPI 规格
cargo run --bin export-openapi
```

### 前端

```bash
# 格式化代码
flutter format .

# 代码分析
flutter analyze

# 更新依赖
flutter pub upgrade

# 代码生成
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📖 学习资源

### Rust

- [Rust 官方文档](https://doc.rust-lang.org/)
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/)
- [项目 Rust 编码规范](../../.cursor/rules/rust-coding-style.md)

### Flutter

- [Flutter 官方文档](https://flutter.dev/docs)
- [Dart 语言指南](https://dart.dev/guides)
- [项目 Flutter 编码规范](../../.cursor/rules/flutter-coding-style.md)

### 项目特定

- [后端开发指南](../../backend/README.md)
- [前端开发指南](../../frontend/README.md)
- [全栈交付约定](../quality/full-stack-delivery-covenant.md)

## 🤝 获取帮助

### 文档

- 查看 [文档总索引](../README.md)
- 搜索 [ADR](../architecture/adr/README.md) 了解架构决策
- 查看 [Runbooks](../operations/runbooks/README.md) 解决常见问题

### 团队沟通

- **Slack**: #dev-general 频道
- **GitHub Issues**: 报告 bug 或提出功能请求
- **GitHub Discussions**: 技术讨论
- **Code Review**: 在 PR 中提问

### 常见问题

**Q: 如何设置本地开发环境？**  
A: 参考本文档的"快速开始"部分。

**Q: 提交代码前需要做什么？**  
A: 运行 `yarn refactor:agent --full` 确保所有检查通过。

**Q: 如何查看 API 文档？**  
A: 启动后端服务后访问 `http://localhost:8080/swagger-ui`。

**Q: 遇到测试失败怎么办？**  
A: 查看错误信息，检查相关 [Runbook](../operations/runbooks/README.md)。

## 🎯 下一步

- [ ] 完成环境设置
- [ ] 阅读[主路线图](../roadmaps/master-roadmap.md)
- [ ] 浏览代码库，了解项目结构
- [ ] 选择一个 "good first issue" 开始贡献
- [ ] 加入团队 Slack 频道

---

**欢迎加入 OpenFlow！** 🚀

如有问题，随时在 Slack 或 GitHub 上联系团队。
