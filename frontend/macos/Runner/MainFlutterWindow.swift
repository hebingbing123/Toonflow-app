import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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
    DispatchQueue.main.async {
      self.toggleFullScreen(nil)
    }
  }
  
  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
}
