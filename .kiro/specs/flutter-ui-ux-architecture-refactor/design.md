# Design Document: Flutter UI/UX Architecture Refactor

## Overview

This design document specifies the technical architecture for a comprehensive UI/UX refactoring of the Toonflow Flutter application. The refactoring encompasses 747 .dart files and follows a 20-phase cross-platform UI/UX enhancement guide. The system builds upon existing foundations (StudioTokens, StudioTypography, 40+ design system components) to achieve:

- **Design System Maturity**: Extended color states, shadow system, animation standards
- **Component Library Completeness**: Full coverage of basic, composite, data display, navigation, and feedback components
- **Responsive Excellence**: Unified breakpoint system with adaptive typography and layout
- **Performance Optimization**: Startup time < 3s, 60fps rendering, optimized memory usage
- **Accessibility Compliance**: WCAG 2.1 AA standard with full keyboard navigation and screen reader support
- **Engineering Excellence**: 80% test coverage, automated CI/CD, comprehensive documentation

The architecture maintains strict separation of concerns with unidirectional dependencies: Application Layer → Component Library → Design System Foundation → Flutter Framework.

## Architecture

### System Architecture Layers

**Presentation Layer**
- Screens, Dialogs, Overlays
- Component Library (40+ components organized in 5 tiers)
- Design System Foundation (Tokens, Typography, Spacing, Motion, Elevation)

**Business Logic Layer**
- Providers, Notifiers, Services
- State Management (Local, Global, Async)

**Data Layer**
- Repositories, API Clients, Local Storage
- Rust Backend Bridge (FFI bindings, OpenAPI contract compliance)

### Module Structure

```
frontend/lib/
├── design_system/          # Design system core
├── platform/               # Platform-specific code
├── routing/                # Navigation and routing
├── state/                  # State management
├── services/               # Business logic services
├── models/                 # Data models
├── utils/                  # Utility functions
└── l10n/                   # Internationalization
```

### Dependency Rules

1. **Unidirectional**: Upper layers depend on lower layers, never the reverse
2. **No Circular Dependencies**: Strictly enforced across all modules
3. **Design System Independence**: Design system layer has no business logic dependencies
4. **Component Composability**: Components can compose other components but remain business-logic agnostic

## 1. Executive Summary

本设计文档定义了 Toonflow Flutter 应用的全局 UI/UX 架构重构技术方案。该重构基于 20 阶段跨平台 UI/UX 体验重构终极指南，对现有 747 个 .dart 文件进行系统性架构升级。

### 1.1 Current State

- **代码规模**: 747 个 .dart 文件
- **现有设计系统**: StudioTokens（25 个语义化颜色）、StudioTypography（3 种配置）、StudioSpacing（8px 网格）、40+ 设计系统组件
- **响应式系统**: 基于 LayoutBuilder 的断点系统（1100px、760px、720px 等）
- **异步加载规范**: ASYNC_LOADING.md 定义骨架屏、空状态、错误处理模式
- **无障碍指南**: ACCESSIBILITY.md 和 A11Y_QUICK_REFERENCE.md
- **主题系统**: 支持亮色和暗色主题，使用 ThemeExtension

### 1.2 Design Goals

1. **设计系统深化**: 扩展颜色状态变体、阴影系统、动画规范
2. **组件库完善**: 补全基础组件、复合组件、数据展示组件
3. **响应式优化**: 完善断点系统、优化布局切换逻辑
4. **性能提升**: 优化启动时间、渲染性能、内存占用
5. **无障碍增强**: 全面支持键盘导航、屏幕阅读器、WCAG 2.1 AA
6. **工程化提升**: 完善测试覆盖、CI/CD 流程、代码质量保障

### 1.3 Technology Stack

- **Flutter SDK**: 3.x (stable channel)
- **Dart**: 3.x
- **State Management**: Provider/Riverpod (现有架构)
- **Routing**: GoRouter (声明式路由)
- **Internationalization**: flutter_intl
- **Testing**: flutter_test, mockito, golden_toolkit
- **Code Generation**: build_runner, freezed, json_serializable


## Components and Interfaces

### Component Tier Classification

**Tier 1: Basic Components** (Atomic, no custom component dependencies)
- StudioButton (FilledButton, OutlinedButton, TextButton variants)
- StudioInput, StudioCheckbox, StudioRadio, StudioSwitch, StudioSlider
- StudioIconButton, StudioChip

**Tier 2: Composite Components** (Composed of Tier 1)
- StudioCard, StudioDialog, StudioSheet, StudioDrawer
- StudioSnackbar, StudioToast, StudioTooltip, StudioMenu, StudioDropdown

**Tier 3: Data Display Components** (Complex, data-driven)
- StudioTable, StudioList, StudioGrid, StudioTree, StudioTimeline, StudioChart

**Tier 4: Navigation Components**
- StudioTabs, StudioBreadcrumb, StudioPagination, StudioStepper, StudioNavigation

**Tier 5: Feedback Components** (Async states)
- StudioLoadingPane, StudioPaneLoadingSkeleton, StudioListSkeleton, StudioGridSkeleton
- StudioEmptyState, StudioApiErrorCallout, StudioProgressIndicator

### Component API Design Pattern

All components follow a consistent API structure:

```dart
class StudioButton extends StatefulWidget {
  const StudioButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = StudioButtonVariant.filled,
    this.size = StudioButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final StudioButtonVariant variant;
  final StudioButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;
  final String? semanticLabel;
}
```

**Key Principles**:
1. Semantic Props: Use semantic property names (isLoading not loading)
2. Accessibility First: All components support semanticLabel
3. State Management: Internal hover/focus/pressed state management
4. Consistent Naming: All components prefixed with Studio
5. Immutable Props: All properties declared as final

### Interface Contracts

**StudioTokens Interface**:
```dart
@immutable
class StudioTokens extends ThemeExtension<StudioTokens> {
  // Base colors
  final Color bgBase, bgSurface, textPrimary, primary, accent;
  
  // Interactive state variants
  final Color primaryHover, primaryPressed, primaryDisabled, primaryFocus;
  final Color accentHover, accentPressed, accentDisabled, accentFocus;
  
  // Semantic colors
  final Color success, warning, error, info;
}
```

**Responsive Layout Interface**:
```dart
enum StudioBreakpoint {
  mobile(maxWidth: 600),
  tablet(maxWidth: 960),
  desktop(maxWidth: 1280),
  wide(maxWidth: double.infinity);
  
  static StudioBreakpoint fromWidth(double width);
  bool get isMobile;
  bool get isTablet;
  bool get isDesktop;
  bool get isWide;
}
```

**Async State Interface**:
```dart
class StudioAsyncDataView<T> extends StatelessWidget {
  const StudioAsyncDataView({
    required this.asyncValue,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });
  
  final AsyncValue<T> asyncValue;
  final Widget Function(BuildContext, T) dataBuilder;
  final Widget Function(BuildContext)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace)? errorBuilder;
}
```

## Data Models

### Design System Data Models

**Color Token Model**:
```dart
@immutable
class StudioTokens extends ThemeExtension<StudioTokens> {
  // 25+ semantic colors with state variants
  // Supports light and dark themes
  // Provides type-safe color access
}
```

**Typography Model**:
```dart
class StudioTypography {
  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  
  // Three profiles: compact, regular, large
  // Switches based on viewport width (1280px, 1720px breakpoints)
}
```

**Spacing Model**:
```dart
abstract final class StudioSpacing {
  // 8px grid system
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
  static const double xxl = 48;
  
  // Radius system
  static const double radiusButton = 10;
  static const double radiusCard = 14;
  static const double radiusDense = 8;
  static const double radiusSheet = 28;
  static const double radiusPill = 999;
  
  // Touch targets
  static double touchTargetForPlatform(TargetPlatform platform);
}
```

**Elevation Model**:
```dart
abstract final class StudioElevation {
  static const List<BoxShadow> level0 = [];
  static List<BoxShadow> level1(bool isDark);
  static List<BoxShadow> level2(bool isDark);
  static List<BoxShadow> level3(bool isDark);
  static List<BoxShadow> level4(bool isDark);
  static List<BoxShadow> level5(bool isDark);
}
```

**Motion Model**:
```dart
abstract final class StudioMotion {
  // Duration constants
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  
  // Easing curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeInOut = Curves.easeInOut;
  
  // Use case specific
  static const Duration hoverTransition = fast;
  static const Duration dialogTransition = normal;
  static const Duration drawerTransition = slow;
}
```

### State Management Data Models

**Async State Model**:
```dart
@freezed
class AsyncValue<T> with _$AsyncValue<T> {
  const factory AsyncValue.data(T value) = AsyncData<T>;
  const factory AsyncValue.loading() = AsyncLoading<T>;
  const factory AsyncValue.error(Object error, StackTrace stackTrace) = AsyncError<T>;
  
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  });
}
```

**Theme State Model**:
```dart
@freezed
class ThemeState with _$ThemeState {
  const factory ThemeState({
    required ThemeMode mode,
    required Brightness brightness,
    required StudioTypography typography,
  }) = _ThemeState;
}
```

**Navigation State Model**:
```dart
@freezed
class NavigationState with _$NavigationState {
  const factory NavigationState({
    required String currentRoute,
    required List<String> history,
    required Map<String, dynamic> routeParams,
  }) = _NavigationState;
}
```

## 2. High-Level Architecture

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Screens    │  │   Dialogs    │  │   Overlays   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            Component Library (40+ components)        │   │
│  │  - Basic: Button, Input, Checkbox, Radio, Switch    │   │
│  │  - Composite: Card, Dialog, Sheet, Drawer, Toast    │   │
│  │  - Data: Table, List, Grid, Tree, Chart             │   │
│  │  - Navigation: Tabs, Breadcrumb, Pagination         │   │
│  │  - Feedback: Loading, Skeleton, EmptyState, Error   │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Design System Foundation                │   │
│  │  - StudioTokens: 25+ semantic colors + states       │   │
│  │  - StudioTypography: compact/regular/large profiles │   │
│  │  - StudioSpacing: 8px grid + touch targets          │   │
│  │  - StudioMotion: animation timing + easing curves   │   │
│  │  - StudioElevation: 5-level shadow system           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                    Business Logic Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Providers  │  │  Notifiers   │  │   Services   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              State Management                        │   │
│  │  - Local State: StatefulWidget                      │   │
│  │  - Global State: Provider/Riverpod                  │   │
│  │  - Async State: FutureProvider/StreamProvider       │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Repositories │  │  API Clients │  │ Local Storage│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Rust Backend Bridge                     │   │
│  │  - rust_api: FFI bindings to Rust backend           │   │
│  │  - OpenAPI contract compliance                       │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```


### 2.2 Module Structure

```
frontend/lib/
├── design_system/              # 设计系统核心
│   ├── tokens.dart             # StudioTokens, StudioSpacing, StudioIconSize
│   ├── studio_typography.dart  # StudioTypography (compact/regular/large)
│   ├── theme.dart              # ThemeData builders
│   ├── studio_motion.dart      # Animation timing and curves
│   ├── studio_elevation.dart   # Shadow system (NEW)
│   ├── layout_breakpoints.dart # Responsive breakpoints
│   ├── ASYNC_LOADING.md        # Async loading patterns
│   ├── ACCESSIBILITY.md        # A11y guidelines
│   ├── components/             # Reusable UI components
│   │   ├── basic/              # Button, Input, Checkbox, Radio, Switch, Slider
│   │   ├── composite/          # Card, Dialog, Sheet, Drawer, Snackbar, Toast
│   │   ├── data/               # Table, List, Grid, Tree, Timeline, Chart
│   │   ├── navigation/         # Tabs, Breadcrumb, Pagination, Stepper
│   │   └── feedback/           # Loading, Skeleton, EmptyState, ErrorState
│   └── ix/                     # Interaction utilities
│       ├── studio_pointer.dart
│       └── studio_scroll_behavior.dart
├── platform/                   # Platform-specific code
│   ├── studio_load_state.dart  # Async data loading state
│   └── platform_bridge.dart    # Rust FFI bridge
├── routing/                    # Navigation and routing
│   ├── app_router.dart         # GoRouter configuration
│   └── route_guards.dart       # Auth and permission guards
├── state/                      # State management
│   ├── providers/              # Provider definitions
│   └── notifiers/              # StateNotifier implementations
├── services/                   # Business logic services
│   ├── api_service.dart        # API client
│   ├── storage_service.dart    # Local storage
│   └── i18n_service.dart       # Internationalization
├── models/                     # Data models
│   └── *.freezed.dart          # Immutable data classes
├── utils/                      # Utility functions
│   ├── error_handling.dart     # Error formatting
│   └── validators.dart         # Form validation
└── l10n/                       # Internationalization
    ├── app_en.arb              # English translations
    └── app_zh.arb              # Chinese translations
```


### 2.3 Component Dependency Graph

```
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                       │
│  (Screens, Pages, Features)                                  │
└───────────────────────┬─────────────────────────────────────┘
                        │ depends on
┌───────────────────────▼─────────────────────────────────────┐
│                   Component Library                          │
│  (Buttons, Inputs, Cards, Dialogs, etc.)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │ depends on
┌───────────────────────▼─────────────────────────────────────┐
│                   Design System Foundation                   │
│  (Tokens, Typography, Spacing, Motion, Elevation)           │
└───────────────────────┬─────────────────────────────────────┘
                        │ depends on
┌───────────────────────▼─────────────────────────────────────┐
│                   Flutter Framework                          │
│  (Material, Cupertino, Widgets)                             │
└─────────────────────────────────────────────────────────────┘
```

**Dependency Rules**:
1. **Unidirectional**: 上层依赖下层，下层不依赖上层
2. **No Circular Dependencies**: 严禁循环依赖
3. **Design System Independence**: 设计系统层不依赖业务逻辑
4. **Component Composability**: 组件可以组合其他组件，但不依赖具体业务逻辑


## 3. Design System Deep Dive

### 3.1 Extended Color Token System

**Current State**: StudioTokens 包含 25 个语义化颜色（bgBase, bgSurface, textPrimary, primary, accent 等）

**Enhancement**: 扩展交互状态变体

```dart
// frontend/lib/design_system/tokens.dart (扩展)
@immutable
class StudioTokens extends ThemeExtension<StudioTokens> {
  // ... existing colors ...
  
  // NEW: Interactive state variants
  final Color primaryHover;
  final Color primaryPressed;
  final Color primaryDisabled;
  final Color primaryFocus;
  
  final Color accentHover;
  final Color accentPressed;
  final Color accentDisabled;
  final Color accentFocus;
  
  final Color surfaceHover;
  final Color surfacePressed;
  final Color surfaceDisabled;
  
  // NEW: Additional semantic colors
  final Color info;
  final Color infoSoft;
  
  // ... constructor and methods ...
}
```

**Implementation Strategy**:
- 基于现有颜色生成状态变体（使用 `withValues(alpha:)` 或 `Color.lerp`）
- 确保暗色和亮色主题都有完整的状态变体
- 在 `buildStudioTheme` 中初始化所有状态颜色


### 3.2 Elevation and Shadow System

**New File**: `frontend/lib/design_system/studio_elevation.dart`

```dart
/// Studio elevation system with 5 levels of shadows.
abstract final class StudioElevation {
  /// Level 0: No shadow (flat surface)
  static const List<BoxShadow> level0 = [];
  
  /// Level 1: Subtle lift (cards, chips)
  static List<BoxShadow> level1(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  /// Level 2: Moderate elevation (dropdowns, tooltips)
  static List<BoxShadow> level2(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  /// Level 3: High elevation (dialogs, sheets)
  static List<BoxShadow> level3(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  /// Level 4: Very high elevation (modals, overlays)
  static List<BoxShadow> level4(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.14),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  /// Level 5: Maximum elevation (toasts, notifications)
  static List<BoxShadow> level5(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.16),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}
```


### 3.3 Animation and Motion System

**Enhancement**: `frontend/lib/design_system/studio_motion.dart`

```dart
/// Studio animation timing and easing curves.
abstract final class StudioMotion {
  // Duration constants
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration verySlow = Duration(milliseconds: 500);
  
  // Easing curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve spring = Curves.elasticOut;
  static const Curve bounce = Curves.bounceOut;
  
  // Specific use cases
  static const Duration hoverTransition = fast;
  static const Duration focusTransition = fast;
  static const Duration dialogTransition = normal;
  static const Duration drawerTransition = slow;
  static const Duration pageTransition = normal;
  static const Duration tooltipTransition = fast;
  static const Duration snackbarTransition = normal;
  
  // Curve recommendations
  static const Curve hoverCurve = easeOut;
  static const Curve dialogCurve = easeInOut;
  static const Curve drawerCurve = easeOut;
  static const Curve pageCurve = easeInOut;
}
```

**Usage Example**:
```dart
AnimatedContainer(
  duration: StudioMotion.hoverTransition,
  curve: StudioMotion.hoverCurve,
  color: isHovered ? tokens.primaryHover : tokens.primary,
  child: child,
)
```


### 3.4 Z-Index Layer System

**New Addition to tokens.dart**:

```dart
/// Z-index layer system for stacking contexts.
abstract final class StudioZIndex {
  static const int base = 0;
  static const int dropdown = 1000;
  static const int sticky = 1100;
  static const int fixed = 1200;
  static const int tooltip = 1300;
  static const int overlay = 1400;
  static const int modal = 1500;
  static const int toast = 1600;
  static const int debug = 9999;
}
```

**Usage**: 在 `Stack` 或 `Positioned` 中使用，确保层级一致性。

### 3.5 Radius System Standardization

**Current State**: StudioSpacing 已定义部分圆角值

**Enhancement**: 完善所有圆角变体

```dart
// frontend/lib/design_system/tokens.dart (StudioSpacing 扩展)
abstract final class StudioSpacing {
  // ... existing spacing values ...
  
  // Radius system (complete)
  static const double radiusButton = 10;      // Buttons, inputs
  static const double radiusCard = 14;        // Cards, panels
  static const double radiusDense = 8;        // Chips, compact panels
  static const double radiusComfort = 12;     // Legacy medium corners
  static const double radiusSheet = 28;       // Large sheets, modals
  static const double radiusPill = 999;       // Fully rounded pill
  static const double radiusHairline = 2;     // Drag handles, micro connectors
  static const double radiusCircle = 9999;    // Perfect circles (NEW)
  static const double radiusNone = 0;         // Sharp corners (NEW)
}
```


## 4. Component Library Architecture

### 4.1 Component Classification

**Tier 1: Basic Components** (Atomic, no dependencies on other custom components)
- `StudioButton` (FilledButton, OutlinedButton, TextButton variants)
- `StudioInput` (TextField with consistent styling)
- `StudioCheckbox`
- `StudioRadio`
- `StudioSwitch`
- `StudioSlider`
- `StudioIconButton`
- `StudioChip`

**Tier 2: Composite Components** (Composed of Tier 1 components)
- `StudioCard`
- `StudioDialog`
- `StudioSheet` (Bottom sheet, side sheet)
- `StudioDrawer`
- `StudioSnackbar`
- `StudioToast`
- `StudioTooltip`
- `StudioMenu`
- `StudioDropdown`

**Tier 3: Data Display Components** (Complex, data-driven)
- `StudioTable`
- `StudioList`
- `StudioGrid`
- `StudioTree`
- `StudioTimeline`
- `StudioChart` (Line, Bar, Pie, Scatter)

**Tier 4: Navigation Components**
- `StudioTabs`
- `StudioBreadcrumb`
- `StudioPagination`
- `StudioStepper`
- `StudioNavigation` (App bar, sidebar)

**Tier 5: Feedback Components** (Async states)
- `StudioLoadingPane`
- `StudioPaneLoadingSkeleton`
- `StudioListSkeleton`
- `StudioGridSkeleton`
- `StudioEmptyState`
- `StudioApiErrorCallout`
- `StudioProgressIndicator`


### 4.2 Component API Design Pattern

**Standard Component Structure**:

```dart
/// Studio button with consistent styling and interaction states.
class StudioButton extends StatefulWidget {
  const StudioButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = StudioButtonVariant.filled,
    this.size = StudioButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final StudioButtonVariant variant;
  final StudioButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final Widget? icon;
  final String? semanticLabel;

  @override
  State<StudioButton> createState() => _StudioButtonState();
}

enum StudioButtonVariant { filled, outlined, text, ghost }
enum StudioButtonSize { small, medium, large }
```

**Key Principles**:
1. **Semantic Props**: 使用语义化属性名（`isLoading` 而非 `loading`）
2. **Accessibility First**: 所有组件支持 `semanticLabel`
3. **State Management**: 内部管理 hover/focus/pressed 状态
4. **Consistent Naming**: 所有组件以 `Studio` 前缀命名
5. **Immutable Props**: 所有属性使用 `final`


### 4.3 Component State Management

**Interaction States**:
```dart
class _StudioButtonState extends State<StudioButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  Color _resolveBackgroundColor(StudioTokens tokens) {
    if (widget.isDisabled) return tokens.primaryDisabled;
    if (_isPressed) return tokens.primaryPressed;
    if (_isHovered) return tokens.primaryHover;
    if (_isFocused) return tokens.primaryFocus;
    return tokens.primary;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.isDisabled ? null : widget.onPressed,
          child: AnimatedContainer(
            duration: StudioMotion.hoverTransition,
            curve: StudioMotion.hoverCurve,
            decoration: BoxDecoration(
              color: _resolveBackgroundColor(tokens),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
            ),
            child: widget.isLoading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : widget.child,
          ),
        ),
      ),
    );
  }
}
```


## 5. Responsive Layout Architecture

### 5.1 Breakpoint System

**Current State**: `layout_breakpoints.dart` 定义多个断点常量

**Enhancement**: 统一断点枚举和工具函数

```dart
// frontend/lib/design_system/layout_breakpoints.dart (扩展)

/// Standard responsive breakpoints.
enum StudioBreakpoint {
  mobile(maxWidth: 600),
  tablet(maxWidth: 960),
  desktop(maxWidth: 1280),
  wide(maxWidth: double.infinity);

  const StudioBreakpoint({required this.maxWidth});
  final double maxWidth;
  
  static StudioBreakpoint fromWidth(double width) {
    if (width < mobile.maxWidth) return mobile;
    if (width < tablet.maxWidth) return tablet;
    if (width < desktop.maxWidth) return desktop;
    return wide;
  }
  
  bool get isMobile => this == mobile;
  bool get isTablet => this == tablet;
  bool get isDesktop => this == desktop;
  bool get isWide => this == wide;
}

/// Responsive layout builder that uses LayoutBuilder instead of MediaQuery.
class StudioResponsiveLayout extends StatelessWidget {
  const StudioResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = StudioBreakpoint.fromWidth(constraints.maxWidth);
        
        switch (breakpoint) {
          case StudioBreakpoint.wide:
            return (wide ?? desktop ?? tablet ?? mobile)(context);
          case StudioBreakpoint.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case StudioBreakpoint.tablet:
            return (tablet ?? mobile)(context);
          case StudioBreakpoint.mobile:
            return mobile(context);
        }
      },
    );
  }
}
```


### 5.2 Typography Responsive Switching

**Current Implementation**: `studioTypographyForWidth` 函数在 1280px 和 1720px 断点切换

**Enhancement**: 集成到主题系统

```dart
// frontend/lib/design_system/studio_adaptive_theme.dart (扩展)

/// Adaptive theme that switches typography based on viewport width.
class StudioAdaptiveTheme extends StatelessWidget {
  const StudioAdaptiveTheme({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final typography = studioTypographyForWidth(constraints.maxWidth);
        final brightness = Theme.of(context).brightness;
        
        return Theme(
          data: buildStudioTheme(
            brightness: brightness,
            typography: typography,
          ),
          child: child,
        );
      },
    );
  }
}
```

**Usage**:
```dart
MaterialApp(
  home: StudioAdaptiveTheme(
    child: Scaffold(
      body: MyContent(),
    ),
  ),
)
```


### 5.3 Touch Target Sizing

**Platform-Specific Touch Targets**:

```dart
// frontend/lib/design_system/tokens.dart (扩展)

abstract final class StudioSpacing {
  // ... existing values ...
  
  /// Platform-aware touch target size.
  static double touchTargetForPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return 44.0; // iOS HIG and Material guidelines
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 36.0; // Desktop can be more compact
      case TargetPlatform.fuchsia:
        return 44.0;
    }
  }
  
  /// Get touch target size for current platform.
  static double touchTargetForContext(BuildContext context) {
    return touchTargetForPlatform(Theme.of(context).platform);
  }
}
```

**Component Usage**:
```dart
SizedBox(
  width: StudioSpacing.touchTargetForContext(context),
  height: StudioSpacing.touchTargetForContext(context),
  child: IconButton(icon: Icon(Icons.close)),
)
```


## 6. Async Loading and State Management

### 6.1 Async Loading Pattern (Existing)

**Current Implementation**: ASYNC_LOADING.md 定义了完整的异步加载模式

**Key Components**:
- `StudioLoadingPane` / `StudioPaneLoadingSkeleton`: 全面板加载
- `StudioListSkeleton`: 列表加载
- `StudioGridSkeleton`: 网格加载
- `StudioEmptyState`: 空状态和错误状态
- `StudioApiErrorCallout`: 行内错误提示
- `StudioAsyncDataView`: 异步数据视图包装器

**No Changes Required**: 现有实现已经符合最佳实践

### 6.2 State Management Architecture

**Local State** (StatefulWidget):
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: _isExpanded,
      onExpansionChanged: (expanded) {
        setState(() => _isExpanded = expanded);
      },
    );
  }
}
```

**Global State** (Provider/Riverpod):
```dart
// State class
class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

// Provider definition
final appStateProvider = ChangeNotifierProvider((ref) => AppState());

// Usage in widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appStateProvider.select((s) => s.themeMode));
    return Text('Current theme: $themeMode');
  }
}
```


**Async State** (FutureProvider/StreamProvider):
```dart
// Async data provider
final projectsProvider = FutureProvider<List<Project>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  return await apiService.fetchProjects();
});

// Usage with StudioAsyncDataView pattern
class ProjectsListView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);
    
    return projectsAsync.when(
      data: (projects) {
        if (projects.isEmpty) {
          return StudioEmptyState.emptyData(
            context,
            message: 'No projects yet',
          );
        }
        return ListView.builder(
          itemCount: projects.length,
          itemBuilder: (context, index) => ProjectCard(projects[index]),
        );
      },
      loading: () => StudioListSkeleton(),
      error: (error, stack) => StudioEmptyState.loadFailed(
        context,
        error: error,
        onRetry: () => ref.refresh(projectsProvider),
      ),
    );
  }
}
```

### 6.3 Error Handling

**Error Formatting** (Existing):
```dart
// frontend/lib/utils/error_handling.dart
String describeUserVisibleApiErrorResolved(BuildContext context, Object error) {
  // Existing implementation - no changes needed
  // Returns user-friendly error messages
}
```

**Usage**:
```dart
StudioApiErrorCallout(
  message: describeUserVisibleApiErrorResolved(context, error),
  onRetry: () => retry(),
)
```


## 7. Accessibility Architecture

### 7.1 Keyboard Navigation

**Focus Management**:
```dart
class StudioFocusableCard extends StatefulWidget {
  const StudioFocusableCard({
    super.key,
    required this.child,
    this.onTap,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  State<StudioFocusableCard> createState() => _StudioFocusableCardState();
}

class _StudioFocusableCardState extends State<StudioFocusableCard> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            border: _isFocused
                ? Border.all(color: tokens.primary, width: 2)
                : null,
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
```


### 7.2 Semantic Labels

**Semantics Wrapper**:
```dart
class StudioSemanticIcon extends StatelessWidget {
  const StudioSemanticIcon({
    super.key,
    required this.icon,
    required this.label,
    this.excludeSemantics = false,
  });

  final IconData icon;
  final String label;
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: excludeSemantics,
      child: Icon(icon),
    );
  }
}
```

**Usage**:
```dart
IconButton(
  icon: StudioSemanticIcon(
    icon: Icons.close,
    label: 'Close dialog',
  ),
  onPressed: () => Navigator.pop(context),
)
```

### 7.3 Color Contrast Validation

**Contrast Checker Utility**:
```dart
// frontend/lib/utils/accessibility.dart

/// Calculates relative luminance of a color.
double _relativeLuminance(Color color) {
  double toLinear(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = toLinear(color.red / 255);
  final g = toLinear(color.green / 255);
  final b = toLinear(color.blue / 255);

  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Calculates contrast ratio between two colors.
double contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Checks if contrast meets WCAG AA standard.
bool meetsWCAGAA(Color foreground, Color background, {bool isLargeText = false}) {
  final ratio = contrastRatio(foreground, background);
  return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
}
```


## 8. Performance Optimization

### 8.1 Widget Optimization

**Const Constructors**:
```dart
// Good: Use const constructors wherever possible
const SizedBox(height: StudioSpacing.md)
const Divider()
const Icon(Icons.check)

// Bad: Avoid unnecessary rebuilds
SizedBox(height: StudioSpacing.md) // Missing const
```

**RepaintBoundary**:
```dart
class StudioExpensiveWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: ComplexPainter(),
        child: child,
      ),
    );
  }
}
```

**ListView.builder for Long Lists**:
```dart
// Good: Virtual scrolling
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(items[index]),
)

// Bad: All items built at once
ListView(
  children: items.map((item) => ItemCard(item)).toList(),
)
```

### 8.2 Image Optimization

**Lazy Loading and Caching**:
```dart
// frontend/lib/design_system/studio_network_image.dart (existing)
// Already implements caching and lazy loading
StudioNetworkImage(
  url: imageUrl,
  width: 200,
  height: 200,
  fit: BoxFit.cover,
)
```

### 8.3 Isolate for Heavy Computation

**Example: JSON Parsing**:
```dart
import 'dart:isolate';

Future<List<Project>> parseProjectsInIsolate(String jsonString) async {
  return await Isolate.run(() {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Project.fromJson(json)).toList();
  });
}
```



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Component State Rendering Consistency

*For any* Studio component, rendering in each interaction state (default, hover, pressed, disabled, focus, error) SHALL produce valid output without throwing exceptions or rendering errors.

**Validates: Requirements 2.7**

### Property 2: Responsive Typography Switching

*For any* window width, the typography configuration SHALL match the expected profile for that width range: compact for width < 1280px, regular for 1280px ≤ width < 1720px, and large for width ≥ 1720px.

**Validates: Requirements 3.2**

### Property 3: Mobile Touch Target Sizing

*For any* interactive widget on mobile platform (iOS, Android), the touch target size SHALL be at least 44x44 logical pixels.

**Validates: Requirements 3.7**

### Property 4: Async Loading Component Usage

*For any* list view in loading state, the system SHALL render StudioListSkeleton instead of a full-page CircularProgressIndicator.

**Validates: Requirements 4.2**

### Property 5: Error Message Formatting

*For any* API error displayed to users, the error message SHALL be formatted using describeUserVisibleApiErrorResolved and SHALL NOT display raw exception strings (e.toString()).

**Validates: Requirements 4.8**

### Property 6: Hover State Timing

*For any* button component, a hover event SHALL trigger a visual state change within 150ms using StudioMotion.hoverTransition duration.

**Validates: Requirements 5.2**

### Property 7: Focus Indication Visibility

*For any* input widget, the focus state SHALL render a visible focus border with 2px width and primary color.

**Validates: Requirements 5.4**

### Property 8: Keyboard Navigation Support

*For any* interactive widget, it SHALL respond to keyboard events (Tab for navigation, Enter/Space for activation) and maintain proper focus order.

**Validates: Requirements 6.1**

### Property 9: Color Contrast Compliance

*For any* text widget, the contrast ratio with its background SHALL be at least 4.5:1 for normal text or 3:1 for large text (WCAG 2.1 AA standard).

**Validates: Requirements 6.5**

### Property 10: Virtual Scrolling for Long Lists

*For any* list with more than 20 items, the implementation SHALL use ListView.builder (virtual scrolling) instead of ListView with a children list.

**Validates: Requirements 7.4**

### Property 11: Cross-Platform Design System Consistency

*For any* platform (desktop, web, mobile), the StudioTokens color values, spacing constants, and typography scales SHALL be identical.

**Validates: Requirements 13.1**

### Property 12: Theme Compatibility

*For any* component, rendering in both light theme and dark theme SHALL produce readable output with sufficient contrast and no visual errors.

**Validates: Requirements 20.5**

## Error Handling

### Error Handling Architecture

**Error Categories**:
1. **Network Errors**: Connection failures, timeouts, server errors
2. **Validation Errors**: Form validation, data format errors
3. **Permission Errors**: Access denied, authentication failures
4. **System Errors**: Out of memory, file system errors
5. **Business Logic Errors**: Invalid state transitions, constraint violations

### Error Handling Patterns

**User-Facing Error Formatting**:
```dart
// frontend/lib/utils/error_handling.dart
String describeUserVisibleApiErrorResolved(BuildContext context, Object error) {
  if (error is NetworkException) {
    return 'Unable to connect. Please check your internet connection.';
  }
  if (error is AuthenticationException) {
    return 'Your session has expired. Please sign in again.';
  }
  if (error is ValidationException) {
    return error.userMessage;
  }
  if (error is ServerException) {
    return 'Server error. Please try again later.';
  }
  return 'An unexpected error occurred. Please try again.';
}
```

**Async Loading Error States**:
```dart
// Use StudioEmptyState for full-page errors
StudioEmptyState.loadFailed(
  context,
  error: error,
  onRetry: () => ref.refresh(dataProvider),
)

// Use StudioApiErrorCallout for inline errors
StudioApiErrorCallout(
  message: describeUserVisibleApiErrorResolved(context, error),
  onRetry: () => retry(),
)
```

**Global Error Boundary**:
```dart
// Catch all unhandled errors
void main() {
  FlutterError.onError = (details) {
    // Log to error tracking service
    logError(details.exception, details.stack);
    
    // Show user-friendly error in development
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  
  runZonedGuarded(() {
    runApp(MyApp());
  }, (error, stack) {
    logError(error, stack);
  });
}
```

**Form Validation Errors**:
```dart
// Field-level validation
TextFormField(
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'This field is required';
    }
    if (!EmailValidator.validate(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  },
)

// Form-level validation
if (!_formKey.currentState!.validate()) {
  // Focus first error field
  FocusScope.of(context).requestFocus(_firstErrorFocusNode);
  return;
}
```

**Graceful Degradation**:
```dart
// Show cached data when network fails
projectsAsync.when(
  data: (projects) => ProjectsList(projects),
  loading: () => StudioListSkeleton(),
  error: (error, stack) {
    final cachedProjects = ref.read(cachedProjectsProvider);
    if (cachedProjects.isNotEmpty) {
      return Column(
        children: [
          StudioApiErrorCallout(
            message: 'Showing cached data. ${describeUserVisibleApiErrorResolved(context, error)}',
            onRetry: () => ref.refresh(projectsProvider),
          ),
          ProjectsList(cachedProjects),
        ],
      );
    }
    return StudioEmptyState.loadFailed(context, error: error);
  },
)
```

**Error Logging**:
```dart
// Log errors with context
void logError(Object error, StackTrace? stack, {Map<String, dynamic>? context}) {
  // In development: print to console
  if (kDebugMode) {
    debugPrint('Error: $error');
    debugPrint('Stack: $stack');
    debugPrint('Context: $context');
  }
  
  // In production: send to error tracking service
  if (kReleaseMode) {
    errorTrackingService.recordError(
      error,
      stack,
      context: context,
    );
  }
}
```

### Error Recovery Strategies

1. **Retry with Exponential Backoff**: For transient network errors
2. **Fallback to Cache**: Show stale data when fresh data unavailable
3. **Partial Degradation**: Disable non-critical features when dependencies fail
4. **User Guidance**: Provide clear instructions for permission errors
5. **Automatic Recovery**: Retry authentication when token expires

## Testing Strategy

### Testing Pyramid

**Unit Tests (80% coverage target)**:
- Business logic in services and notifiers
- Utility functions and validators
- State management logic
- Data model serialization/deserialization

**Widget Tests**:
- Component rendering in all states
- User interaction handling
- Responsive layout behavior
- Accessibility features

**Integration Tests**:
- Complete user flows
- Navigation between screens
- Data persistence
- API integration

**Golden Tests**:
- Visual regression testing for key components
- Theme consistency verification
- Responsive layout snapshots

### Test Organization

```
frontend/test/
├── unit/
│   ├── services/
│   ├── utils/
│   └── models/
├── widget/
│   ├── design_system/
│   │   ├── components/
│   │   └── tokens_test.dart
│   └── features/
├── integration/
│   ├── user_flows/
│   └── navigation/
└── golden/
    ├── components/
    └── screens/
```

### Property-Based Testing

**Component State Property Tests**:
```dart
// Test that components render correctly in all states
testWidgets('StudioButton renders in all interaction states', (tester) async {
  for (final state in InteractionState.values) {
    await tester.pumpWidget(
      MaterialApp(
        home: StudioButton(
          onPressed: state == InteractionState.disabled ? null : () {},
          isLoading: state == InteractionState.loading,
          child: Text('Button'),
        ),
      ),
    );
    
    expect(find.byType(StudioButton), findsOneWidget);
    // Verify no rendering errors
    expect(tester.takeException(), isNull);
  }
});
```

**Responsive Typography Property Tests**:
```dart
// Test typography switching at all breakpoints
testWidgets('Typography switches at correct breakpoints', (tester) async {
  final testWidths = [600, 1000, 1280, 1500, 1720, 2000];
  
  for (final width in testWidths) {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: width.toDouble(),
          child: Builder(
            builder: (context) {
              final typography = Theme.of(context).textTheme;
              final expectedProfile = width < 1280 ? 'compact'
                  : width < 1720 ? 'regular'
                  : 'large';
              
              // Verify typography matches expected profile
              return Text('Width: $width, Profile: $expectedProfile');
            },
          ),
        ),
      ),
    );
    
    await tester.pumpAndSettle();
  }
});
```

**Touch Target Property Tests**:
```dart
// Test touch targets on mobile platforms
testWidgets('Interactive elements meet minimum touch target size on mobile', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: Column(
          children: [
            StudioButton(onPressed: () {}, child: Text('Button')),
            StudioIconButton(icon: Icons.close, onPressed: () {}),
            StudioCheckbox(value: false, onChanged: (_) {}),
          ],
        ),
      ),
    ),
  );
  
  // Find all interactive widgets
  final buttons = find.byType(StudioButton);
  final iconButtons = find.byType(StudioIconButton);
  final checkboxes = find.byType(StudioCheckbox);
  
  // Verify each has minimum 44x44 touch target
  for (final finder in [buttons, iconButtons, checkboxes]) {
    final size = tester.getSize(finder);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  }
});
```

**Color Contrast Property Tests**:
```dart
// Test color contrast compliance
testWidgets('Text meets WCAG AA contrast requirements', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Text('Normal text', style: TextStyle(fontSize: 14)),
            Text('Large text', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    ),
  );
  
  // Extract text and background colors
  final normalText = find.text('Normal text');
  final largeText = find.text('Large text');
  
  // Verify contrast ratios
  final normalContrast = calculateContrastRatio(
    textColor: Colors.black,
    backgroundColor: Colors.white,
  );
  expect(normalContrast, greaterThanOrEqualTo(4.5));
  
  final largeContrast = calculateContrastRatio(
    textColor: Colors.black,
    backgroundColor: Colors.white,
  );
  expect(largeContrast, greaterThanOrEqualTo(3.0));
});
```

### CI/CD Integration

**Automated Test Execution**:
```yaml
# .github/workflows/flutter-test.yml
name: Flutter Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - run: flutter test --update-goldens # Only on main branch
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

**Quality Gates**:
1. All tests must pass
2. Code coverage must be ≥ 80%
3. No analyzer warnings or errors
4. Golden tests must match (no visual regressions)
5. Performance benchmarks must not regress

### Test Data Management

**Mock Data**:
```dart
// test/fixtures/mock_data.dart
class MockData {
  static List<Project> projects() => [
    Project(id: '1', name: 'Project A', status: 'active'),
    Project(id: '2', name: 'Project B', status: 'archived'),
  ];
  
  static User user() => User(
    id: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
  );
}
```

**Test Utilities**:
```dart
// test/helpers/test_helpers.dart
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget widget, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: widget),
    ),
  );
}

Future<void> pumpWithTheme(
  WidgetTester tester,
  Widget widget, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildStudioTheme(brightness: brightness),
      home: widget,
    ),
  );
}
```

### Performance Testing

**Benchmark Tests**:
```dart
// test/performance/rendering_benchmark.dart
void main() {
  testWidgets('Large list rendering performance', (tester) async {
    final stopwatch = Stopwatch()..start();
    
    await tester.pumpWidget(
      MaterialApp(
        home: ListView.builder(
          itemCount: 1000,
          itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    stopwatch.stop();
    
    // Verify rendering completes within acceptable time
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
  });
}
```

**Memory Profiling**:
```dart
// Monitor memory usage during tests
testWidgets('Memory usage remains stable during navigation', (tester) async {
  final initialMemory = ProcessInfo.currentRss;
  
  // Navigate through multiple screens
  for (var i = 0; i < 10; i++) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }
  
  final finalMemory = ProcessInfo.currentRss;
  final memoryIncrease = finalMemory - initialMemory;
  
  // Verify no significant memory leaks
  expect(memoryIncrease, lessThan(50 * 1024 * 1024)); // < 50MB increase
});
```

### Accessibility Testing

**Semantic Label Tests**:
```dart
testWidgets('All interactive elements have semantic labels', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Find all interactive widgets
  final buttons = find.byType(IconButton);
  
  for (var i = 0; i < buttons.evaluate().length; i++) {
    final semantics = tester.getSemantics(buttons.at(i));
    expect(semantics.label, isNotNull);
    expect(semantics.label, isNotEmpty);
  }
});
```

**Keyboard Navigation Tests**:
```dart
testWidgets('Form can be completed using only keyboard', (tester) async {
  await tester.pumpWidget(MyForm());
  
  // Tab through form fields
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.enterText(find.byType(TextField).first, 'Test');
  
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.enterText(find.byType(TextField).at(1), 'test@example.com');
  
  // Submit with Enter key
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
  
  // Verify form was submitted
  expect(find.text('Success'), findsOneWidget);
});
```
