import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let minimumWindowSize = NSSize(width: 920, height: 760)
    self.minSize = minimumWindowSize

    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    windowFrame.size.width = max(windowFrame.size.width, minimumWindowSize.width)
    windowFrame.size.height = max(windowFrame.size.height, minimumWindowSize.height)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
