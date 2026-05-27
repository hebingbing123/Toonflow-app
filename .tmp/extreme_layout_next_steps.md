# 极端排版场景修复 - 下一步行动清单

## ✅ 已完成的工作

### 1. 代码修复（已提交）
- ✅ 9 个页面添加软键盘推挤保护
- ✅ 12 个文件添加文本溢出防护
- ✅ 4 个对话框/工作台添加键盘导航支持（17 个字段）
- ✅ 所有修改通过 `yarn refactor:agent` 检查
- ✅ Git commit: `bdff429ae`

### 2. 文档输出
- ✅ 详细测试计划：`.tmp/extreme_layout_fixes_report.md`
- ✅ 完成总结：`.tmp/extreme_layout_fixes_summary.md`
- ✅ 下一步清单：`.tmp/extreme_layout_next_steps.md`（本文件）

---

## 🔍 需要人工验证的项目

### 优先级 1：关键路径测试（建议立即进行）

#### 1.1 移动设备软键盘测试
**设备**：iOS 或 Android 真机/模拟器

**测试步骤**：
```
1. 打开登录页面
2. 点击 Email 输入框
   ✓ 预期：软键盘弹出，Email 和 Password 输入框都可见
3. 输入 Email 后点击 Password 输入框
   ✓ 预期：Password 输入框和提交按钮都可见
4. 切换到注册模式，点击 Confirm Password 输入框
   ✓ 预期：所有输入框和提交按钮都可见
```

**如果失败**：检查 `Scaffold` 的 `resizeToAvoidBottomInset` 是否生效

#### 1.2 超长文本溢出测试
**测试数据**：
```dart
// 准备测试字符串
final longText = "这是一个" + "非常" * 200 + "长的标题";
final noSpaceText = "ThisIsAVeryVeryVery" * 50 + "LongTitle";
```

**测试步骤**：
```
1. 创建一个包含 1000 字符标题的通知
   ✓ 预期：标题显示为 2 行，末尾显示 "..."
   ✓ 预期：界面不报错，不出现 RenderFlex Overflowed

2. 创建一个包含无空格英文的工作区名称
   ✓ 预期：名称显示为 1 行，末尾显示 "..."
   ✓ 预期：列表项布局正常

3. 在故事板编辑器的 Prompt 字段输入 1000 字符
   ✓ 预期：TextField 正常显示，可以滚动查看全部内容
```

**如果失败**：检查 `Text` 组件的 `maxLines` 和 `overflow` 属性

#### 1.3 桌面键盘导航测试
**设备**：macOS/Windows/Linux 或 Web 浏览器

**测试步骤**：
```
1. 打开登录页面
2. 按 Tab 键
   ✓ 预期：焦点依次移动到 Email → Password → 提交按钮
   ✓ 预期：当前聚焦的输入框有蓝色边框
3. 在 Password 字段按 Enter 键
   ✓ 预期：触发登录提交

4. 打开故事板编辑器对话框
5. 按 Tab 键在 5 个字段间切换
   ✓ 预期：焦点依次移动，最后停在 Should Generate Image 字段
6. 在最后一个字段按 Enter 键
   ✓ 预期：关闭键盘（移动端）或保持焦点（桌面端）

7. 打开资产筛选对话框
8. 按 Tab 键在 4 个字段间切换
9. 在 Limit 字段按 Enter 键
   ✓ 预期：直接应用筛选并关闭对话框

10. 打开视频工作台
11. 在 Video Prompt 字段（多行）按 Enter 键
    ✓ 预期：插入换行符，不跳转到下一个字段
```

**如果失败**：检查 `textInputAction` 和 `onSubmitted` 配置

---

## 🚀 建议的后续改进（按优先级）

### 优先级 2：增强现有功能（1-2 周内）

#### 2.1 为项目编辑器添加键盘导航
**文件**：`frontend/lib/project_editor/editor.dart`
**工作量**：约 1 小时
**影响**：19 个字段

**实施步骤**：
1. 为所有 `TextField` 添加 `textInputAction: TextInputAction.next`
2. 为最后一个字段添加 `textInputAction: TextInputAction.done`
3. 测试 Tab 键导航流程

#### 2.2 添加文本溢出单元测试
**文件**：`frontend/test/ui/text_overflow_test.dart`（新建）
**工作量**：约 2 小时

**测试用例**：
```dart
testWidgets('Notification title truncates long text', (tester) async {
  final longTitle = "这是一个" + "非常" * 200 + "长的标题";
  // ... 测试代码
  expect(find.text(longTitle, findRichText: true), findsNothing);
  expect(find.textContaining("..."), findsOneWidget);
});
```

#### 2.3 添加键盘导航集成测试
**文件**：`frontend/integration_test/keyboard_navigation_test.dart`（新建）
**工作量**：约 3 小时

**测试场景**：
- 登录页面 Tab 导航
- 故事板编辑器 Tab 导航
- 资产筛选对话框 Enter 提交

---

### 优先级 3：用户体验优化（1-2 月内）

#### 3.1 超长表单分页/折叠
**目标**：优化项目编辑器的 19 个字段显示
**方案**：
- 方案 A：使用 `ExpansionPanel` 分组折叠
- 方案 B：使用 `PageView` 分页显示
- 方案 C：使用 `Stepper` 步骤式导航

**推荐**：方案 A（分组折叠），保持单页面，减少认知负担

#### 3.2 横屏模式优化
**目标**：改善横屏模式下的软键盘体验
**方案**：
```dart
// 检测横屏模式
final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

// 横屏时使用不同的布局策略
if (isLandscape) {
  // 使用 Row 布局，左侧表单，右侧预览
} else {
  // 使用 Column 布局，垂直堆叠
}
```

#### 3.3 "展开全文"功能
**目标**：允许用户查看完整的超长文本
**方案**：
```dart
// 可展开的文本组件
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  
  // 点击 "展开" 按钮显示全文
  // 点击 "收起" 按钮恢复截断
}
```

---

### 优先级 4：无障碍支持（3-6 月内）

#### 4.1 屏幕阅读器测试
**工具**：
- iOS：VoiceOver
- Android：TalkBack
- macOS：VoiceOver
- Windows：NVDA

**测试项目**：
- 所有输入框是否有正确的标签
- 焦点顺序是否合理
- 错误提示是否可读

#### 4.2 键盘快捷键系统
**功能**：
- `Ctrl+Enter`：提交表单
- `Esc`：关闭对话框
- `Ctrl+/`：显示快捷键帮助

---

## 📊 质量指标

### 当前状态
- ✅ 软键盘推挤保护覆盖率：9/9 关键页面（100%）
- ✅ 文本溢出防护覆盖率：12/15+ 关键组件（80%+）
- ✅ 键盘导航支持：6/10 表单密集页面（60%）
- ✅ 自动化测试通过率：100%（yarn refactor:agent）

### 目标状态（3 个月后）
- 🎯 软键盘推挤保护覆盖率：100%
- 🎯 文本溢出防护覆盖率：95%+
- 🎯 键盘导航支持：90%+
- 🎯 单元测试覆盖率：80%+
- 🎯 集成测试覆盖率：60%+
- 🎯 无障碍测试通过率：100%

---

## 🔧 故障排查指南

### 问题 1：软键盘仍然遮挡输入框
**可能原因**：
1. `resizeToAvoidBottomInset` 未生效
2. 对话框使用了固定高度
3. 父组件限制了 Scaffold 的 resize 行为

**解决方案**：
```dart
// 确保对话框内容可滚动
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    content: SingleChildScrollView(  // 关键
      child: Column(children: [...]),
    ),
  ),
);
```

### 问题 2：文本仍然溢出
**可能原因**：
1. `maxLines` 设置过大
2. 父容器没有宽度约束
3. 使用了 `Expanded` 但没有 `Flexible`

**解决方案**：
```dart
// 确保有宽度约束
ConstrainedBox(
  constraints: BoxConstraints(maxWidth: 300),
  child: Text(
    longText,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  ),
);
```

### 问题 3：Tab 键不跳转
**可能原因**：
1. `textInputAction` 未设置
2. 焦点节点配置错误
3. 表单被禁用

**解决方案**：
```dart
// 确保 textInputAction 正确
TextField(
  textInputAction: TextInputAction.next,  // 关键
  onSubmitted: (_) {
    // 可选：手动控制焦点
    FocusScope.of(context).nextFocus();
  },
);
```

---

## 📝 提交清单

在宣布完成前，请确认：

- [x] 所有代码修改已提交到 Git
- [x] 所有自动化检查通过（yarn refactor:agent）
- [ ] 在真实移动设备上测试软键盘推挤
- [ ] 在桌面设备上测试键盘导航
- [ ] 测试超长文本输入（1000+ 字符）
- [ ] 更新相关文档（如有必要）
- [ ] 通知团队成员进行 Code Review

---

## 🎯 成功标准

本次修复被认为成功，当且仅当：

1. ✅ **代码质量**：所有自动化检查通过
2. ⏳ **功能验证**：软键盘推挤、文本溢出、键盘导航在真实设备上正常工作
3. ⏳ **用户体验**：用户可以流畅地输入超长文本，不会遇到界面崩溃
4. ⏳ **无回归**：现有功能不受影响

**当前状态**：1/4 完成（代码质量已达标，等待功能验证）

---

## 📞 联系方式

如果在测试过程中遇到问题，请：

1. 查看本文档的"故障排查指南"部分
2. 查看详细测试计划：`.tmp/extreme_layout_fixes_report.md`
3. 查看完成总结：`.tmp/extreme_layout_fixes_summary.md`
4. 查看 Git commit：`bdff429ae`

---

**最后更新**：2026-05-27
**状态**：等待人工验证
**下一步**：在真实设备上进行优先级 1 测试
