# 创作者 UX 提交拆分建议

> 里程碑功能见 [`creator-ux-execution-task-list.md`](creator-ux-execution-task-list.md)。`flutter analyze` 已无 **error**；全仓约 80+ **warning** 为历史债，与本次竖切无新增 error。

## Commit 1 — `feat(creator-ux): 主链路与评审包`

**后端**

- `backend/src/projects/routes/handlers/detail/creator_journey.rs`（新）
- `backend/src/projects/routes/handlers/detail/home.rs`（starter 模板）
- `backend/src/projects/routes/handlers/detail/mod.rs`
- `backend/src/projects/routes/handlers/mod.rs`
- `backend/src/projects/routes/mod.rs`
- `backend/src/projects/openapi.rs`
- `backend/src/prompting/quality/validate.rs`
- `backend/src/prompting/quality/tests.rs`
- `backend/src/app/contract_smoke_tests/.../creator_journey_contract.rs`（新）
- `backend/src/app/contract_smoke_tests/.../general/mod.rs`

**前端**

- `frontend/lib/project_studio/creator_journey_*.dart`（新）
- `frontend/lib/project_studio/creator_starter_*.dart`（新）
- `frontend/lib/project_studio/studio_review_pack_*.dart`（新）
- `frontend/lib/project_studio/project_studio_page.dart`
- `frontend/lib/project_studio/project_studio_scope.dart`
- `frontend/lib/project_studio/project_studio_cockpit_panel.dart`
- `frontend/lib/project_studio/studio_merge_deliver_bar.dart`
- `frontend/lib/project_studio/studio_overlay_*.dart`
- `frontend/lib/product_shell/router.dart`
- `frontend/lib/shell/build_sections_product.dart`
- `frontend/lib/home_page.dart`（若仅含评审/路由相关 part 可整文件放此 commit）
- `frontend/lib/rust_api/project/creator_journey_api.dart`（新）
- `frontend/lib/rust_api/project/index.dart`
- `frontend/lib/l10n/app_*.arb` + 生成的 `app_localizations*.dart`
- `frontend/test/project_studio/*creator*`、`studio_review_pack_*`、`router_test.dart` 等

**文档**

- `docs/plans/creator-ux-execution-task-list.md`
- `docs/plans/creator-ux-commit-handoff.md`（本文件）

## Commit 2 — `fix(frontend): home_page part 与 analyze 零 error`

**范围**：`part of` 路径、`home_page` part 注册、part 文件非法 import、子库 `part of` 顺序、`ShortVideoErrorHandler` 类型、`bridge_api_test_fakes.dart`、`video_section.dart` 等结构性修复。

**排除**：无关 `backend/src/vendor/video/*` 纯格式化（可单独 `chore(fmt): vendor video` 或 `git checkout` 还原）。

## 提交前自检

```bash
cd frontend && flutter test test/project_studio/ test/product_shell/router_test.dart \
  test/rust_api/creator_journey_api_test.dart

cd backend && cargo test --lib creator_journey

flutter analyze   # 当前：0 error（约 80 warning 为历史债）

yarn refactor:agent --quick   # analyze 可能因 warning 非零退出码失败，但无 error
```

**已验证（2026-05-20）**：`test/project_studio/` 78/78 通过；后端 `creator_journey` 4/4 通过。

## 后续可选（新里程碑）

- T8 版本对比
- 运营侧 `GET creator-journey-summary` 可视化
- 收敛全仓 `flutter analyze` warning（DevEx 专项）
