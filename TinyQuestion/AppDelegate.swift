import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = OverlayPanel(rootView: OverlayView())
        self.panel = panel
        panel.showCentered()
    }
}
