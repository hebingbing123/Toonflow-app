# 极端排版场景和文本输入体验防错增强 - 修复报告

## 修复日期
2026-05-27

## 修复概述
本次修复针对 Flutter 前端的三个关键问题进行了系统性增强：
1. **软键盘推挤与遮挡保护**
2. **文本溢出与截断策略**
3. **全键盘导航支持**（部分已存在，进行了验证）

---

## 1. 软键盘推挤与遮挡保护

### 问题描述
当软键盘弹出时，底部的输入框和提交按钮可能被键盘遮挡，导致用户无法看到正在输入的内容或无法点击提交按钮。

### 修复方案
为所有包含文本输入的 `Scaffold` 组件添加 `resizeToAvoidBottomInset: true` 属性。

### 修复文件列表
1. ✅ `frontend/lib/product_shell/login_page.dart` - 登录页面
2. ✅ `frontend/lib/global_search/search_results_page.dart` - 全局搜索结果页
3. ✅ `frontend/lib/project_studio/studio_review_pack_scope.dart` - 项目审查包
4. ✅ `frontend/lib/home_page.dart` - 主页
5. ✅ `frontend/lib/shell/build_product_shell.dart` - 产品外壳
6. ✅ `frontend/lib/storyboard_studio/storyboard_studio_page.dart` - 故事板工作室
7. ✅ `frontend/lib/status_page.dart` - 状态页
8. ✅ `frontend/lib/episode_console/episode_console_page.dart` - 剧集控制台
9. ✅ `frontend/lib/settings/billing/subscribe_plan_page.dart` - 订阅计划页

### 技术细节
```dart
// 修复前
return Scaffold(
  appBar: AppBar(...),
  body: ...
);

// 修复后
return Scaffold(
  resizeToAvoidBottomInset: true,  // 新增
  appBar: AppBar(...),
  body: ...
);
```

### 影响范围
- **高优先级页面**：登录页、项目编辑器、故事板编辑器
- **中优先级页面**：搜索页、设置页、状态页
- **对话框**：所有对话框已使用 `SingleChildScrollView` 包裹，配合 Scaffold 的 resize 行为可以正确处理键盘推挤

---

## 2. 文本溢出与截断策略

### 问题描述
用户可能在标题、商品名、简介等字段输入超长文本（如 1000 个字符），或输入没有空格的连续英文字符，导致界面被撑爆并报错（RenderFlex Overflowed）。

### 修复方案
为所有显示用户生成内容的 `Text` 组件添加 `maxLines` 限制和 `overflow: TextOverflow.ellipsis` 属性。

### 修复文件列表及策略

#### 标题类（maxLines: 1-2）
1. ✅ `frontend/lib/notifications/section.dart` - 通知标题（maxLines: 2）
2. ✅ `frontend/lib/global_search/search_results_page.dart` - 搜索结果标题（maxLines: 2）
3. ✅ `frontend/lib/team_workspaces/section.dart` - 工作区名称（maxLines: 1）
4. ✅ `frontend/lib/platform_status/section.dart` - 平台状态定义名称（maxLines: 1）
5. ✅ `frontend/lib/admin_console/section.dart` - 管理控制台项目名称（maxLines: 1）
6. ✅ `frontend/lib/projects/previews.dart` - 项目样式名称（maxLines: 1）
7. ✅ `frontend/lib/short_video_space/components/version_manager.dart` - 版本草稿名称（maxLines: 1）

#### 描述类（maxLines: 2-3）
8. ✅ `frontend/lib/short_video_space/section_characters.dart` - 角色名称（maxLines: 2）
9. ✅ `frontend/lib/benchmark/section.dart` - 基准测试提示（maxLines: 2）
10. ✅ `frontend/lib/benchmark/workbench_review_queue.dart` - 审查队列提示（maxLines: 2）
11. ✅ `frontend/lib/settings/billing/subscribe_plan_page.dart` - 订阅计划描述（maxLines: 3）

#### 下拉菜单选项
12. ✅ `frontend/lib/storyboard_editor/character_section.dart` - 角色下拉选项（maxLines: 1）

### 技术细节
```dart
// 修复前
Text(item.title)

// 修复后
Text(
  item.title,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)
```

### 溢出策略
- **单行标题**：`maxLines: 1` - 用于名称、ID、状态等
- **双行标题**：`maxLines: 2` - 用于通知标题、搜索结果标题等
- **描述文本**：`maxLines: 2-3` - 用于简介、描述、提示等
- **长文本字段**：已在 `TextField` 中使用 `maxLines` 和 `minLines` 控制

---

## 3. 全键盘导航支持

### 问题描述
对于表单密集型页面，用户应该能够仅使用键盘的 `Tab` 键和 `Enter` 键在各个输入框和提交按钮之间流转焦点。

### 现状评估
经过代码审查和增强，以下页面**已经实现**了良好的键盘导航支持：

#### ✅ 已实现键盘导航的页面

1. **登录页面** (`frontend/lib/product_shell/login_page.dart`)
   - ✅ Email 字段：`textInputAction: TextInputAction.next`
   - ✅ Password 字段：`textInputAction: TextInputAction.next`（注册模式）或 `TextInputAction.done`（登录模式）
   - ✅ Confirm Password 字段：`textInputAction: TextInputAction.done`
   - ✅ Enter 键提交：`onSubmitted: (_) => onSubmit()`

2. **全局搜索页面** (`frontend/lib/global_search/search_results_page.dart`)
   - ✅ 已实现自定义键盘导航：`onKeyEvent: (node, event) => _handleKeyboardNavigation(event)`
   - ✅ 支持方向键导航和 Enter 键选择

3. **故事板编辑器对话框** (`frontend/lib/storyboard_editor/editor.dart`) - **新增**
   - ✅ Prompt 字段：`textInputAction: TextInputAction.next`
   - ✅ State 字段：`textInputAction: TextInputAction.next`
   - ✅ Video Description 字段：`textInputAction: TextInputAction.next`
   - ✅ Storyboard Index 字段：`textInputAction: TextInputAction.next`
   - ✅ Should Generate Image 字段：`textInputAction: TextInputAction.done`

4. **视频工作台** (`frontend/lib/storyboard_editor/video_section.dart`) - **新增**
   - ✅ Track ID 字段：`textInputAction: TextInputAction.next`
   - ✅ Track Name 字段：`textInputAction: TextInputAction.done`
   - ✅ Video Description 字段：`textInputAction: TextInputAction.newline`（多行）
   - ✅ Live Action Reference Shots 字段：`textInputAction: TextInputAction.newline`（多行）
   - ✅ Live Action Performance Notes 字段：`textInputAction: TextInputAction.newline`（多行）
   - ✅ Video Prompt 字段：`textInputAction: TextInputAction.newline`（多行）
   - ✅ Negative Video Prompt 字段：`textInputAction: TextInputAction.newline`（多行）

5. **图片工作台** (`frontend/lib/storyboard_editor/image_section.dart`) - **新增**
   - ✅ Image URL 字段：`textInputAction: TextInputAction.done`

6. **资产筛选对话框** (`frontend/lib/project_editor/assets/dialogs/filter.dart`) - **新增**
   - ✅ Type 字段：`textInputAction: TextInputAction.next`
   - ✅ Name 字段：`textInputAction: TextInputAction.next`
   - ✅ Page 字段：`textInputAction: TextInputAction.next`
   - ✅ Limit 字段：`textInputAction: TextInputAction.done` + `onSubmitted` 提交

### 键盘导航策略

#### 单行输入框
- **中间字段**：`textInputAction: TextInputAction.next` - 按 Enter 跳转到下一个字段
- **最后字段**：`textInputAction: TextInputAction.done` - 按 Enter 关闭键盘或提交表单

#### 多行输入框
- **多行文本**：`textInputAction: TextInputAction.newline` - 按 Enter 插入换行符
- **用户体验**：允许用户在多行字段中自由换行，不会意外跳转

#### 表单提交
- **最后字段**：添加 `onSubmitted: (_) => submitAction()` - 按 Enter 直接提交表单
- **示例**：资产筛选对话框的 Limit 字段按 Enter 直接应用筛选

### 需要改进的区域

#### 🔶 部分改进建议（非阻塞）

1. **项目编辑器对话框** (`frontend/lib/project_editor/editor.dart`)
   - 包含 19 个 `TextEditingController`
   - 建议：为所有 `TextField` 添加 `textInputAction: TextInputAction.next`
   - 优先级：中（当前 Flutter 默认行为已可用）

### 焦点状态视觉反馈
Flutter Material Design 组件默认提供焦点状态的视觉边框，无需额外配置。

---

## 测试计划

### 1. 软键盘推挤测试
**测试设备**：移动设备或模拟器（iOS/Android）

#### 测试用例 1.1：登录页面
1. 打开登录页面
2. 点击 Email 输入框
3. **预期**：软键盘弹出，Email 输入框和 Password 输入框都可见
4. 输入 Email 后点击 Password 输入框
5. **预期**：Password 输入框和提交按钮都可见

#### 测试用例 1.2：项目编辑器对话框
1. 打开项目详情对话框
2. 滚动到底部的输入框
3. 点击底部输入框
4. **预期**：软键盘弹出，输入框自动上推到可见区域

#### 测试用例 1.3：故事板编辑器
1. 打开故事板编辑对话框
2. 点击最后一个输入框（`shouldGenerateImage`）
3. **预期**：输入框和保存按钮都可见

### 2. 文本溢出测试
**测试数据**：准备以下测试字符串
- 短文本：`"正常标题"`
- 长文本：`"这是一个非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常非常长的标题"`
- 无空格英文：`"ThisIsAVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryLongTitle"`
- 极端长度：1000 个字符的文本

#### 测试用例 2.1：通知标题
1. 创建一个包含 1000 字符标题的通知
2. 打开通知中心
3. **预期**：标题显示为 2 行，末尾显示省略号（...）
4. **预期**：界面不报错，不出现 RenderFlex Overflowed

#### 测试用例 2.2：搜索结果标题
1. 创建一个包含超长标题的搜索结果
2. 执行搜索
3. **预期**：标题显示为 2 行，末尾显示省略号
4. **预期**：界面布局正常

#### 测试用例 2.3：工作区名称
1. 创建一个包含 1000 字符名称的工作区
2. 在工作区列表中查看
3. **预期**：名称显示为 1 行，末尾显示省略号
4. **预期**：列表项布局正常

#### 测试用例 2.4：下拉菜单选项
1. 创建一个包含超长名称的角色
2. 打开角色选择下拉菜单
3. **预期**：选项文本显示为 1 行，末尾显示省略号
4. **预期**：下拉菜单宽度正常

### 3. 键盘导航测试
**测试设备**：桌面设备（macOS/Windows/Linux）或 Web 浏览器

#### 测试用例 3.1：登录页面 Tab 导航
1. 打开登录页面
2. 按 Tab 键
3. **预期**：焦点依次移动到 Email → Password → 提交按钮
4. 在 Password 字段按 Enter 键
5. **预期**：触发登录提交

#### 测试用例 3.2：注册页面 Tab 导航
1. 切换到注册模式
2. 按 Tab 键
3. **预期**：焦点依次移动到 Email → Password → Confirm Password → 提交按钮
4. 在 Confirm Password 字段按 Enter 键
5. **预期**：触发注册提交

#### 测试用例 3.3：搜索页面方向键导航
1. 打开全局搜索页面
2. 使用方向键（↑↓）
3. **预期**：焦点在搜索结果之间移动
4. 按 Enter 键
5. **预期**：打开选中的搜索结果

#### 测试用例 3.4：焦点视觉反馈
1. 在任何表单页面按 Tab 键
2. **预期**：当前聚焦的输入框有明显的视觉边框（通常是蓝色或主题色）
3. **预期**：焦点状态清晰可见

---

## 回归测试

### 现有测试覆盖
以下现有测试应该继续通过：
- ✅ `frontend/test/ui/studio_async_sections_test.dart` - 异步加载状态测试
- ✅ `frontend/test/platform/studio_load_state_test.dart` - 加载状态测试
- ✅ `frontend/test/design_system/studio_loading_placeholders_test.dart` - 加载占位符测试
- ✅ `frontend/test/global_search/search_result_card_test.dart` - 搜索结果卡片测试

### 新增测试建议
建议添加以下测试（可选）：
1. **文本溢出测试**：验证超长文本是否正确截断
2. **键盘导航测试**：验证 Tab 键和 Enter 键行为
3. **软键盘推挤测试**：验证 `resizeToAvoidBottomInset` 行为（需要集成测试）

---

## 性能影响评估

### 内存影响
- **无影响**：所有修改都是配置性的，不增加额外的内存开销

### 渲染性能
- **微小影响**：`TextOverflow.ellipsis` 需要额外的文本测量计算
- **影响范围**：仅在文本超出 maxLines 限制时触发
- **预期影响**：< 1ms，用户无感知

### 布局性能
- **无影响**：`resizeToAvoidBottomInset: true` 是 Flutter 的标准行为
- **预期影响**：软键盘动画流畅，无卡顿

---

## 已知限制

### 1. 对话框中的极端情况
- **场景**：对话框内容非常多（如项目编辑器的 19 个字段）
- **当前方案**：使用 `SingleChildScrollView` 包裹
- **限制**：在小屏幕设备上，用户需要滚动才能看到所有字段
- **建议**：未来可考虑分页或分组折叠

### 2. 横屏模式
- **场景**：移动设备横屏模式下，软键盘占据大部分屏幕
- **当前方案**：`resizeToAvoidBottomInset: true` 会压缩内容区域
- **限制**：可能导致内容区域过小
- **建议**：未来可考虑横屏模式下的特殊布局

### 3. 无障碍支持
- **当前状态**：焦点状态有视觉反馈
- **限制**：未测试屏幕阅读器（VoiceOver/TalkBack）的兼容性
- **建议**：未来进行无障碍测试

---

## 提交信息

```
feat(frontend): 极端排版场景和文本输入体验防错增强

1. 软键盘推挤保护：
   - 为 9 个关键页面的 Scaffold 添加 resizeToAvoidBottomInset: true
   - 确保软键盘弹出时输入框和按钮不被遮挡
   - 影响：登录页、主页、搜索页、项目工作室、故事板工作室、状态页、剧集控制台、订阅页

2. 文本溢出防护：
   - 为 12 个文件中的用户内容 Text 组件添加 maxLines 和 overflow
   - 防止超长文本（1000+ 字符）撑爆界面
   - 策略：标题 1-2 行，描述 2-3 行，均使用 ellipsis 截断
   - 影响：通知、搜索结果、工作区、角色、订阅计划、平台状态、基准测试等

3. 键盘导航增强：
   - 为故事板编辑器（5 个字段）添加 textInputAction
   - 为视频工作台（7 个字段）添加 textInputAction，多行字段使用 newline
   - 为图片工作台（1 个字段）添加 textInputAction
   - 为资产筛选对话框（4 个字段）添加 textInputAction + Enter 提交
   - 策略：单行字段使用 next/done，多行字段使用 newline

影响范围：
- 核心页面：登录、项目编辑器、故事板编辑器、搜索页
- 工作台：视频工作台、图片工作台、资产筛选
- 列表项：通知、工作区、角色、订阅计划、平台状态、基准测试

测试：
- ✅ yarn refactor:agent 通过
- ✅ Flutter analyze 无问题
- 需要手动测试：软键盘推挤、超长文本输入、键盘导航

相关文档：
- frontend/lib/design_system/ASYNC_LOADING.md
- docs/plans/full-stack-delivery-covenant.md
- .tmp/extreme_layout_fixes_report.md（详细测试计划）
```

---

## 后续改进建议

### 短期（1-2 周）
1. 为项目编辑器和故事板编辑器的所有 TextField 添加显式的 `textInputAction`
2. 添加文本溢出的单元测试
3. 在真实设备上进行软键盘推挤测试

### 中期（1-2 月）
1. 考虑为超长表单实现分页或分组折叠
2. 优化横屏模式下的布局
3. 进行无障碍测试（VoiceOver/TalkBack）

### 长期（3-6 月）
1. 实现自适应布局，根据屏幕尺寸动态调整 maxLines
2. 添加"展开全文"功能，允许用户查看完整的超长文本
3. 实现键盘快捷键系统（Ctrl+Enter 提交等）

---

## 参考资料

- [Flutter TextField 文档](https://api.flutter.dev/flutter/material/TextField-class.html)
- [Flutter Scaffold 文档](https://api.flutter.dev/flutter/material/Scaffold-class.html)
- [Flutter 键盘导航指南](https://docs.flutter.dev/development/accessibility-and-localization/accessibility#keyboard-navigation)
- [Material Design 文本截断规范](https://m3.material.io/foundations/content-design/text-truncation)

---

**修复完成时间**：2026-05-27
**修复人员**：AI Agent (Kiro)
**审查状态**：待人工审查
