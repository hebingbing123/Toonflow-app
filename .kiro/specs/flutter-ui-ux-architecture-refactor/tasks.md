# Implementation Plan: Flutter UI/UX Architecture Refactor

## Overview

本实施计划将 Toonflow Flutter 应用的 UI/UX 架构重构分解为可执行的编码任务。重构涵盖 747 个 .dart 文件，按照 P0（关键）、P1（重要）、P2（优化）三个优先级组织，遵循 AGENTS.md 约定（单文件 ≤800 行、小步多次 commit）和 ASYNC_LOADING.md 异步加载规范。

**实施原则**：
- 每个任务独立可测试和验证
- 优先完成 P0 任务，再进行 P1 和 P2
- 遵循设计系统 → 组件库 → 应用层的依赖顺序
- 所有数据加载使用骨架屏，禁止全页 CircularProgressIndicator
- 错误信息使用 describeUserVisibleApiErrorResolved 格式化

## Tasks

### P0: 关键基础设施（Phase 1-5）

- [ ] 1. 设计系统核心扩展
  - [ ] 1.1 扩展 StudioTokens 交互状态颜色
    - 在 `frontend/lib/design_system/tokens.dart` 中添加 primaryHover、primaryPressed、primaryDisabled、primaryFocus 等状态颜色
    - 为 accent、surface 等颜色添加对应状态变体
    - 确保亮色和暗色主题都有完整的状态颜色定义
    - 更新 buildStudioTheme 函数以初始化所有新增颜色
    - _Requirements: 1.1, 1.8_
  
  - [ ] 1.2 创建 StudioElevation 阴影系统
    - 创建 `frontend/lib/design_system/studio_elevation.dart`
    - 定义 level0 到 level5 共 6 个阴影级别
    - 每个级别提供亮色和暗色主题的阴影配置
    - 添加使用文档和示例注释
    - _Requirements: 1.2_
  
  - [ ] 1.3 完善 StudioMotion 动画系统
    - 扩展 `frontend/lib/design_system/studio_motion.dart`
    - 添加 fast(150ms)、normal(250ms)、slow(350ms) 时长常量
    - 定义 easeOut、easeIn、easeInOut 等缓动曲线
    - 为常见用例定义专用常量（hoverTransition、dialogTransition 等）
    - _Requirements: 1.5_

  - [ ] 1.4 标准化圆角和间距系统
    - 在 `frontend/lib/design_system/tokens.dart` 的 StudioSpacing 中补全所有圆角值
    - 添加 radiusCircle、radiusNone、radiusHairline 等缺失的圆角常量
    - 定义 StudioZIndex 层级系统（dropdown、modal、toast 等）
    - 实现 touchTargetForPlatform 和 touchTargetForContext 方法
    - _Requirements: 1.3, 1.4, 1.6, 1.7_

- [ ] 2. 响应式布局架构升级
  - [ ] 2.1 统一响应式断点系统
    - 扩展 `frontend/lib/design_system/layout_breakpoints.dart`
    - 定义 StudioBreakpoint 枚举（mobile<600、tablet 600-960、desktop 960-1280、wide>1280）
    - 实现 fromWidth 静态方法和便捷属性（isMobile、isTablet 等）
    - 添加单元测试验证断点判断逻辑
    - _Requirements: 3.1_
  
  - [ ] 2.2 创建 StudioResponsiveLayout 组件
    - 在 `frontend/lib/design_system/layout_breakpoints.dart` 中实现 StudioResponsiveLayout
    - 使用 LayoutBuilder 而非 MediaQuery 支持嵌套响应式
    - 支持 mobile、tablet、desktop、wide 四个断点的 builder
    - 实现降级逻辑（wide → desktop → tablet → mobile）
    - _Requirements: 3.5_
  
  - [ ] 2.3 实现自适应字体主题切换
    - 创建 `frontend/lib/design_system/studio_adaptive_theme.dart`
    - 实现 StudioAdaptiveTheme 组件，根据视口宽度切换 typography
    - 在 1280px 和 1720px 断点自动切换 compact、regular、large 配置
    - 集成到主应用的 MaterialApp 中
    - _Requirements: 3.2_

- [ ] 3. 异步加载模式标准化
  - [ ] 3.1 审计现有异步加载实现
    - 扫描所有使用 CircularProgressIndicator 的文件
    - 识别不符合 ASYNC_LOADING.md 规范的用例
    - 生成重构清单（文件路径、当前实现、目标实现）
    - 创建迁移优先级矩阵（按影响范围和用户可见性排序）
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [ ] 3.2 统一骨架屏组件使用
    - 将所有列表加载替换为 StudioListSkeleton
    - 将所有面板加载替换为 StudioPaneLoadingSkeleton
    - 将所有网格加载替换为 StudioGridSkeleton
    - 确保所有骨架屏使用正确的 density 参数
    - _Requirements: 4.2, 4.3, 4.4_
  
  - [ ] 3.3 统一错误处理和空状态
    - 将所有全页错误替换为 StudioEmptyState.loadFailed
    - 将所有行内错误替换为 StudioApiErrorCallout
    - 将所有空数据状态替换为 StudioEmptyState.emptyData
    - 确保所有错误使用 describeUserVisibleApiErrorResolved 格式化
    - _Requirements: 4.5, 4.6, 4.8_
  
  - [ ] 3.4 扩展 StudioAsyncDataView 使用范围
    - 识别所有使用 StudioLoadState 的面板
    - 将这些面板迁移到 StudioAsyncDataView + resolveStudioPaneLoadState 模式
    - 确保 loading、error、data 三态都有正确的 UI 反馈
    - 添加重试逻辑到所有错误状态
    - _Requirements: 4.9_

- [ ] 4. Checkpoint - 验证 P0 基础设施
  - 运行 `flutter analyze` 确保无静态分析错误
  - 运行 `flutter test` 确保所有测试通过
  - 手动测试设计系统组件在亮色和暗色主题下的表现
  - 验证响应式布局在不同断点下的切换
  - 验证异步加载模式在主要数据面板的表现
  - 确认所有改动符合 AGENTS.md 约定（单文件 ≤800 行）


### P1: 组件库与交互优化（Phase 6-12）

- [ ] 5. 基础组件完善（Tier 1）
  - [ ] 5.1 增强 StudioButton 组件
    - 在现有 StudioButton 基础上添加完整的交互状态管理
    - 实现 hover、focus、pressed、disabled 状态的视觉反馈
    - 添加 isLoading 状态支持（显示 CircularProgressIndicator(strokeWidth: 2)）
    - 支持 icon 属性和 semanticLabel 无障碍标签
    - 使用 StudioMotion.hoverTransition 和 StudioTokens 状态颜色
    - _Requirements: 2.1, 2.7, 5.2, 5.3_
  
  - [ ] 5.2 创建 StudioInput 组件
    - 创建 `frontend/lib/design_system/components/basic/studio_input.dart`
    - 基于 TextField 实现一致的输入框样式
    - 支持 label、hint、error、helper text
    - 实现 focus 状态的 2px primary 边框
    - 支持 prefix/suffix icon 和 clear button
    - _Requirements: 2.1, 5.4_
  
  - [ ] 5.3 创建 StudioCheckbox、StudioRadio、StudioSwitch 组件
    - 创建 `frontend/lib/design_system/components/basic/studio_checkbox.dart`
    - 创建 `frontend/lib/design_system/components/basic/studio_radio.dart`
    - 创建 `frontend/lib/design_system/components/basic/studio_switch.dart`
    - 统一使用 StudioTokens 颜色和 StudioMotion 动画
    - 确保触摸目标符合平台规范（桌面 36px、移动 44px）
    - 添加 semanticLabel 支持
    - _Requirements: 2.1, 6.1_
  
  - [ ] 5.4 创建 StudioSlider 和 StudioIconButton 组件
    - 创建 `frontend/lib/design_system/components/basic/studio_slider.dart`
    - 创建 `frontend/lib/design_system/components/basic/studio_icon_button.dart`
    - 实现一致的交互状态和无障碍支持
    - 使用设计系统颜色和动画规范
    - _Requirements: 2.1, 6.1_

- [ ] 6. 复合组件完善（Tier 2）
  - [ ] 6.1 增强 StudioCard 组件
    - 扩展现有 StudioCard 支持 elevation 属性
    - 使用 StudioElevation 阴影系统
    - 支持 hover 状态的阴影提升效果
    - 添加 onTap 回调和涟漪效果
    - _Requirements: 2.2, 5.1_
  
  - [ ] 6.2 创建 StudioDialog 和 StudioSheet 组件
    - 创建 `frontend/lib/design_system/components/composite/studio_dialog.dart`
    - 创建 `frontend/lib/design_system/components/composite/studio_sheet.dart`
    - 实现淡入淡出动画（250ms）和滑动动画（300ms）
    - 支持 title、content、actions 插槽
    - 实现焦点陷阱（focus trap）确保无障碍
    - _Requirements: 2.2, 5.6, 5.7, 6.9_
  
  - [ ] 6.3 创建 StudioDrawer 组件
    - 创建 `frontend/lib/design_system/components/composite/studio_drawer.dart`
    - 支持左侧和右侧抽屉
    - 使用 StudioMotion.drawerTransition 动画
    - 实现遮罩层和点击外部关闭
    - _Requirements: 2.2, 5.7_
  
  - [ ] 6.4 创建 StudioSnackbar 和 StudioToast 组件
    - 创建 `frontend/lib/design_system/components/composite/studio_snackbar.dart`
    - 创建 `frontend/lib/design_system/components/composite/studio_toast.dart`
    - 支持 success、warning、error、info 四种类型
    - 实现 3 秒自动消失和手动关闭
    - 支持操作按钮（重试、撤销、查看详情）
    - _Requirements: 2.2, 5.9, 18.1, 18.2, 18.3_
  
  - [ ] 6.5 创建 StudioTooltip 和 StudioMenu 组件
    - 创建 `frontend/lib/design_system/components/composite/studio_tooltip.dart`
    - 创建 `frontend/lib/design_system/components/composite/studio_menu.dart`
    - 使用 StudioElevation.level2 阴影
    - 实现键盘导航（Arrow 键、Enter、Esc）
    - 支持子菜单和分隔线
    - _Requirements: 2.2, 6.1_

- [ ] 7. 无障碍性全面提升
  - [ ] 7.1 实现键盘导航支持
    - 审计所有交互元素的键盘可访问性
    - 为所有按钮、输入框、菜单添加 Tab 导航支持
    - 实现 Enter/Space 激活、Arrow 键导航、Esc 关闭
    - 确保焦点顺序符合逻辑阅读顺序（从左到右、从上到下）
    - _Requirements: 6.1, 6.2_
  
  - [ ] 7.2 添加语义化标签和屏幕阅读器支持
    - 为所有图标和图片添加 Semantics widget
    - 为所有表单输入提供关联的标签
    - 为所有错误消息提供屏幕阅读器公告
    - 为所有模态对话框实现焦点陷阱
    - _Requirements: 6.3, 6.4, 6.6, 6.9_
  
  - [ ] 7.3 验证颜色对比度和无障碍标准
    - 使用工具检查所有文本与背景的对比度
    - 确保正文 4.5:1、大文本 3:1 符合 WCAG 2.1 AA
    - 为所有颜色编码信息提供文本或图标替代
    - 支持用户偏好的动画减少设置（prefers-reduced-motion）
    - _Requirements: 6.5, 6.7, 6.8_

- [ ] 8. 状态管理架构优化
  - [ ] 8.1 定义状态管理模式和最佳实践
    - 创建 `frontend/lib/state/README.md` 文档
    - 明确局部状态（StatefulWidget）和全局状态（Provider/Riverpod）的使用场景
    - 定义异步状态管理模式（FutureProvider/StreamProvider）
    - 提供状态管理代码示例和反模式警告
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [ ] 8.2 创建不可变状态类模板
    - 使用 Freezed 定义标准状态类模板
    - 创建 AsyncValue、ThemeState、NavigationState 等核心状态类
    - 为所有状态类添加 copyWith 和 equality 支持
    - 提供代码生成脚本和使用文档
    - _Requirements: 8.7_

  - [ ] 8.3 优化状态更新和性能
    - 审计所有 Provider 使用，识别不必要的重建
    - 使用 select 或 Selector 优化局部更新
    - 避免在 build 方法中执行副作用操作
    - 为所有状态变更添加可追踪日志（开发模式）
    - _Requirements: 8.4, 8.5, 8.8_

- [ ] 9. 性能优化与资源管理
  - [ ] 9.1 优化列表和网格渲染
    - 将所有长列表替换为 ListView.builder（虚拟滚动）
    - 为所有列表项使用 const 构造函数
    - 添加 RepaintBoundary 到复杂列表项
    - 优化 GridView 的 childAspectRatio 和缓存策略
    - _Requirements: 7.4, 7.9_
  
  - [ ] 9.2 实现图片懒加载和缓存
    - 审计所有 Image 组件使用
    - 实现图片懒加载策略（进入视口时加载）
    - 配置图片缓存策略（内存缓存 + 磁盘缓存）
    - 添加图片加载占位符和错误处理
    - _Requirements: 7.5_
  
  - [ ] 9.3 优化应用启动性能
    - 分析应用启动流程，识别性能瓶颈
    - 实现关键资源的预加载策略
    - 延迟加载非关键模块（deferred loading）
    - 优化 Rust FFI 桥接的初始化时间
    - 目标：冷启动 < 3 秒，热启动 < 1 秒
    - _Requirements: 7.1, 7.2, 7.6_
  
  - [ ] 9.4 使用 Isolate 处理耗时任务
    - 识别所有阻塞 UI 线程的计算任务
    - 将耗时计算迁移到 Isolate
    - 实现 Isolate 通信和结果回传机制
    - 确保主界面渲染帧率稳定在 60fps
    - _Requirements: 7.3, 7.10_

- [ ] 10. 国际化与本地化完善
  - [ ] 10.1 建立 Flutter intl 国际化架构
    - 配置 flutter_intl 包和 l10n.yaml
    - 创建 `frontend/lib/l10n/app_en.arb` 和 `app_zh.arb`
    - 定义翻译键命名规范（feature.component.action 格式）
    - 生成类型安全的 AppLocalizations 类
    - _Requirements: 9.1, 9.2, 9.8_
  
  - [ ] 10.2 提取和迁移硬编码文本
    - 扫描所有 .dart 文件，识别硬编码的用户可见文本
    - 将硬编码文本提取到 .arb 文件
    - 替换为 AppLocalizations.of(context).xxx 调用
    - 确保所有用户可见文本都已国际化
    - _Requirements: 9.3_
  
  - [ ] 10.3 实现日期、时间、数字本地化
    - 使用 intl 包的 DateFormat、NumberFormat
    - 支持中文和英文的日期时间格式
    - 支持数字、货币的本地化显示
    - 支持复数形式和性别变化的本地化
    - _Requirements: 9.4, 9.5_
  
  - [ ] 10.4 实现语言切换和 RTL 预留
    - 实现语言切换功能（设置页面）
    - 确保语言切换后立即更新所有界面文本
    - 为 RTL 语言预留布局镜像支持（Directionality widget）
    - 创建翻译缺失检测工具
    - _Requirements: 9.6, 9.7, 9.9_

- [ ] 11. 错误处理与降级策略
  - [ ] 11.1 统一错误处理架构
    - 创建 `frontend/lib/utils/error_handling.dart`
    - 实现全局异常捕获和日志记录
    - 定义错误类型分类（网络、权限、验证、服务器）
    - 为每种错误类型提供友好的用户提示
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ] 11.2 实现降级策略和缓存
    - 为关键功能实现降级方案
    - 在数据加载失败时显示缓存数据（标记为过期）
    - 实现离线模式支持（本地数据优先）
    - 为所有错误提供唯一的错误代码
    - _Requirements: 10.6, 10.7, 10.9_
  
  - [ ] 11.3 优化错误信息展示
    - 确保所有错误使用 describeUserVisibleApiErrorResolved
    - 避免向用户显示技术性错误信息（堆栈跟踪、异常类型）
    - 为字段级验证错误提供具体提示
    - 在开发模式下提供详细的错误信息和调试工具
    - _Requirements: 10.8, 10.10_

- [ ] 12. Checkpoint - 验证 P1 组件和优化
  - 运行 `flutter analyze` 确保无静态分析错误
  - 运行 `flutter test` 确保所有测试通过
  - 手动测试所有新增组件的交互状态
  - 验证键盘导航和屏幕阅读器支持
  - 使用性能分析工具验证启动时间和帧率
  - 测试语言切换功能
  - 验证错误处理和降级策略
  - 确认所有改动符合 AGENTS.md 约定（单文件 ≤800 行）

### P2: 高级功能与体验优化（Phase 13-20）

- [ ] 13. 导航与路由架构优化
  - [ ] 13.1 实现声明式路由系统
    - 配置 GoRouter 或 Navigator 2.0
    - 定义所有路由路径和参数
    - 实现嵌套路由和子路由
    - 支持路由参数和查询参数
    - _Requirements: 14.1, 14.4, 14.5_
  
  - [ ] 13.2 实现深度链接和路由守卫
    - 配置深度链接（Deep Links）支持
    - 实现路由守卫（权限检查、登录验证）
    - 支持浏览器前进后退按钮（Web 平台）
    - 实现 404 页面和错误路由处理
    - _Requirements: 14.2, 14.3, 14.6, 14.8_

  - [ ] 13.3 实现路由过渡动画
    - 为页面切换添加过渡动画
    - 使用 StudioMotion.pageTransition 时长
    - 支持平台特定的过渡效果（iOS 滑动、Android 淡入淡出）
    - 保持导航历史栈的正确性
    - _Requirements: 14.7, 14.9, 14.10_

- [ ] 14. 表单处理与验证优化
  - [ ] 14.1 创建表单管理系统
    - 创建 `frontend/lib/utils/form_management.dart`
    - 基于 Form 和 FormField 实现表单状态管理
    - 支持实时验证和提交时验证
    - 实现字段级和表单级验证规则
    - _Requirements: 15.1, 15.2, 15.4_
  
  - [ ] 14.2 实现表单验证和错误处理
    - 创建 `frontend/lib/utils/validators.dart`
    - 实现常见验证规则（必填、邮箱、长度、正则）
    - 为所有输入字段提供清晰的错误提示
    - 在验证失败时自动聚焦到第一个错误字段
    - _Requirements: 15.3, 15.5_
  
  - [ ] 14.3 实现表单提交和自动保存
    - 在提交时禁用表单并显示加载状态
    - 支持异步验证（如用户名唯一性检查）
    - 实现表单数据的自动保存和恢复
    - 支持键盘快捷键（Enter 提交、Esc 取消）
    - _Requirements: 15.6, 15.7, 15.8, 15.9, 15.10_

- [ ] 15. 数据展示组件（Tier 3）
  - [ ] 15.1 创建 StudioTable 组件
    - 创建 `frontend/lib/design_system/components/data/studio_table.dart`
    - 支持排序、筛选、分页
    - 实现固定表头和列
    - 支持行选择和批量操作
    - _Requirements: 2.3_

  - [ ] 15.2 创建 StudioList 和 StudioGrid 组件
    - 创建 `frontend/lib/design_system/components/data/studio_list.dart`
    - 创建 `frontend/lib/design_system/components/data/studio_grid.dart`
    - 支持虚拟滚动和懒加载
    - 实现选中状态和多选
    - 集成 StudioListSkeleton 和 StudioGridSkeleton
    - _Requirements: 2.3_
  
  - [ ] 15.3 创建 StudioTree 和 StudioTimeline 组件
    - 创建 `frontend/lib/design_system/components/data/studio_tree.dart`
    - 创建 `frontend/lib/design_system/components/data/studio_timeline.dart`
    - 支持展开/折叠和节点操作
    - 实现时间轴的时间标记和事件卡片
    - _Requirements: 2.3_

- [ ] 16. 导航组件（Tier 4）
  - [ ] 16.1 创建 StudioTabs 组件
    - 创建 `frontend/lib/design_system/components/navigation/studio_tabs.dart`
    - 支持水平和垂直标签页
    - 实现标签页切换动画
    - 支持键盘导航（Arrow 键、Home、End）
    - _Requirements: 2.4_
  
  - [ ] 16.2 创建 StudioBreadcrumb 和 StudioPagination 组件
    - 创建 `frontend/lib/design_system/components/navigation/studio_breadcrumb.dart`
    - 创建 `frontend/lib/design_system/components/navigation/studio_pagination.dart`
    - 实现面包屑导航和页码跳转
    - 支持省略号和快速跳转
    - _Requirements: 2.4_
  
  - [ ] 16.3 创建 StudioStepper 组件
    - 创建 `frontend/lib/design_system/components/navigation/studio_stepper.dart`
    - 支持水平和垂直步骤条
    - 实现步骤状态（待完成、进行中、已完成、错误）
    - 支持步骤跳转和验证
    - _Requirements: 2.4_

- [ ] 17. 数据可视化与图表优化
  - [ ] 17.1 选择和集成图表库
    - 评估 fl_chart、charts_flutter 等图表库
    - 选择最适合项目需求的图表库
    - 配置图表库并创建包装组件
    - 定义图表主题（基于 StudioTokens）
    - _Requirements: 16.1, 16.2_
  
  - [ ] 17.2 创建 StudioChart 组件系列
    - 创建 `frontend/lib/design_system/components/data/studio_chart.dart`
    - 实现折线图、柱状图、饼图、散点图
    - 支持图表交互（悬停提示、点击详情、缩放平移）
    - 实现响应式图表（自适应容器尺寸）
    - _Requirements: 16.1, 16.3, 16.4_
  
  - [ ] 17.3 优化图表性能和无障碍
    - 优化大数据集的渲染性能
    - 为图表提供无障碍替代（数据表格、文本描述）
    - 支持图表导出（PNG、SVG、CSV）
    - 实现图表动画（数据更新时的过渡动画）
    - _Requirements: 16.5, 16.6, 16.7, 16.8_

- [ ] 18. 搜索与过滤功能优化
  - [ ] 18.1 实现全局搜索系统
    - 创建 `frontend/lib/features/search/global_search.dart`
    - 实现全局搜索快捷键（Cmd/Ctrl+K）
    - 支持实时搜索建议（自动完成）
    - 实现搜索历史记录
    - _Requirements: 17.1, 17.2, 17.3, 17.10_
  
  - [ ] 18.2 实现高级过滤系统
    - 创建 `frontend/lib/features/search/advanced_filter.dart`
    - 支持多条件组合过滤
    - 实现日期范围、标签、分类过滤
    - 支持过滤条件的保存和恢复
    - _Requirements: 17.4_

  - [ ] 18.3 优化搜索性能和体验
    - 实现搜索防抖（debounce）优化性能
    - 高亮显示搜索结果中的匹配文本
    - 支持模糊搜索和精确搜索
    - 在搜索无结果时提供建议或引导
    - 支持搜索结果排序（相关性、时间、名称）
    - _Requirements: 17.5, 17.6, 17.7, 17.8, 17.9_

- [ ] 19. 通知与消息系统优化
  - [ ] 19.1 实现通知队列管理
    - 创建 `frontend/lib/features/notifications/notification_manager.dart`
    - 实现通知队列（避免同时显示多个通知）
    - 支持通知优先级（高优先级不自动关闭）
    - 实现通知历史记录
    - _Requirements: 18.5, 18.6_
  
  - [ ] 19.2 实现通知偏好设置
    - 创建通知设置页面
    - 支持静音和免打扰时段
    - 支持按类型配置通知行为
    - 实现通知权限请求
    - _Requirements: 18.7_
  
  - [ ] 19.3 集成桌面原生通知
    - 配置 flutter_local_notifications 包
    - 实现桌面原生通知（macOS、Windows、Linux）
    - 支持通知点击跳转到相关页面
    - 确保通知在应用后台时也能显示
    - _Requirements: 18.10_

- [ ] 20. 文件上传与下载优化
  - [ ] 20.1 实现拖拽上传功能
    - 创建 `frontend/lib/features/file_transfer/drag_drop_upload.dart`
    - 实现拖拽区域和视觉反馈
    - 支持文件类型和大小限制
    - 在上传前预览文件（图片、视频）
    - _Requirements: 19.1, 19.7, 19.8_

  - [ ] 20.2 实现批量上传和进度管理
    - 支持批量文件选择和上传
    - 显示实时进度（百分比、速度、剩余时间）
    - 支持暂停、恢复、取消传输
    - 在传输失败时提供重试选项
    - _Requirements: 19.2, 19.3, 19.4, 19.5, 19.6_
  
  - [ ] 20.3 实现后台传输和通知
    - 支持后台传输（不阻塞 UI）
    - 在传输完成时提供通知
    - 实现传输队列管理
    - 支持批量下载
    - _Requirements: 19.9, 19.10_

- [ ] 21. 主题与暗色模式优化
  - [ ] 21.1 完善暗色模式支持
    - 审计所有组件在暗色模式下的表现
    - 确保所有组件在两种主题下都清晰可读
    - 验证暗色模式下的对比度符合无障碍标准
    - 优化图片和图标在两种主题下的适配
    - _Requirements: 20.1, 20.5, 20.6, 20.9_
  
  - [ ] 21.2 实现主题切换功能
    - 创建主题设置页面
    - 支持亮色、暗色、跟随系统三种模式
    - 实现主题切换的平滑过渡动画
    - 保存用户的主题偏好设置
    - _Requirements: 20.2, 20.3, 20.4, 20.7_
  
  - [ ] 21.3 预留自定义主题扩展
    - 设计自定义主题颜色的架构
    - 为未来的主题自定义功能预留接口
    - 实现主题切换键盘快捷键
    - 创建主题预览功能
    - _Requirements: 20.8, 20.10_

- [ ] 22. 测试覆盖与质量保障
  - [ ] 22.1 建立单元测试框架
    - 为所有业务逻辑编写单元测试
    - 使用 Mockito 模拟外部依赖
    - 为所有状态管理逻辑编写测试
    - 目标：业务逻辑代码覆盖率达到 80%
    - _Requirements: 11.1, 11.5, 11.7_
  
  - [ ] 22.2 建立 Widget 测试框架
    - 为所有可复用组件编写 Widget 测试
    - 测试组件的交互状态和边界情况
    - 为所有异步操作编写测试（使用 pumpAndSettle）
    - 为所有错误处理路径编写测试
    - _Requirements: 11.3, 11.6, 11.8_
  
  - [ ] 22.3 建立 Golden 测试和集成测试
    - 使用 Golden 测试验证关键界面的视觉一致性
    - 为所有关键用户流程编写集成测试
    - 配置 CI 自动运行所有测试
    - 在测试失败时阻止代码合并
    - _Requirements: 11.2, 11.4, 11.9, 11.10_

- [ ] 23. 代码质量与可维护性
  - [ ] 23.1 配置代码质量工具
    - 配置 Dart Analyzer 和 analysis_options.yaml
    - 配置 dart format 自动格式化
    - 配置 CI 自动运行 flutter analyze
    - 配置 CI 自动检查代码格式
    - _Requirements: 12.2, 12.9, 12.10_
  
  - [ ] 23.2 重构超长文件和函数
    - 扫描所有超过 800 行的文件
    - 将超长文件拆分为多个模块
    - 重构超过 50 行的函数
    - 确保所有类的职责单一且清晰
    - _Requirements: 12.3, 12.4, 12.5_

  - [ ] 23.3 完善代码文档
    - 为所有公共 API 添加文档注释
    - 避免使用 dynamic 类型（除非必要）
    - 使用 const 构造函数优化性能
    - 生成 Dart 文档（dartdoc）
    - _Requirements: 12.6, 12.7, 12.8_

- [ ] 24. 跨平台一致性保障
  - [ ] 24.1 实现平台特定功能适配
    - 为桌面端添加鼠标悬停和右键菜单支持
    - 为移动端添加触摸手势支持（滑动、捏合、长按）
    - 为 Web 端添加浏览器前进后退导航支持
    - 使用条件编译隔离平台特定代码（dart:io、dart:html）
    - _Requirements: 13.4, 13.5, 13.6, 13.7_
  
  - [ ] 24.2 统一跨平台设计系统
    - 确保桌面、Web 和移动端使用相同的设计系统
    - 确保核心功能在所有平台上可用
    - 为平台特定功能提供优雅的降级方案
    - 在所有平台上使用相同的颜色、字体和间距
    - _Requirements: 13.1, 13.2, 13.3, 13.9_
  
  - [ ] 24.3 实现跨平台键盘快捷键
    - 定义统一的键盘快捷键映射
    - 考虑平台差异（Cmd vs Ctrl、Option vs Alt）
    - 实现快捷键帮助页面
    - 配置 CI 在所有目标平台上运行构建和测试
    - _Requirements: 13.8, 13.10_

- [ ] 25. Checkpoint - 验证 P2 高级功能
  - 运行 `flutter analyze` 确保无静态分析错误
  - 运行 `flutter test` 确保所有测试通过
  - 手动测试所有高级功能（导航、表单、图表、搜索、通知、文件传输）
  - 验证主题切换和暗色模式
  - 验证跨平台一致性（桌面、Web、移动）
  - 检查代码质量指标（覆盖率、复杂度、文档完整性）
  - 确认所有改动符合 AGENTS.md 约定（单文件 ≤800 行）


### 工程化与文档（Phase 21-25）

- [ ] 26. 工程化流程与自动化
  - [ ] 26.1 完善 CI/CD 流程
    - 配置 GitHub Actions 或 GitLab CI
    - 在每次提交时自动运行 flutter analyze
    - 在每次提交时自动运行 flutter test
    - 在每次提交时自动检查代码格式和测试覆盖率
    - 在每次提交时自动构建所有目标平台
    - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5, 23.6_
  
  - [ ] 26.2 创建代码生成工具
    - 创建组件模板生成脚本
    - 创建路由生成脚本
    - 创建状态管理模板生成脚本
    - 创建国际化文本提取和验证工具
    - _Requirements: 23.7, 23.10_
  
  - [ ] 26.3 创建性能分析工具
    - 创建启动性能分析脚本
    - 创建内存占用分析工具
    - 创建构建产物大小分析工具
    - 提供性能优化建议工具
    - _Requirements: 23.9_

- [ ] 27. 文档与知识管理
  - [ ] 27.1 创建架构设计文档
    - 编写系统架构文档（模块划分、依赖关系）
    - 编写技术选型文档（状态管理、路由、国际化）
    - 编写数据流文档（API 调用、状态更新、UI 渲染）
    - 创建架构决策记录（ADR）
    - _Requirements: 24.1_
  
  - [ ] 27.2 完善设计系统文档
    - 编写设计系统使用指南（颜色、字体、间距、组件）
    - 为所有组件创建使用示例和 API 文档
    - 创建设计系统 Storybook 或组件预览工具
    - 生成设计系统文档网站
    - _Requirements: 24.2, 2.6, 2.8_

  - [ ] 27.3 创建开发指南和测试指南
    - 编写环境搭建指南（Flutter SDK、依赖安装、IDE 配置）
    - 编写编码规范（命名、格式、注释、最佳实践）
    - 编写提交规范（commit message、PR 模板）
    - 编写测试指南（单元测试、Widget 测试、集成测试）
    - _Requirements: 24.3, 24.4_
  
  - [ ] 27.4 创建部署和故障排查指南
    - 编写构建流程文档（debug、profile、release）
    - 编写发布流程文档（版本管理、发布检查清单）
    - 编写故障排查指南（常见问题、调试技巧）
    - 生成 API 文档（dartdoc）
    - _Requirements: 24.5, 24.6, 24.7, 24.8, 24.9_

- [ ] 28. 监控与反馈机制
  - [ ] 28.1 建立重构进度跟踪系统
    - 创建重构进度仪表板
    - 跟踪已完成、进行中、待开始的阶段
    - 生成周报和月报展示重构成果
    - 提供趋势分析（指标随时间的变化）
    - _Requirements: 25.1, 25.5, 25.6_
  
  - [ ] 28.2 建立代码质量监控
    - 跟踪测试覆盖率指标
    - 跟踪代码复杂度指标
    - 跟踪技术债务指标
    - 在指标异常时发送告警
    - _Requirements: 25.2, 25.7_
  
  - [ ] 28.3 建立性能监控
    - 跟踪应用启动时间
    - 跟踪主界面渲染帧率
    - 跟踪内存占用
    - 跟踪构建时间
    - _Requirements: 25.3_
  
  - [ ] 28.4 建立用户体验监控
    - 跟踪页面加载时间
    - 跟踪交互响应时间
    - 跟踪错误率
    - 收集用户反馈（满意度调查、问题报告）
    - _Requirements: 25.4, 25.9, 25.10_

- [ ] 29. 最终验收与优化
  - [ ] 29.1 全面性能测试
    - 验证应用冷启动时间 < 3 秒
    - 验证应用热启动时间 < 1 秒
    - 验证主界面渲染帧率稳定在 60fps
    - 验证内存占用在正常使用下 < 500MB
    - _Requirements: 7.1, 7.2, 7.3, 7.7_
  
  - [ ] 29.2 全面无障碍测试
    - 使用屏幕阅读器测试所有关键流程
    - 验证所有交互元素支持键盘导航
    - 验证所有文本与背景的对比度符合 WCAG 2.1 AA
    - 验证所有动态内容更新有 ARIA live region 公告
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 6.10_
  
  - [ ] 29.3 全面跨平台测试
    - 在 macOS、Windows、Linux 桌面平台测试
    - 在 Chrome、Safari、Firefox 浏览器测试
    - 在 iOS 和 Android 移动平台测试
    - 验证所有平台的功能一致性和视觉一致性
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8, 13.9, 13.10_
  
  - [ ] 29.4 全面代码质量审查
    - 验证测试覆盖率达到 80%
    - 验证所有文件长度 ≤ 800 行
    - 验证所有函数长度 ≤ 50 行
    - 验证所有公共 API 有文档注释
    - _Requirements: 11.1, 12.3, 12.4, 12.6_
  
  - [ ] 29.5 生成最终报告
    - 生成重构完成报告（完成的任务、改进的指标）
    - 生成已知问题清单（遗留问题、技术债务）
    - 生成后续优化建议（性能优化、功能增强）
    - 组织团队回顾会议（经验总结、流程改进）
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5, 22.6, 22.7, 22.8_

- [ ] 30. Final Checkpoint - 宣布完成
  - 运行 `yarn refactor:agent --full` 进行全量门禁检查
  - 确保所有测试通过、代码质量达标
  - 确认所有 P0 和 P1 任务已完成
  - 确认所有文档已更新
  - 准备发布说明和迁移指南
  - 组织团队培训和知识分享


## Notes

### 优先级说明

- **P0（关键）**: 设计系统核心、响应式架构、异步加载标准化 - 必须优先完成，是后续工作的基础
- **P1（重要）**: 组件库完善、交互优化、性能优化、国际化 - 显著提升用户体验和开发效率
- **P2（优化）**: 高级功能、数据可视化、搜索过滤、文件传输 - 锦上添花的功能增强

### 实施建议

1. **按优先级顺序执行**: 严格按照 P0 → P1 → P2 的顺序执行任务
2. **小步多次 commit**: 每完成一个子任务或一组相关改动就提交，遵循 AGENTS.md 约定
3. **持续验证**: 在每个 Checkpoint 任务处进行全面验证，确保质量
4. **文档同步**: 代码改动和文档更新同步进行，避免文档滞后
5. **测试先行**: 为关键功能编写测试，确保重构不破坏现有功能

### 依赖关系

- **设计系统 → 组件库 → 应用层**: 严格的单向依赖，下层变更会影响上层
- **异步加载模式**: 贯穿所有数据加载场景，需要在 P0 阶段统一
- **响应式系统**: 影响所有布局组件，需要在 P0 阶段完成
- **国际化系统**: 影响所有用户可见文本，建议在 P1 阶段早期完成

### 工作量估算

- **P0 任务**: 约 4-6 周（设计系统扩展 1 周、响应式优化 1 周、异步加载标准化 2-3 周、验证 1 周）
- **P1 任务**: 约 8-12 周（组件库 4-6 周、无障碍 1-2 周、性能优化 2-3 周、国际化 1-2 周）
- **P2 任务**: 约 6-10 周（导航路由 1-2 周、表单 1 周、数据展示 2-3 周、高级功能 2-4 周）
- **工程化与文档**: 约 2-4 周（贯穿整个重构过程，最后集中完善）

**总计**: 约 20-32 周（5-8 个月），具体取决于团队规模和并行度

### 风险与缓解

1. **范围蔓延**: 严格控制需求变更，新需求放入后续迭代
2. **技术债务**: 在重构过程中发现的技术债务记录到 backlog，不在本次重构中解决
3. **性能回归**: 在每个 Checkpoint 进行性能测试，及时发现和修复性能问题
4. **兼容性问题**: 在多平台测试，确保跨平台一致性
5. **团队协作**: 建立清晰的代码审查流程，确保代码质量和知识共享


## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1.1", "1.2", "1.3", "1.4"]
    },
    {
      "id": 1,
      "tasks": ["2.1", "2.2", "2.3"]
    },
    {
      "id": 2,
      "tasks": ["3.1"]
    },
    {
      "id": 3,
      "tasks": ["3.2", "3.3", "3.4"]
    },
    {
      "id": 4,
      "tasks": ["5.1", "5.2", "5.3", "5.4"]
    },
    {
      "id": 5,
      "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5"]
    },
    {
      "id": 6,
      "tasks": ["7.1", "7.2", "7.3"]
    },
    {
      "id": 7,
      "tasks": ["8.1", "8.2", "8.3"]
    },
    {
      "id": 8,
      "tasks": ["9.1", "9.2", "9.3", "9.4"]
    },
    {
      "id": 9,
      "tasks": ["10.1", "10.2", "10.3", "10.4"]
    },
    {
      "id": 10,
      "tasks": ["11.1", "11.2", "11.3"]
    },
    {
      "id": 11,
      "tasks": ["13.1", "13.2", "13.3"]
    },
    {
      "id": 12,
      "tasks": ["14.1", "14.2", "14.3"]
    },
    {
      "id": 13,
      "tasks": ["15.1", "15.2", "15.3"]
    },
    {
      "id": 14,
      "tasks": ["16.1", "16.2", "16.3"]
    },
    {
      "id": 15,
      "tasks": ["17.1", "17.2", "17.3"]
    },
    {
      "id": 16,
      "tasks": ["18.1", "18.2", "18.3"]
    },
    {
      "id": 17,
      "tasks": ["19.1", "19.2", "19.3"]
    },
    {
      "id": 18,
      "tasks": ["20.1", "20.2", "20.3"]
    },
    {
      "id": 19,
      "tasks": ["21.1", "21.2", "21.3"]
    },
    {
      "id": 20,
      "tasks": ["22.1", "22.2", "22.3"]
    },
    {
      "id": 21,
      "tasks": ["23.1", "23.2", "23.3"]
    },
    {
      "id": 22,
      "tasks": ["24.1", "24.2", "24.3"]
    },
    {
      "id": 23,
      "tasks": ["26.1", "26.2", "26.3"]
    },
    {
      "id": 24,
      "tasks": ["27.1", "27.2", "27.3", "27.4"]
    },
    {
      "id": 25,
      "tasks": ["28.1", "28.2", "28.3", "28.4"]
    },
    {
      "id": 26,
      "tasks": ["29.1", "29.2", "29.3", "29.4", "29.5"]
    }
  ]
}
```
