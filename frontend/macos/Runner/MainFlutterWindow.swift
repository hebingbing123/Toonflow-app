import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let minimumWindowSize = NSSize(width: 960, height: 640)
  /// Matches integrated macOS title bar + padding (Flutter `fullSizeContentView` chrome).
  private static let titleBarChromeHeight: CGFloat = 49
  private var localMouseMonitor: Any?

  private func toggleTitleBarDisplayMode() {
    toggleFullScreen(nil)
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Enable custom title bar with transparent background
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    
    // Keep traffic lights (red, yellow, green buttons) visible
    self.standardWindowButton(.closeButton)?.superview?.needsLayout = true
    self.standardWindowButton(.miniaturizeButton)?.superview?.needsLayout = true
    self.standardWindowButton(.zoomButton)?.superview?.needsLayout = true

    collectionBehavior.insert(.fullScreenPrimary)

    minSize = Self.minimumWindowSize
    if windowFrame.width < Self.minimumWindowSize.width
      || windowFrame.height < Self.minimumWindowSize.height
    {
      var frame = windowFrame
      frame.size.width = max(frame.size.width, Self.minimumWindowSize.width)
      frame.size.height = max(frame.size.height, Self.minimumWindowSize.height)
      setFrame(frame, display: true)
    }

    let windowChannel = FlutterMethodChannel(
      name: "com.openflow.app/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let window = self else {
        result(nil)
        return
      }
      switch call.method {
      case "startDragging":
        if let event = NSApp.currentEvent {
          window.performDrag(with: event)
        }
        result(nil)
      case "toggleZoom":
        window.toggleFullScreen(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) {
      [weak self] event in
      guard let self = self,
            event.window === self,
            event.clickCount == 2
      else {
        return event
      }
      let location = event.locationInWindow
      if location.y >= self.frame.size.height - Self.titleBarChromeHeight {
        self.toggleTitleBarDisplayMode()
        return nil
      }
      return event
    }
  }

  deinit {
    if let localMouseMonitor = localMouseMonitor {
      NSEvent.removeMonitor(localMouseMonitor)
    }
  }

  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
}
