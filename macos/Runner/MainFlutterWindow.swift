import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Configure window as borderless popover
    self.styleMask = [.borderless]
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = true
    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    
    // Hide window when it loses focus (click outside)
    NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification,
      object: self,
      queue: .main
    ) { [weak self] _ in
      print("Window resigned key - hiding")
      self?.orderOut(nil)
      // Notify Flutter that window was hidden
      if let controller = self?.contentViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(
          name: "quick_notes/window",
          binaryMessenger: controller.engine.binaryMessenger
        )
        channel.invokeMethod("window_hidden", arguments: nil)
      }
    }
    
    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
  
  // Allow window to become key window (receive keyboard events)
  override var canBecomeKey: Bool {
    return true
  }
  
  // Allow window to accept first responder (for text input)
  override var acceptsFirstResponder: Bool {
    return true
  }
}
