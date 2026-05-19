#!/usr/bin/env bash
# OpenFlow 文档重组脚本 - 第二阶段
# 用途：处理 docs/plans/ 中剩余的 29 个文档
# 使用：bash scripts/reorganize-docs-phase2.sh [--dry-run]

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

echo "========================================="
echo "  OpenFlow 文档重组脚本 - 第二阶段"
echo "========================================="
echo ""

# ============================================
# 阶段 1：迁移技术专项文档
# ============================================
log_info "阶段 1：迁移技术专项文档"
echo ""

# 1.1 HTTP API 清理相关
log_info "1.1 迁移 HTTP API 清理文档"
move_file "${DOCS_DIR}/plans/http-api-cleanup.md" "${DOCS_DIR}/roadmaps/http-api-cleanup.md"
move_file "${DOCS_DIR}/plans/http-api-cleanup-h0-inventory.md" "${DOCS_DIR}/roadmaps/http-api-cleanup-inventory.md"
move_file "${DOCS_DIR}/plans/tasks-http-api-cleanup.md" "${DOCS_DIR}/roadmaps/tasks-http-api-cleanup.md"

echo ""

# 1.2 任务队列相关
log_info "1.2 迁移任务队列文档"
move_file "${DOCS_DIR}/plans/tasks-pg-queue-observability.md" "${DOCS_DIR}/roadmaps/tasks-pg-queue-observability.md"

echo ""

# 1.3 后端架构相关
log_info "1.3 迁移后端架构文档"
move_file "${DOCS_DIR}/plans/backend-domain-layer-review.md" "${DOCS_DIR}/architecture/backend-domain-layer-review.md"
move_file "${DOCS_DIR}/plans/ddd-full-migration-c.md" "${DOCS_DIR}/architecture/ddd-full-migration-c.md"

echo ""

# 1.4 数据库相关
log_info "1.4 迁移数据库文档"
move_file "${DOCS_DIR}/plans/database-migration-history-policy.md" "${DOCS_DIR}/migration/database-migration-history-policy.md"

echo ""

# 1.5 资产生成相关
log_info "1.5 迁移资产生成文档"
move_file "${DOCS_DIR}/plans/assets-generate-job-payload-v2.md" "${DOCS_DIR}/product/specs/assets-generate-job-payload-v2.md"

echo ""

# ============================================
# 阶段 2：迁移 Workspace 计费文档
# ============================================
log_info "阶段 2：迁移 Workspace 计费文档"
echo ""

move_file "${DOCS_DIR}/plans/workspace-billing-future-workspace-scope.md" "${DOCS_DIR}/features/workspace/billing-future-scope.md"
move_file "${DOCS_DIR}/plans/workspace-billing-job-creation-audit.md" "${DOCS_DIR}/features/workspace/billing-job-creation-audit.md"
move_file "${DOCS_DIR}/plans/workspace-billing-migration-notice.md" "${DOCS_DIR}/features/workspace/billing-migration-notice.md"
move_file "${DOCS_DIR}/plans/workspace-billing-rollback-procedures.md" "${DOCS_DIR}/features/workspace/billing-rollback-procedures.md"
move_file "${DOCS_DIR}/plans/workspace-billing-schema-rollback.md" "${DOCS_DIR}/features/workspace/billing-schema-rollback.md"
move_file "${DOCS_DIR}/plans/workspace-billing-staging-validation-checklist.md" "${DOCS_DIR}/features/workspace/billing-staging-validation.md"

echo ""

# ============================================
# 阶段 3：迁移 Workspace 其他文档
# ============================================
log_info "阶段 3：迁移 Workspace 其他文档"
echo ""

move_file "${DOCS_DIR}/plans/workspace-migration-notice.md" "${DOCS_DIR}/features/workspace/migration-notice.md"
move_file "${DOCS_DIR}/plans/workspace-release-checklist.md" "${DOCS_DIR}/features/workspace/release-checklist.md"
move_file "${DOCS_DIR}/plans/workspace-rls-consistency-matrix.md" "${DOCS_DIR}/features/workspace/rls-consistency-matrix.md"
move_file "${DOCS_DIR}/plans/harness-ws-context-matrix.md" "${DOCS_DIR}/features/harness/ws-context-matrix.md"

echo ""

# ============================================
# 阶段 4：迁移计费系统文档
# ============================================
log_info "阶段 4：迁移计费系统文档"
echo ""

move_file "${DOCS_DIR}/plans/billing-webhook-retention-policy.md" "${DOCS_DIR}/operations/billing-webhook-retention-policy.md"

echo ""

# ============================================
# 阶段 5：迁移平台与质量文档
# ============================================
log_info "阶段 5：迁移平台与质量文档"
echo ""

# 5.1 质量文档
log_info "5.1 迁移质量文档"
move_file "${DOCS_DIR}/plans/quality-rubric.md" "${DOCS_DIR}/quality/quality-rubric.md"
move_file "${DOCS_DIR}/plans/full-stack-delivery-covenant.md" "${DOCS_DIR}/quality/full-stack-delivery-covenant.md"

echo ""

# 5.2 平台文档
log_info "5.2 迁移平台文档"
move_file "${DOCS_DIR}/plans/platform-capabilities-backlog.md" "${DOCS_DIR}/roadmaps/platform-capabilities-backlog.md"
move_file "${DOCS_DIR}/plans/platform-config-plan-overrides.md" "${DOCS_DIR}/roadmaps/platform-config-plan-overrides.md"

echo ""

# ============================================
# 阶段 6：迁移产品与 UI 文档
# ============================================
log_info "阶段 6：迁移产品与 UI 文档"
echo ""

move_file "${DOCS_DIR}/plans/moneyprinter-short-video-space.md" "${DOCS_DIR}/product/specs/moneyprinter-short-video-space.md"
move_file "${DOCS_DIR}/plans/ui-review-2026-05-18.md" "${DOCS_DIR}/product/ux/ui-review-2026-05-18.md"
move_file "${DOCS_DIR}/plans/ui-surface-inventory.md" "${DOCS_DIR}/product/ux/ui-surface-inventory.md"

echo ""

# ============================================
# 阶段 7：迁移路线图索引文档
# ============================================
log_info "阶段 7：迁移路线图索引文档"
echo ""

move_file "${DOCS_DIR}/plans/roadmap-index.md" "${DOCS_DIR}/roadmaps/index.md"
move_file "${DOCS_DIR}/plans/roadmap-parity-shipping.md" "${DOCS_DIR}/roadmaps/parity-shipping.md"
move_file "${DOCS_DIR}/plans/roadmap-repo-contract-infra.md" "${DOCS_DIR}/roadmaps/repo-contract-infra.md"

echo ""

# ============================================
# 阶段 8：处理 plans/README.md
# ============================================
log_info "阶段 8：处理 plans/README.md"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY-RUN] 将 plans/README.md 移动到 legacy/"
else
    if [[ -f "${DOCS_DIR}/plans/README.md" ]]; then
        mv "${DOCS_DIR}/plans/README.md" "${DOCS_DIR}/legacy/plans-readme-archive.md"
        log_success "归档: plans/README.md -> legacy/plans-readme-archive.md"
    fi
fi

echo ""

# ============================================
# 阶段 9：删除空的 plans 和 runbooks 目录
# ============================================
log_info "阶段 9：清理空目录"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "  [DRY-RUN] 检查并删除空目录"
else
    # 检查 plans 目录是否为空
    if [[ -d "${DOCS_DIR}/plans" ]] && [[ -z "$(ls -A ${DOCS_DIR}/plans)" ]]; then
        rmdir "${DOCS_DIR}/plans"
        log_success "删除空目录: docs/plans/"
    else
        log_warning "docs/plans/ 目录不为空，保留"
    fi
    
    # 检查 runbooks 目录是否为空
    if [[ -d "${DOCS_DIR}/runbooks" ]] && [[ -z "$(ls -A ${DOCS_DIR}/runbooks)" ]]; then
        rmdir "${DOCS_DIR}/runbooks"
        log_success "删除空目录: docs/runbooks/"
    else
        log_warning "docs/runbooks/ 目录不为空，保留"
    fi
fi

echo ""

# ============================================
# 完成
# ============================================
echo ""
echo "========================================="
log_success "文档重组第二阶段完成！"
echo "========================================="
echo ""

if [[ "$DRY_RUN" == true ]]; then
    log_warning "这是 dry-run 模式，没有实际修改文件"
    echo ""
    log_info "要执行实际操作，请运行："
    echo "  bash scripts/reorganize-docs-phase2.sh"
else
    log_info "已处理的文档："
    echo "  - 技术专项：9 个"
    echo "  - Workspace 计费：6 个"
    echo "  - Workspace 其他：4 个"
    echo "  - 计费系统：1 个"
    echo "  - 平台与质量：4 个"
    echo "  - 产品与 UI：3 个"
    echo "  - 路线图索引：3 个"
    echo "  总计：30 个文档"
    echo ""
    log_info "下一步："
    echo "  1. 检查移动后的文档"
    echo "  2. 更新文档间的引用链接"
    echo "  3. 提交变更到 Git"
fi

echo ""
