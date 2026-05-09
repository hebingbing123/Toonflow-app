#!/bin/bash

# 快速验证脚本 - 只检查文件存在性，不运行测试

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=========================================="
echo "快速验证 - 短视频轻量剪辑工作台增强功能"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0

check_pass() {
    TOTAL=$((TOTAL + 1))
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    TOTAL=$((TOTAL + 1))
    FAILED=$((FAILED + 1))
    echo -e "${RED}✗${NC} $1"
}

# 前端组件
echo "━━━ 前端组件 ━━━"
COMPONENTS=(
    "frontend/lib/short_video_space/components/preview_player.dart"
    "frontend/lib/short_video_space/components/batch_operation_toolbar.dart"
    "frontend/lib/short_video_space/components/filter_panel.dart"
    "frontend/lib/short_video_space/components/version_manager.dart"
)

for file in "${COMPONENTS[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        check_pass "$(basename $file)"
    else
        check_fail "$(basename $file)"
    fi
done

# 对话框
echo ""
echo "━━━ 对话框 ━━━"
DIALOGS=(
    "frontend/lib/short_video_space/dialogs/voiceover_settings_dialog.dart"
    "frontend/lib/short_video_space/dialogs/export_settings_dialog.dart"
    "frontend/lib/short_video_space/dialogs/export_progress_dialog.dart"
    "frontend/lib/short_video_space/dialogs/export_history_dialog.dart"
)

for file in "${DIALOGS[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        check_pass "$(basename $file)"
    else
        check_fail "$(basename $file)"
    fi
done

# 状态管理
echo ""
echo "━━━ 状态管理 ━━━"
if [ -f "$PROJECT_ROOT/frontend/lib/short_video_space/state/operation_history.dart" ]; then
    check_pass "operation_history.dart"
else
    check_fail "operation_history.dart"
fi

# 快捷键
echo ""
echo "━━━ 快捷键支持 ━━━"
if [ -f "$PROJECT_ROOT/frontend/lib/short_video_space/section_keyboard_shortcuts.dart" ]; then
    check_pass "section_keyboard_shortcuts.dart"
else
    check_fail "section_keyboard_shortcuts.dart"
fi

# 测试文件
echo ""
echo "━━━ 测试文件 ━━━"
TESTS=(
    "frontend/test/preview_player_test.dart"
    "frontend/test/batch_operation_toolbar_test.dart"
    "frontend/test/filter_panel_test.dart"
    "frontend/test/version_manager_test.dart"
    "frontend/test/tts_functionality_test.dart"
    "frontend/test/export_settings_dialog_test.dart"
    "frontend/test/export_progress_dialog_test.dart"
    "frontend/test/export_history_dialog_test.dart"
)

for file in "${TESTS[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        check_pass "$(basename $file)"
    else
        check_fail "$(basename $file)"
    fi
done

# 文档
echo ""
echo "━━━ 文档 ━━━"
DOCS=(
    "docs/short-video-editing-user-guide.md"
    "docs/short-video-editing-shortcuts.md"
    "backend/src/openapi_spec/short_video_editing_api.md"
    ".kiro/specs/short-video-editing-enhancements/IMPLEMENTATION_SUMMARY.md"
    ".kiro/specs/short-video-editing-enhancements/ACTUAL_STATUS.md"
)

for file in "${DOCS[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        check_pass "$(basename $file)"
    else
        check_fail "$(basename $file)"
    fi
done

# 后端状态（预期未完成）
echo ""
echo "━━━ 后端实现状态 ━━━"
echo -e "${YELLOW}注意：后端功能尚未实现，这是预期的${NC}"
echo ""
echo "需要实现的后端组件："
echo "  - 数据库迁移文件（2 个）"
echo "  - 数据模型（export_task.rs + voiceover.rs 扩展）"
echo "  - TTS 服务（tts_service.rs）"
echo "  - 导出服务（export_service.rs）"
echo "  - API 路由（tts_routes.rs + export_routes.rs + workbench.rs 扩展）"
echo "  - 后端测试（单元测试 + 集成测试）"

# 结果汇总
echo ""
echo "=========================================="
echo "验证结果"
echo "=========================================="
echo ""
echo "总检查项: $TOTAL"
echo -e "${GREEN}通过: $PASSED${NC}"
echo -e "${RED}失败: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ 前端实现完成！${NC}"
    echo ""
    echo "下一步："
    echo "1. 查看 ACTUAL_STATUS.md 了解详细状态"
    echo "2. 按照优先级实现后端功能"
    echo "3. 运行完整测试验证"
    exit 0
else
    echo -e "${RED}✗ 有 $FAILED 项检查失败${NC}"
    exit 1
fi
