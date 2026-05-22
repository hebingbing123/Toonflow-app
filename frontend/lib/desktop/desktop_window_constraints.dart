/// Minimum desktop window size for the product shell.
///
/// Keep in sync with native runners:
/// - `macos/Runner/MainFlutterWindow.swift`
/// - `windows/runner/win32_window.cpp`
/// - `linux/runner/my_application.cc`
abstract final class DesktopWindowConstraints {
  /// Below this width the macOS integrated title bar and pipeline strip overflow.
  static const double minWidth = 960;

  static const double minHeight = 640;
}
