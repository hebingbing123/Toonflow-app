# Studio 剧本步 UX 打磨计划（2026-05-21）

## 范围

六步工作流 **剧本** 步整页（截图对应区域）：

- 顶栏：步骤条、步骤模型路由、快速起步模板、Agent 快捷条、驾驶舱摘要
- 主区：`ProjectStudioScriptStepPanel`（左内容轨 + 右 Agent 工作区）
- 内联：`StudioScriptNovelInlineImport`

## 审计结论

| 维度 | 问题 |
|------|------|
| 视觉层级 | 宽屏下「剧本工作区」标题重复；顶栏卡片与主工作区对比度接近；左轨信息密度远高于右侧表单区 |
| 间距 | `cardInner - 4` 等魔法数分散；Tab 与卡片间距不统一 |
| 字体 | Agent 区外层仍用 `titleSmall`，与 `StudioPaneHeader` 不一致 |
| 颜色 | 小说导入卡使用 `primary` 描边过亮，与 `bgInset` 左轨不协调 |
| 按钮可点性 | 快捷条 `ActionChip` 对比度弱；内联「高级工作台」为弱 `TextButton` |
| 空状态 | `studioScriptStepEmpty*` 文案存在但剧本 Tab 无列表时未展示引导 |
| 交互 | 窄屏「内容/生成」下再嵌套三 Tab，层级过深；无内容计数扫读 |
| 布局 | 侧栏固定 380px；仅 1080 分栏，平板宽度体验差 |
| 多端 | &lt;720 应上下堆叠；&lt;1080 应用 Tab 而非强制分栏 |

## 实施项（本 PR）

1. **去重标题**：剧本步宽屏由 `StudioPaneHeader` 统一展示标题+说明；Agent 区 `suppressSectionHeader`。
2. **内容轨**：Tab 样式统一；顶栏显示「小说 N · 剧本 M」；剧本 Tab 空列表用 `StudioEmptyState.firstUse`。
3. **响应式**：720 以下上下堆叠；侧栏宽度随约束自适应（约 32%–40%，clamp 300–420）。
4. **小说导入卡**：改用 `borderSubtle`、studio 字号 token；主 CTA 保证触控高度。
5. **快捷条**：`ActionChip` → 带边框的 tonal 按钮，提升可点性感。

## Phase 2（2026-05-21 续）

- 新增 `ProjectStudioScriptStepSetupPanel`：剧本步将模型路由、快速起步、快捷条、驾驶舱合并为 **默认折叠** 的「步骤准备区」。
- `project_studio_page.dart` 顶栏由三块 Padding 收敛为单块，主工作区默认获得更多垂直空间。

## 验证

- `flutter test test/ui/studio_step_script_test.dart`
- `flutter test test/project_studio/novel_inline_import_section_test.dart`
- `yarn refactor:agent`（frontend 改动）
