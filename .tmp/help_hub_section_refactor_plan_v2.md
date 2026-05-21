# help_hub_section.dart 拆分方案 V2（渐进式）

## 现状分析

### 现有文件
- `help_hub_section.dart` (1620 行) - 主文件：State + UI
- `help_hub_webhook_actions.dart` (524 行) - Webhook 操作（extension）
- `help_hub_billing_actions.dart` (352 行) - Billing 操作（extension）

### 问题
主文件包含：
- 状态定义（~100 行）
- Help Hub Docs UI（~400 行）
- Webhooks UI（~700 行）
- Billing UI（~400 行）

## 拆分方案：UI 构建方法分离

保持 `_HelpHubSectionState`，将 UI 构建方法拆分为 part 文件：

```
shell/
├── help_hub_section.dart                # 主文件 + State（~200 行）
├── help_hub_docs_ui.dart                # Docs UI 构建（~400 行）
├── help_hub_webhooks_ui.dart            # Webhooks UI 构建（~700 行）
├── help_hub_billing_ui.dart             # Billing UI 构建（~400 行）
├── help_hub_webhook_actions.dart        # 已存在（524 行）
└── help_hub_billing_actions.dart        # 已存在（352 行）
```

### 拆分后的结构

#### 1. `help_hub_section.dart` (~200 行)
```dart
part of '../../home_page.dart';

class _HelpHubSection extends StatefulWidget { ... }

class _HelpHubSectionState extends State<_HelpHubSection> {
  // 所有状态变量
  bool _loading = false;
  // ...
  
  @override
  void initState() { ... }
  
  @override
  void dispose() { ... }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ..._buildHelpHubDocsSection(context),
          ..._buildWebhooksSection(context),
          ..._buildBillingSection(context),
        ],
      ),
    );
  }
}
```

#### 2. `help_hub_docs_ui.dart` (~400 行)
```dart
part of '../../home_page.dart';

extension _HelpHubDocsUI on _HelpHubSectionState {
  List<Widget> _buildHelpHubDocsSection(BuildContext context) {
    // 所有 Help Hub Docs 相关的 UI 构建代码
  }
  
  Future<void> _openHelpHubManageDialog() async { ... }
  
  List<HelpHubLinkItemV1> _filteredHelpHubLinks() { ... }
  
  String _helpHubCategorySlug(HelpHubLinkItemV1 item) { ... }
  
  // ... 其他 Docs 相关方法
}
```

#### 3. `help_hub_webhooks_ui.dart` (~700 行)
```dart
part of '../../home_page.dart';

extension _HelpHubWebhooksUI on _HelpHubSectionState {
  List<Widget> _buildWebhooksSection(BuildContext context) {
    // 所有 Webhooks 相关的 UI 构建代码
    // 包括你提到的交互问题代码
  }
  
  List<OutboundWebhookListItemV1> _filteredWebhooks() { ... }
  
  // ... 其他 Webhooks UI 相关方法
}
```

#### 4. `help_hub_billing_ui.dart` (~400 行)
```dart
part of '../../home_page.dart';

extension _HelpHubBillingUI on _HelpHubSectionState {
  List<Widget> _buildBillingSection(BuildContext context) {
    // 所有 Billing 相关的 UI 构建代码
  }
  
  // ... 其他 Billing UI 相关方法
}
```

## 优点

1. **改动范围小**
   - 不改变状态管理
   - 不改变 API
   - 只是重新组织代码

2. **风险低**
   - 编译器会检查所有依赖
   - 不会破坏现有逻辑

3. **快速完成**
   - 预计 2-3 小时
   - 不需要重构状态传递

4. **立即见效**
   - 主文件从 1620 行减少到 ~200 行
   - 每个 UI 文件 400-700 行

## 实施步骤

### Step 1: 创建 `help_hub_docs_ui.dart`
- 提取所有 Help Hub Docs 相关的 UI 构建方法
- 创建 extension `_HelpHubDocsUI`

### Step 2: 创建 `help_hub_webhooks_ui.dart`
- 提取所有 Webhooks 相关的 UI 构建方法
- 创建 extension `_HelpHubWebhooksUI`
- **重点关注你提到的交互问题代码**

### Step 3: 创建 `help_hub_billing_ui.dart`
- 提取所有 Billing 相关的 UI 构建方法
- 创建 extension `_HelpHubBillingUI`

### Step 4: 重构 `help_hub_section.dart`
- 保留状态定义和生命周期方法
- 简化 `build` 方法，调用各个 extension 的方法
- 添加 part 声明

### Step 5: 更新 `home_page.dart`
- 添加新的 part 声明

### Step 6: 验证和提交
- 运行 `yarn refactor:agent`
- 手动测试
- Git commit

## 预期收益

- 主文件：1620 行 → ~200 行（-87.7%）
- 每个 UI 文件：400-700 行（符合标准）
- 职责清晰，易于维护
- 你的交互问题代码在独立的文件中，更容易调试

## 时间估算

- Step 1: 1 小时
- Step 2: 1.5 小时
- Step 3: 1 小时
- Step 4: 0.5 小时
- Step 5-6: 0.5 小时
- **总计**: 4.5 小时

比完全重写（5-9 小时）更快，风险更低。
