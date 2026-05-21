# Frontend 大文件重构优先级清单

## 超大文件（>800 行，需要拆分）

按行数排序（排除自动生成的 l10n 文件）：

| 文件 | 行数 | 超出比例 | 优先级 | 建议 |
|------|------|----------|--------|------|
| `short_video_space/section_production_assembly.dart` | 2594 | 3.2x | 🔴 高 | 拆分为多个 part 文件 |
| `content_compliance/section.dart` | 2531 | 3.2x | 🔴 高 | 拆分为多个 part 文件 |
| `team_workspaces/section.dart` | 2387 | 3.0x | 🔴 高 | 拆分为多个 part 文件 |
| `admin_console/section.dart` | 2008 | 2.5x | 🔴 高 | 拆分为多个 part 文件 |
| `short_video_space/view.dart` | 1986 | 2.5x | 🔴 高 | 拆分为多个 part 文件 |
| `notifications/section.dart` | 1896 | 2.4x | 🔴 高 | 拆分为多个 part 文件 |
| **`shell/help_hub_section.dart`** | **1620** | **2.0x** | 🔴 **高** | **你提到的交互问题在这里** |
| `product_shell/login_page.dart` | 1600 | 2.0x | 🟡 中 | 拆分登录流程 |
| `project_studio/project_studio_page.dart` | 1522 | 1.9x | 🟡 中 | 拆分 Studio 步骤 |
| `home_page.dart` | 1466 | 1.8x | 🟡 中 | 主文件，已有 part 拆分 |
| `global_search/search_results_page.dart` | 1449 | 1.8x | 🟡 中 | 拆分搜索结果类型 |
| `global_search/global_search_bar.dart` | 1425 | 1.8x | 🟡 中 | 拆分搜索逻辑 |
| `short_video_space/section.dart` | 1395 | 1.7x | 🟡 中 | 拆分短视频功能 |
| **`shell/build_sections_product.dart`** | **1387** | **1.7x** | 🟡 **中** | **你询问的文件** |
| `notifications/controller.dart` | 1350 | 1.7x | 🟡 中 | 拆分通知类型 |
| `rust_api/settings/notifications.dart` | 1286 | 1.6x | 🟡 中 | 自动生成？检查 |

## 拆分策略

### 立即行动（本周）

#### 1. `shell/help_hub_section.dart` (1620 行) - 🔴 最高优先级
**原因**：你提到的交互问题在这里，且体量最大

**拆分方案**：
```
shell/
├── help_hub_section.dart              # 主入口（~200 行）
├── help_hub_webhooks_ui.dart          # Webhook UI（~400 行）
├── help_hub_billing_ui.dart           # Billing UI（~300 行）
├── help_hub_support_ui.dart           # Support UI（~300 行）
├── help_hub_webhook_actions.dart      # 已存在
├── help_hub_billing_actions.dart      # 已存在
```

**预期收益**：
- 解决你提到的交互问题
- 减少 1400+ 行到 200 行
- 提升 webhook 交互的可维护性

#### 2. `shell/build_sections_product.dart` (1387 行) - 🟡 高优先级
**原因**：你询问的文件

**拆分方案**：（见前面的详细分析）
```
shell/
├── build_sections_product.dart          # 主入口（~150 行）
├── product_scope_management.dart        # 项目作用域（~200 行）
├── product_navigation.dart              # 导航（~150 行）
├── product_studio_overlay.dart          # Studio Overlay（~250 行）
├── product_studio_steps.dart            # Studio 步骤（~200 行）
├── product_workbench_launchers.dart     # Workbench 启动器（~150 行）
├── product_agent_workspace.dart         # Agent 工作区（~150 行）
├── product_panes_builder.dart           # 面板构建器（~300 行）
```

### 中期行动（本月）

#### 3. `short_video_space/section_production_assembly.dart` (2594 行)
**拆分方案**：
- 按生产流程阶段拆分（素材、剪辑、合成、导出）
- 每个阶段 ~500-600 行

#### 4. `content_compliance/section.dart` (2531 行)
**拆分方案**：
- 按合规类型拆分（内容审核、版权检查、敏感信息）
- 每个类型 ~600-800 行

#### 5. `team_workspaces/section.dart` (2387 行)
**拆分方案**：
- 按工作区功能拆分（成员管理、权限、设置、活动）
- 每个功能 ~500-600 行

### 长期行动（下季度）

#### 6-10. 其他 1000+ 行文件
- 按优先级逐个处理
- 每个文件拆分为 3-5 个 part 文件

## 拆分原则

### 1. Part 文件拆分（推荐，低风险）
- 适用于 extension 和 mixin
- 不改变运行时行为
- 编译器自动处理

### 2. 独立 Widget 提取（中风险）
- 适用于可复用的 UI 组件
- 需要处理状态传递
- 提升测试性

### 3. Controller 提取（高风险，高收益）
- 适用于复杂的业务逻辑
- 需要架构级别重构
- 建议在大版本迭代时进行

## 验证清单

每次拆分后必须验证：

- [ ] `yarn refactor:agent` 通过
- [ ] 相关功能手动测试通过
- [ ] 没有引入新的 lint 警告
- [ ] Git diff 确认只是文件移动，没有逻辑改动

## 技术债务跟踪

建议在项目管理工具中创建以下任务：

1. **P0 - 本周**：
   - [ ] 拆分 `help_hub_section.dart` (1620 行)
   - [ ] 拆分 `build_sections_product.dart` (1387 行)

2. **P1 - 本月**：
   - [ ] 拆分 `section_production_assembly.dart` (2594 行)
   - [ ] 拆分 `content_compliance/section.dart` (2531 行)
   - [ ] 拆分 `team_workspaces/section.dart` (2387 行)

3. **P2 - 下季度**：
   - [ ] 拆分其余 1000+ 行文件
   - [ ] 考虑提取独立 Controller

## 预期收益

完成 P0 和 P1 任务后：

- **减少代码行数**：~10,000 行 → ~2,000 行（主文件）
- **提升可维护性**：单文件 800 行以内
- **降低回归风险**：职责单一，易于测试
- **提升开发效率**：快速定位问题

## 风险控制

1. **小步快跑**：每次只拆分一个文件
2. **充分测试**：每次拆分后跑完整门禁
3. **代码审查**：确保拆分逻辑正确
4. **回滚准备**：保持 Git 历史清晰

---

**下一步行动**：
1. 确认优先级
2. 创建拆分任务
3. 逐个拆分并验证
4. 提交 PR 并跑完整门禁
