#!/usr/bin/env bash
# OpenFlow 文档重组脚本
# 用途：根据 docs/DOCUMENTATION_AUDIT_2026.md 的方案重组文档结构
# 使用：bash scripts/reorganize-docs.sh [--dry-run]

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="${PROJECT_ROOT}/docs"

# 是否为 dry-run 模式
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}🔍 Dry-run 模式：只显示将要执行的操作，不实际修改文件${NC}"
    echo ""
fi

# 日志函数
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 创建目录函数
create_dir() {
    local dir="$1"
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY-RUN] 创建目录: $dir"
    else
        mkdir -p "$dir"
        log_success "创建目录: $dir"
    fi
}

# 移动文件函数
move_file() {
    local src="$1"
    local dest="$2"
    
    if [[ ! -f "$src" ]]; then
        log_warning "源文件不存在: $src"
        return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY-RUN] 移动: $src -> $dest"
    else
        mkdir -p "$(dirname "$dest")"
        mv "$src" "$dest"
        log_success "移动: $(basename "$src") -> $dest"
    fi
}

# 创建文件函数
create_file() {
    local file="$1"
    local content="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [DRY-RUN] 创建文件: $file"
    else
        mkdir -p "$(dirname "$file")"
        echo "$content" > "$file"
        log_success "创建文件: $file"
    fi
}

echo "========================================="
echo "  OpenFlow 文档重组脚本"
echo "========================================="
echo ""

# ============================================
# 阶段 1：创建新的目录结构
# ============================================
log_info "阶段 1：创建新的目录结构"
echo ""

create_dir "${DOCS_DIR}/templates"
create_dir "${DOCS_DIR}/getting-started"
create_dir "${DOCS_DIR}/architecture/adr"
create_dir "${DOCS_DIR}/api"
create_dir "${DOCS_DIR}/features/workspace"
create_dir "${DOCS_DIR}/features/short-video"
create_dir "${DOCS_DIR}/features/harness"
create_dir "${DOCS_DIR}/development"
create_dir "${DOCS_DIR}/operations/runbooks"
create_dir "${DOCS_DIR}/roadmaps"
create_dir "${DOCS_DIR}/security/threat-models"
create_dir "${DOCS_DIR}/product/ux"
create_dir "${DOCS_DIR}/product/specs"
create_dir "${DOCS_DIR}/quality"
create_dir "${DOCS_DIR}/legacy/deprecated"

echo ""
log_success "阶段 1 完成：目录结构已创建"
echo ""

# ============================================
# 阶段 2：迁移文档（高优先级）
# ============================================
log_info "阶段 2：迁移文档（高优先级）"
echo ""

# 2.1 迁移 Runbooks
log_info "2.1 迁移 Runbooks"
move_file "${DOCS_DIR}/plans/jobs-pg-queue-runbook.md" "${DOCS_DIR}/operations/runbooks/jobs-pg-queue.md"
move_file "${DOCS_DIR}/plans/harness-wasm-alert-runbook.md" "${DOCS_DIR}/operations/runbooks/harness-wasm-alert.md"
move_file "${DOCS_DIR}/plans/workspace-operations-runbook.md" "${DOCS_DIR}/operations/runbooks/workspace-operations.md"
move_file "${DOCS_DIR}/plans/workspace-invite-runbook.md" "${DOCS_DIR}/operations/runbooks/workspace-invite.md"
move_file "${DOCS_DIR}/plans/workspace-rls-validation-runbook.md" "${DOCS_DIR}/operations/runbooks/workspace-rls-validation.md"
move_file "${DOCS_DIR}/plans/workspace-sensitive-operations-runbook.md" "${DOCS_DIR}/operations/runbooks/workspace-sensitive-operations.md"
move_file "${DOCS_DIR}/plans/billing-reconciliation-guide.md" "${DOCS_DIR}/operations/runbooks/billing-reconciliation.md"
move_file "${DOCS_DIR}/plans/billing-webhook-pii-runbook.md" "${DOCS_DIR}/operations/runbooks/billing-webhook-pii.md"
move_file "${DOCS_DIR}/plans/workspace-billing-cutover-runbook.md" "${DOCS_DIR}/operations/runbooks/workspace-billing-cutover.md"
move_file "${DOCS_DIR}/plans/workspace-billing-rollback-runbook.md" "${DOCS_DIR}/operations/runbooks/workspace-billing-rollback.md"
move_file "${DOCS_DIR}/runbooks/backfill-job-workspace-id.md" "${DOCS_DIR}/operations/runbooks/backfill-job-workspace-id.md"
move_file "${DOCS_DIR}/runbooks/export-s3-artifacts.md" "${DOCS_DIR}/operations/runbooks/export-s3-artifacts.md"
move_file "${DOCS_DIR}/runbooks/short-video-optimization-smoke.md" "${DOCS_DIR}/operations/runbooks/short-video-optimization-smoke.md"

echo ""

# 2.2 迁移 ADR
log_info "2.2 迁移 ADR"
move_file "${DOCS_DIR}/plans/adr-me-api-version-negotiation.md" "${DOCS_DIR}/architecture/adr/001-me-api-version-negotiation.md"
move_file "${DOCS_DIR}/plans/adr-workspace-billing-attribution.md" "${DOCS_DIR}/architecture/adr/002-workspace-billing-attribution.md"
move_file "${DOCS_DIR}/plans/adr-workspace-billing-storage-model.md" "${DOCS_DIR}/architecture/adr/003-workspace-billing-storage-model.md"
move_file "${DOCS_DIR}/plans/adr-rust-backend-cloudflare-worker.md" "${DOCS_DIR}/architecture/adr/004-rust-backend-cloudflare-worker.md"

echo ""

# 2.3 迁移根目录文档
log_info "2.3 迁移根目录文档"
move_file "${DOCS_DIR}/websocket-events.md" "${DOCS_DIR}/api/websocket-events.md"
move_file "${DOCS_DIR}/global-search.md" "${DOCS_DIR}/features/global-search.md"
move_file "${DOCS_DIR}/monitoring-and-logging.md" "${DOCS_DIR}/operations/monitoring-and-logging.md"
move_file "${DOCS_DIR}/product-deep-links.md" "${DOCS_DIR}/product/deep-links.md"
move_file "${DOCS_DIR}/short-video-editing-shortcuts.md" "${DOCS_DIR}/features/short-video/shortcuts.md"
move_file "${DOCS_DIR}/short-video-editing-user-guide.md" "${DOCS_DIR}/features/short-video/user-guide.md"

echo ""

# 2.4 迁移 Workspace 文档
log_info "2.4 迁移 Workspace 文档"
move_file "${DOCS_DIR}/plans/workspace-team-full-plan.md" "${DOCS_DIR}/features/workspace/team-collaboration.md"
move_file "${DOCS_DIR}/plans/workspace-billing-scope-decision.md" "${DOCS_DIR}/features/workspace/billing-scope.md"
move_file "${DOCS_DIR}/plans/workspace-billing-feature-flag-guide.md" "${DOCS_DIR}/features/workspace/billing-feature-flags.md"
move_file "${DOCS_DIR}/plans/workspace-project-permission-policy.md" "${DOCS_DIR}/features/workspace/permissions.md"
move_file "${DOCS_DIR}/plans/workspace-observability-spec.md" "${DOCS_DIR}/features/workspace/observability.md"

echo ""

# 2.5 迁移安全文档
log_info "2.5 迁移安全文档"
move_file "${DOCS_DIR}/plans/harness-user-wasm-threat-model.md" "${DOCS_DIR}/security/threat-models/harness-user-wasm.md"
move_file "${DOCS_DIR}/plans/workspace-security-boundary.md" "${DOCS_DIR}/security/threat-models/workspace-security-boundary.md"
move_file "${DOCS_DIR}/plans/workspace-invite-security-review.md" "${DOCS_DIR}/security/workspace-invite-security-review.md"

echo ""

# 2.6 迁移路线图
log_info "2.6 迁移路线图"
move_file "${DOCS_DIR}/plans/harness-rust-flutter.md" "${DOCS_DIR}/roadmaps/master-roadmap.md"
move_file "${DOCS_DIR}/plans/electron-node-parity.md" "${DOCS_DIR}/roadmaps/parity-audit.md"
move_file "${DOCS_DIR}/plans/master-detailed-parity-audit.md" "${DOCS_DIR}/roadmaps/detailed-parity-audit.md"
move_file "${DOCS_DIR}/plans/roadmap-backend-harness.md" "${DOCS_DIR}/roadmaps/backend-harness.md"
move_file "${DOCS_DIR}/plans/roadmap-flutter-shell.md" "${DOCS_DIR}/roadmaps/flutter-shell.md"
move_file "${DOCS_DIR}/plans/roadmap-jobs-saas.md" "${DOCS_DIR}/roadmaps/jobs-saas.md"
move_file "${DOCS_DIR}/plans/roadmap-workspace.md" "${DOCS_DIR}/roadmaps/workspace.md"
move_file "${DOCS_DIR}/plans/roadmap-quality.md" "${DOCS_DIR}/roadmaps/quality.md"
move_file "${DOCS_DIR}/plans/openflow-platform-progress.md" "${DOCS_DIR}/roadmaps/platform-progress.md"

echo ""

# 2.7 迁移产品文档
log_info "2.7 迁移产品文档"
move_file "${DOCS_DIR}/plans/studio-competitive-ui-benchmark.md" "${DOCS_DIR}/product/ux/competitive-ui-benchmark.md"
move_file "${DOCS_DIR}/plans/studio-design-tokens.md" "${DOCS_DIR}/product/ux/design-tokens.md"
move_file "${DOCS_DIR}/plans/studio-ix-covenant.md" "${DOCS_DIR}/product/ux/ix-covenant.md"
move_file "${DOCS_DIR}/plans/short-video-light-editing-spec.md" "${DOCS_DIR}/features/short-video/light-editing-spec.md"
move_file "${DOCS_DIR}/plans/ai-drama-quality-token-memory-spec.md" "${DOCS_DIR}/product/specs/ai-drama-quality-token-memory.md"
move_file "${DOCS_DIR}/plans/model-pricing-prd.md" "${DOCS_DIR}/product/specs/model-pricing-prd.md"
move_file "${DOCS_DIR}/plans/novel-intake-crawler-plan.md" "${DOCS_DIR}/product/specs/novel-intake-crawler.md"

echo ""

log_success "阶段 2 完成：高优先级文档已迁移"
echo ""

# ============================================
# 阶段 3：创建索引文件
# ============================================
log_info "阶段 3：创建索引文件"
echo ""

# 3.1 创建主 README
create_file "${DOCS_DIR}/README.md" "# OpenFlow 文档中心

欢迎来到 OpenFlow 文档中心！本文档库提供了完整的技术文档、API 参考、运维指南和产品规格。

## 📚 文档导航

### 🚀 快速开始
- [开发者快速开始](./getting-started/for-developers.md)
- [运维人员快速开始](./getting-started/for-operators.md)
- [产品经理快速开始](./getting-started/for-product-managers.md)

### 🏗️ 架构文档
- [架构概览](./architecture/overview.md)
- [技术栈](./architecture/tech-stack.md)
- [架构决策记录（ADR）](./architecture/adr/README.md)

### 🔌 API 文档
- [REST API](./api/rest-api.md)
- [WebSocket 事件](./api/websocket-events.md)
- [Webhooks](./api/webhooks.md)

### ✨ 功能文档
- [全局搜索](./features/global-search.md)
- [Workspace 协作](./features/workspace/README.md)
- [短视频编辑](./features/short-video/README.md)
- [Harness 工具](./features/harness/README.md)

### 💻 开发指南
- [后端开发](./development/backend-guide.md)
- [前端开发](./development/frontend-guide.md)
- [测试指南](./development/testing.md)

### 🔧 运维文档
- [运维手册（Runbooks）](./operations/runbooks/README.md)
- [监控与日志](./operations/monitoring-and-logging.md)
- [故障排查](./operations/troubleshooting.md)

### 🗺️ 路线图
- [主路线图](./roadmaps/master-roadmap.md)
- [功能对齐审计](./roadmaps/parity-audit.md)
- [平台进度](./roadmaps/platform-progress.md)

### 🔒 安全文档
- [威胁模型](./security/threat-models/)
- [安全最佳实践](./security/best-practices.md)

### 📱 产品文档
- [产品规格](./product/specs/)
- [UX 设计](./product/ux/)
- [深链接](./product/deep-links.md)

### 🔄 迁移文档
- [数据库迁移](./migration/database-migrations.md)
- [SQLite 到 Supabase](./migration/sqlite-to-supabase.md)

## 📝 贡献指南

请参阅 [CONTRIBUTING.md](./CONTRIBUTING.md) 了解如何贡献文档。

## 🔍 文档审计

最新的文档审计报告：[DOCUMENTATION_AUDIT_2026.md](./DOCUMENTATION_AUDIT_2026.md)

## 📧 联系方式

如有问题或建议，请联系：ltlctools@outlook.com
"

# 3.2 创建 Runbooks 索引
create_file "${DOCS_DIR}/operations/runbooks/README.md" "# 运维手册（Runbooks）

本目录包含 OpenFlow 平台的运维操作手册。

## 📋 手册列表

### 任务队列
- [PostgreSQL 任务队列运维](./jobs-pg-queue.md)

### Harness 系统
- [Harness WASM 告警排障](./harness-wasm-alert.md)

### Workspace 运维
- [Workspace 运维操作](./workspace-operations.md)
- [Workspace 邀请运维](./workspace-invite.md)
- [Workspace RLS 验证](./workspace-rls-validation.md)
- [Workspace 敏感操作](./workspace-sensitive-operations.md)

### 计费系统
- [计费对账指南](./billing-reconciliation.md)
- [计费 Webhook PII 处理](./billing-webhook-pii.md)
- [Workspace 计费切换](./workspace-billing-cutover.md)
- [Workspace 计费回滚](./workspace-billing-rollback.md)

### 数据维护
- [Job Workspace ID 回填](./backfill-job-workspace-id.md)
- [S3 制品导出](./export-s3-artifacts.md)

### 性能优化
- [短视频优化烟测](./short-video-optimization-smoke.md)

## 📖 使用指南

每个 Runbook 包含：
- **问题描述**：什么情况下使用此手册
- **前置条件**：需要的权限和工具
- **操作步骤**：详细的执行步骤
- **验证方法**：如何确认操作成功
- **回滚方案**：出错时如何恢复
- **常见问题**：FAQ 和故障排查
"

# 3.3 创建 ADR 索引
create_file "${DOCS_DIR}/architecture/adr/README.md" "# 架构决策记录（ADR）

本目录包含 OpenFlow 项目的架构决策记录（Architecture Decision Records）。

## 什么是 ADR？

ADR 是记录重要架构决策的文档，包括：
- 决策的背景和上下文
- 考虑的备选方案
- 最终决策及其理由
- 决策的后果和影响

## 📋 决策列表

| 编号 | 标题 | 状态 | 日期 |
|------|------|------|------|
| 001 | [/api/v1/me API 版本协商](./001-me-api-version-negotiation.md) | ✅ 已采纳 | 2025-Q4 |
| 002 | [Workspace 计费归属决策](./002-workspace-billing-attribution.md) | ✅ 已采纳 | 2025-Q4 |
| 003 | [Workspace 计费存储模型](./003-workspace-billing-storage-model.md) | ✅ 已采纳 | 2025-Q4 |
| 004 | [Rust 后端 Cloudflare Worker](./004-rust-backend-cloudflare-worker.md) | 🚧 评估中 | 2026-Q1 |

## 📝 ADR 模板

创建新的 ADR 时，请使用 [ADR 模板](../../templates/adr-template.md)。

## 🔄 ADR 状态

- 🚧 **草稿**：正在编写中
- 👀 **评审中**：等待团队审核
- ✅ **已采纳**：决策已被采纳并实施
- ⚠️ **已废弃**：决策已被新的 ADR 替代
- ❌ **已拒绝**：决策未被采纳
"

echo ""
log_success "阶段 3 完成：索引文件已创建"
echo ""

# ============================================
# 完成
# ============================================
echo ""
echo "========================================="
log_success "文档重组完成！"
echo "========================================="
echo ""

if [[ "$DRY_RUN" == true ]]; then
    log_warning "这是 dry-run 模式，没有实际修改文件"
    echo ""
    log_info "要执行实际操作，请运行："
    echo "  bash scripts/reorganize-docs.sh"
else
    log_info "下一步："
    echo "  1. 检查移动后的文档"
    echo "  2. 更新文档间的引用链接"
    echo "  3. 为文档添加 YAML front matter"
    echo "  4. 运行 'yarn refactor:agent' 验证"
fi

echo ""
