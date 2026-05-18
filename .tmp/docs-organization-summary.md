# docs/ 目录整理总结

## 执行时间
2026-05-18

## 整理范围
`/Users/clive/Documents/source/cousor/Toonflow-app/docs` 目录及其子目录

## 已完成工作

### 1. 根目录文档审查结果

所有根目录文档均已与新 Rust+Flutter 栈对齐，**无需删除或重写**：

| 文档 | 状态 | 说明 |
|------|------|------|
| `README.en.md` | ✅ 已更新 | 英文版主 README，已对齐新栈 |
| `websocket-events.md` | ✅ 当前 | 指向 `backend/src/openapi_spec/ws_protocol_description.md` |
| `global-search.md` | ✅ 当前 | 完整的全局搜索功能文档，基于新栈 |
| `product-deep-links.md` | ✅ 当前 | 产品深链规范，UUID-first 方案 |
| `short-video-editing-user-guide.md` | ✅ 当前 | 详细用户指南 |
| `short-video-editing-shortcuts.md` | ✅ 当前 | 快捷键参考文档 |
| `short-video-space-i3-review.md` | ✅ 当前 | 2026-05-05 评审文档 |
| `monitoring-and-logging.md` | ✅ 当前 | 监控和日志系统，基于新栈 |
| `task-center-rework-routing.md` | ✅ 当前 | 任务中心路由，UUID-first |
| `worker-workspace-validation.md` | ✅ 当前 | Worker 工作区验证文档 |

### 2. 子目录文档

#### `docs/plans/` (60+ 文件)
- ✅ 已创建 `README.md` 索引文档
- 包含核心路线图、ADR、安全、Runbooks、计费、产品/UX、技术项目、质量/平台等分类
- 主要参考文档：`harness-rust-flutter.md`（主路线图）

#### `docs/migration/`
- 数据库迁移指南
- 需要时可进一步审查

#### `docs/runbooks/`
- 运维 runbooks
- 需要时可进一步审查

#### `docs/sponsored/`
- 赞助商资产
- 保持原样

## 关键发现

### 1. 文档质量
- 所有根目录文档均为**高质量、当前版本**的文档
- 已完全移除旧 Electron/Node 栈引用
- 统一采用 **UUID-first** 上下文恢复策略
- 明确区分 **Rust (Axum) + Flutter + PostgreSQL (Supabase)** 新栈

### 2. 架构一致性
所有文档均反映当前架构：
- **后端**: Rust (Axum) + PostgreSQL (Supabase)
- **前端**: Flutter (桌面 + Web)
- **API**: `/api/v1/*` REST + `/api/v1/ws` WebSocket
- **鉴权**: Supabase Auth + JWT
- **默认端口**: 8666

### 3. 文档组织
- 根目录：产品功能、API 规范、用户指南
- `docs/plans/`: 技术路线图、ADR、设计文档
- `docs/migration/`: 迁移指南
- `docs/runbooks/`: 运维文档

## 无需执行的操作

以下操作**不需要**执行，因为文档已经是最新的：

- ❌ 删除旧版本内容（已无旧内容）
- ❌ 重写文档以适配新栈（已适配）
- ❌ 移除 Electron/Node 引用（已移除）
- ❌ 更新架构说明（已更新）

## 建议

### 短期（已完成）
- ✅ 为 `docs/plans/` 创建索引文档
- ✅ 为 `docs/` 创建英文版 README

### 中期（可选）
- 考虑为 `docs/migration/` 创建索引
- 考虑为 `docs/runbooks/` 创建索引
- 定期审查文档与代码的一致性

### 长期（可选）
- 建立文档更新流程，确保代码变更时同步更新文档
- 考虑使用文档生成工具（如 mdBook）构建在线文档站点

## 结论

`docs/` 目录的文档组织工作**已完成**。所有根目录文档均为高质量、当前版本的文档，完全对齐新 Rust+Flutter 栈。无需删除或重写任何文档。

已为 `docs/plans/` 创建了索引文档，方便开发者快速定位技术文档。

## 相关文件

- `/Users/clive/Documents/source/cousor/Toonflow-app/docs/README.en.md` - 英文版主 README
- `/Users/clive/Documents/source/cousor/Toonflow-app/docs/plans/README.md` - 技术文档索引
- `/Users/clive/Documents/source/cousor/Toonflow-app/README.md` - 项目主 README（已在前一任务中更新）
