# build_sections_product.dart 拆分分析报告

## 文件现状

- **文件路径**: `frontend/lib/shell/build_sections_product.dart`
- **当前行数**: 1387 行
- **文件性质**: `part of '../../home_page.dart'` (extension on `_HomePageState`)
- **主要职责**: Product Shell 相关的 UI 构建和交互逻辑

## 问题诊断

### 1. 体量问题（高优先级）
- **1387 行**已接近 **建议上限 800 行的 1.7 倍**
- 单文件包含了太多不同层次的职责
- 后续任何小改动都容易引入回归

### 2. 职责混杂（核心问题）
通过方法签名分析，该文件混合了以下职责：

#### A. 项目作用域管理（Project Scope）
- `_refreshRecentProjectIds()`
- `_applyDefaultProductProjectScopeIfNeeded()`
- `_selectProjectScope(ProjectRow)`
- `_studioProjectRow()`
- `_studioProjectRowForNumericId(int)`
- `_buildReadonlyProjectScopeRow(...)`

#### B. 深度链接与导航（Deep Link & Navigation）
- `_applyDomainDeepLink(TaskCenterDomainDeepLink)`
- `_openProjectStudio(ProjectRow)`
- `_openShellPaneFromStudioOverlay(...)`
- `_deliverTabIndexFromRoute(BuildContext, {int fallback})`

#### C. Studio Overlay 构建（Studio Overlay）
- `_buildStudioOverlayWidgets(BuildContext)` - 221 行开始，非常长
- `_runStudioAgent(String)`

#### D. Project Studio 步骤构建（Step Body Builders）
- `_buildProjectStudioScriptStepBody(BuildContext, int)`
- `_buildProjectStudioStepBody(BuildContext, AppLocalizations, StudioStep, int)`
- `_buildProjectStudioDeliverStepBody(...)`

#### E. Workbench 对话框启动器（Workbench Launchers）
- `_studioScriptOpenNovelWorkbench(...)`
- `_studioScriptOpenScriptsWorkbench(...)`

#### F. 短视频空间（Short Video Space）
- `_buildShortVideoSpaceSection({ShortVideoSpaceEmbedScope})`

#### G. 合规目标打开（Compliance）
- `_openComplianceProductTarget(ContentComplianceReportItemV1)`

#### H. Agent 工作区（Agent Workspace）
- `_buildAgentWorkspacePane({...})` - 参数非常多

#### I. 产品面板构建（Product Panes）
- `_buildFeatureGatedPane({...})`
- `_buildProductPaneSelector(BuildContext)`
- `_buildProductScriptOrProductionPane(...)`
- `_buildProductHarnessRedirectHint(...)`

#### J. 主入口（Main Builders）
- `_buildProductSections(BuildContext)`
- `_buildActiveProductPaneWidgets(BuildContext)` - 非常长，包含大量 if 分支

### 3. 交互问题（你提到的 4066-4073 行）
```dart
OutboundWebhookEventChips(
  ...
  enabled: !_loadingWebhooks && _webhookBusyId == null,
  onSelectionChanged: (next) {
    unawaited(_patchWebhookEventSubscription(wh, next));
  },
),
```
- 这段代码涉及 webhook 交互，但在 1387 行的文件中找不到（可能在其他 part 文件）
- 说明交互逻辑分散在多个巨型文件中，难以追踪

## 拆分建议

### 方案 A：按职责域拆分（推荐）

将 `build_sections_product.dart` 拆分为以下 part 文件：

```
shell/
├── build_sections_product.dart          # 保留主入口（~150 行）
├── product_scope_management.dart        # 项目作用域管理（~200 行）
├── product_navigation.dart              # 深度链接与导航（~150 行）
├── product_studio_overlay.dart          # Studio Overlay 构建（~250 行）
├── product_studio_steps.dart            # Studio 步骤构建（~200 行）
├── product_workbench_launchers.dart     # Workbench 启动器（~150 行）
├── product_agent_workspace.dart         # Agent 工作区构建（~150 行）
├── product_panes_builder.dart           # 产品面板构建器（~300 行）
```

#### 拆分后的 `build_sections_product.dart` 结构：
```dart
part of '../../home_page.dart';

extension _HomePageBuildProductSections on _HomePageState {
  // 主入口方法
  List<Widget> _buildProductSections(BuildContext context) {
    return <Widget>[
      _buildProductPaneSelector(context),
      ..._buildActiveProductPaneWidgets(context),
    ];
  }

  List<Widget> _buildActiveProductPaneWidgets(BuildContext context) {
    // 委托给各个子模块
    // ...
  }
}
```

### 方案 B：按功能模块拆分（更激进）

如果要更彻底地解决问题，可以考虑：

1. **提取独立的 Controller**
   - `ProductScopeController` - 管理项目作用域
   - `ProductNavigationController` - 管理导航和深度链接
   - `ProductStudioController` - 管理 Studio 状态

2. **提取独立的 Builder Widget**
   - `ProductStudioOverlayBuilder` - 独立的 StatefulWidget
   - `ProductPanesBuilder` - 独立的 StatefulWidget
   - `AgentWorkspaceBuilder` - 独立的 StatefulWidget

3. **好处**：
   - 更好的测试性
   - 更清晰的状态管理
   - 减少 `_HomePageState` 的负担

4. **代价**：
   - 需要重构状态传递
   - 可能需要引入 Provider/Riverpod 等状态管理
   - 改动范围更大

## 拆分优先级

### 立即可做（低风险）
1. **拆分 `product_scope_management.dart`**
   - 包含所有 `_*ProjectScope*` 方法
   - 职责单一，依赖少
   - 风险低

2. **拆分 `product_navigation.dart`**
   - 包含所有 `_*DeepLink*` 和 `_open*` 方法
   - 相对独立

### 中期可做（中风险）
3. **拆分 `product_studio_overlay.dart` 和 `product_studio_steps.dart`**
   - 包含 Studio 相关的构建逻辑
   - 需要仔细处理依赖

4. **拆分 `product_panes_builder.dart`**
   - 包含 `_buildActiveProductPaneWidgets` 的大量 if 分支
   - 可以考虑用 Map<ProductWorkspacePane, Widget Function()> 重构

### 长期可做（高风险，高收益）
5. **提取独立 Controller 和 Widget**
   - 需要架构级别的重构
   - 建议在下一个大版本迭代时进行

## 具体拆分步骤（方案 A）

### Step 1: 拆分 `product_scope_management.dart`

```dart
// shell/product_scope_management.dart
part of '../../home_page.dart';

extension _HomePageProductScopeManagement on _HomePageState {
  Future<void> _refreshRecentProjectIds() async { ... }
  Future<void> _applyDefaultProductProjectScopeIfNeeded() async { ... }
  Future<void> _selectProjectScope(ProjectRow row) async { ... }
  ProjectRow? _studioProjectRow() { ... }
  ProjectRow? _studioProjectRowForNumericId(int projectNumericId) { ... }
  ProjectRow _buildReadonlyProjectScopeRow({...}) { ... }
}
```

### Step 2: 拆分 `product_navigation.dart`

```dart
// shell/product_navigation.dart
part of '../../home_page.dart';

extension _HomePageProductNavigation on _HomePageState {
  void _applyDomainDeepLink(TaskCenterDomainDeepLink link) { ... }
  Future<void> _openProjectStudio(ProjectRow row) async { ... }
  void _openShellPaneFromStudioOverlay(...) { ... }
  int _deliverTabIndexFromRoute(BuildContext context, {int fallback = 0}) { ... }
  Future<void> _openComplianceProductTarget(...) async { ... }
}
```

### Step 3: 拆分其他模块
（类似步骤，按职责域拆分）

### Step 4: 更新 `home_page.dart`

```dart
// home_page.dart
part 'shell/build_sections_product.dart';
part 'shell/product_scope_management.dart';
part 'shell/product_navigation.dart';
part 'shell/product_studio_overlay.dart';
part 'shell/product_studio_steps.dart';
part 'shell/product_workbench_launchers.dart';
part 'shell/product_agent_workspace.dart';
part 'shell/product_panes_builder.dart';
```

## 关于你提到的交互问题（行号 4066-4073）

**已定位**：你提到的 `OutboundWebhookEventChips` 代码在 **`shell/help_hub_section.dart`** 中。

### 问题更严重

- **`help_hub_section.dart` 有 1620 行**（超过建议上限 800 行的 2 倍！）
- 这个文件也需要拆分
- Webhook 交互逻辑混在 Help Hub UI 构建中

### 发现的代码位置

```dart
// shell/help_hub_section.dart:989-996
OutboundWebhookEventChips(
  selected: outboundWebhookEffectiveSelection(wh.eventTypes),
  enabled: !_loadingWebhooks && _webhookBusyId == null,
  onSelectionChanged: (next) {
    unawaited(_patchWebhookEventSubscription(wh, next));
  },
),
```

### 建议

1. **`help_hub_section.dart` 也需要拆分**，建议拆分为：
   - `help_hub_section.dart` - 主入口（~200 行）
   - `help_hub_webhooks_ui.dart` - Webhook UI 构建（~400 行）
   - `help_hub_billing_ui.dart` - Billing UI 构建（~300 行）
   - `help_hub_support_ui.dart` - Support UI 构建（~300 行）
   - 已有的 `help_hub_webhook_actions.dart` 和 `help_hub_billing_actions.dart` 保持

2. **交互问题的根源**：
   - 1620 行的文件中，状态、UI、网络请求混在一起
   - `_loadingWebhooks` 和 `_webhookBusyId` 状态管理分散
   - `_patchWebhookEventSubscription` 方法可能在 `help_hub_webhook_actions.dart` 中

3. **优先级提升**：
   - `help_hub_section.dart` (1620 行) 比 `build_sections_product.dart` (1387 行) 更紧急
   - 建议同时拆分这两个文件

## 风险评估

### 低风险
- 拆分 part 文件不改变运行时行为
- Dart 的 extension 机制支持多个 extension 在同一个类上
- 只要 part 声明正确，编译器会处理

### 中风险
- 可能存在方法间的隐式依赖
- 需要仔细测试所有交互路径

### 高风险
- 如果提取独立 Widget/Controller，需要重构状态传递
- 可能影响现有的测试

## 建议执行顺序

1. **立即执行**：拆分 `product_scope_management.dart` 和 `product_navigation.dart`
   - 风险低，收益明显
   - 可以立即减少 ~350 行

2. **本周内执行**：拆分其余 part 文件
   - 完成后，主文件应该在 150 行左右
   - 每个 part 文件在 150-300 行之间

3. **下个迭代**：考虑提取独立 Controller/Widget
   - 需要更多设计和讨论
   - 可以作为技术债务跟踪

## 验证清单

拆分完成后，需要验证：

- [ ] `yarn refactor:agent` 通过
- [ ] 所有 Product Shell 导航功能正常
- [ ] Studio Overlay 正常显示
- [ ] 项目作用域切换正常
- [ ] 深度链接跳转正常
- [ ] Agent 工作区正常
- [ ] 所有产品面板正常显示

## 总结

**可以直接拆分**，建议采用**方案 A（按职责域拆分）**：

- ✅ 风险可控
- ✅ 收益明显（1387 行 → 7-8 个 150-300 行的文件）
- ✅ 不改变运行时行为
- ✅ 提升可维护性
- ✅ 为后续重构打基础

**不建议**立即采用方案 B（提取独立 Widget/Controller），除非：
- 有充足的时间进行架构重构
- 有完善的测试覆盖
- 团队达成共识

---

**下一步行动**：
1. 确认拆分方案
2. 创建拆分任务清单
3. 逐个拆分并验证
4. 提交 PR 并跑完整门禁
