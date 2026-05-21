import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let window = NSApplication.shared.windows.first,
       let flutterViewController = window.contentViewController as? FlutterViewController {
      let windowChannel = FlutterMethodChannel(
        name: "com.openflow.app/window",
        binaryMessenger: flutterViewController.engine.binaryMessenger
      )
      
      windowChannel.setMethodCallHandler { [weak window] (call, result) in
        switch call.method {
        case "startDragging":
          window?.performDrag(withEvent: NSApp.currentEvent!)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

