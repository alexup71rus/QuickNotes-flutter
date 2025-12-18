import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // CRITICAL: Return false to prevent app from closing when window is hidden
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
