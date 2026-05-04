import AppKit
import HotKey
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = OverlayPanel(rootView: OverlayView())
        self.panel = panel

        let manager = HotkeyManager { [weak self] in
            self?.panel?.toggle()
        }
        manager.register(key: .j, modifiers: [.command, .option])
        self.hotkeyManager = manager
    }
}
