# macOS 标题栏集成总结

## 目标
将前端应用的顶部导航栏集成到 macOS 原生窗口的标题栏区域（红黄绿按钮那一行），以节省垂直空间并提供更原生的桌面体验。

## 实现方案

### 1. macOS 原生窗口配置
**文件**: `frontend/macos/Runner/MainFlutterWindow.swift`

启用自定义标题栏样式：
```swift
// 启用透明标题栏
self.titlebarAppearsTransparent = true
self.titleVisibility = .hidden
self.styleMask.insert(.fullSizeContentView)

// 保持交通灯按钮可见
self.standardWindowButton(.closeButton)?.superview?.needsLayout = true
self.standardWindowButton(.miniaturizeButton)?.superview?.needsLayout = true
self.standardWindowButton(.zoomButton)?.superview?.needsLayout = true
```

### 2. 窗口拖动支持
**文件**: `frontend/macos/Runner/AppDelegate.swift`

添加 Method Channel 支持窗口拖动：
```swift
let windowChannel = FlutterMethodChannel(
  name: "com.openflow.app/window",
  binaryMessenger: flutterViewController.engine.binaryMessenger
)

windowChannel.setMethodCallHandler { [weak window] (call, result) in
  switch call.method {
  case "startDragging":
    if let event = NSApp.currentEvent {
      window?.performDrag(with: event)
    }
    result(nil)
  default:
    result(FlutterMethodNotImplemented)
  }
}
```

### 3. Flutter 端集成
**文件**: `frontend/lib/shell/build_product_shell.dart`

#### 3.1 添加平台检测
```dart
import 'dart:io' show Platform;
```

#### 3.2 包装顶部导航栏
```dart
GestureDetector(
  behavior: HitTestBehavior.translucent,
  onPanStart: isMacOS ? (_) => _startWindowDragging() : null,
  child: StudioGlassPanel(
    padding: EdgeInsets.only(
      left: isMacOS && !compactTopChrome ? 78 : ...,  // 为交通灯按钮留空间
      right: ...,
      top: isMacOS ? 8 : 0,  // macOS 顶部留出空间
      bottom: 0,
    ),
    child: // 导航栏内容
  ),
)
```

#### 3.3 实现窗口拖动方法
```dart
Future<void> _startWindowDragging() async {
  if (!Platform.isMacOS) {
    return;
  }
  try {
    const channel = MethodChannel('com.openflow.app/window');
    await channel.invokeMethod('startDragging');
  } catch (e) {
    debugPrint('Failed to start window dragging: $e');
  }
}
```

## 效果

### 布局调整
1. **macOS 桌面模式**（宽度 ≥ 860px）：
   - 左侧预留 78px 空间给交通灯按钮
   - 顶部增加 8px padding
   - 整个导航栏可拖动窗口

2. **紧凑模式**（宽度 < 860px）：
   - 保持原有布局不变
   - 不预留交通灯空间

3. **非 macOS 平台**：
   - 保持原有布局
   - 不启用窗口拖动

### 空间节省
- 原标题栏高度：~28px（macOS 默认）
- 导航栏高度：52-78px（根据屏幕宽度）
- **净节省**：~28px 垂直空间

## 兼容性

### 平台支持
- ✅ macOS：完整支持（自定义标题栏 + 窗口拖动）
- ✅ Windows：保持原有布局
- ✅ Linux：保持原有布局
- ✅ Web：保持原有布局

### 响应式布局
- ✅ 宽屏（≥1440px）：单行布局，左侧预留交通灯空间
- ✅ 中等屏幕（860-1440px）：两行布局，左侧预留交通灯空间
- ✅ 窄屏（<860px）：紧凑布局，不预留交通灯空间

## 测试验证

### 构建测试
```bash
cd frontend
flutter build macos --debug
# ✓ Built build/macos/Build/Products/Debug/openflow_app.app
```

### 代码检查
```bash
flutter analyze lib/shell/build_product_shell.dart
# No issues found!
```

## 提交记录

1. **feat(frontend): Add browser-style navigation buttons to desktop top bar** (94bda941c)
   - 添加前进/后退导航按钮
   - 重新组织顶部导航栏布局

2. **feat(desktop): Integrate navigation bar into macOS title bar area** (0310e6509)
   - 启用 macOS 自定义标题栏
   - 添加窗口拖动支持
   - 集成导航栏到标题栏区域

3. **fix(macos): Correct performDrag method parameter name** (96f657eb5)
   - 修复 Swift API 调用错误
   - 添加 nil 检查

## 后续优化建议

1. **导航历史管理**：
   - 实现真正的前进/后退功能
   - 集成 go_router 的导航历史

2. **交通灯按钮位置**：
   - 考虑动态检测交通灯按钮的实际位置
   - 支持用户自定义交通灯位置（左侧/右侧）

3. **全屏模式**：
   - 优化全屏模式下的标题栏行为
   - 考虑自动隐藏/显示标题栏

4. **Windows 支持**：
   - 考虑为 Windows 添加类似的自定义标题栏
   - 使用 `bitsdojo_window` 或类似插件

## 相关文件

### 修改的文件
- `frontend/macos/Runner/MainFlutterWindow.swift`
- `frontend/macos/Runner/AppDelegate.swift`
- `frontend/lib/home_page.dart`
- `frontend/lib/shell/build_product_shell.dart`

### 新增的文件
- 无（所有功能都集成到现有文件中）

## 参考资料

- [NSWindow - Apple Developer](https://developer.apple.com/documentation/appkit/nswindow)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [macOS Window Customization](https://developer.apple.com/design/human-interface-guidelines/macos/windows-and-views/window-anatomy/)
