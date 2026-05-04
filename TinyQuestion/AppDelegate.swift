import AppKit
import HotKey
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: OverlayPanel?
    private var hotkeyManager: HotkeyManager?
    private let conversation = Conversation()
    private let settings = AppSettings()
    private let client = OllamaClient()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = OverlayView(
            conversation: conversation,
            settings: settings,
            client: client,
            onDismiss: { [weak self] in self?.dismiss() }
        )
        panel = OverlayPanel(rootView: view)

        let manager = HotkeyManager { [weak self] in self?.toggle() }
        manager.register(carbonKeyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers)
        hotkeyManager = manager

        observeHotkeyChanges()
    }

    private func toggle() {
        guard let panel else { return }
        if panel.isVisible && panel.isKeyWindow {
            dismiss()
        } else {
            panel.showCentered()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func dismiss() {
        conversation.clear()
        panel?.orderOut(nil)
    }

    /// Re-registers the global hotkey whenever the user changes it in settings.
    /// Re-arms after each fire because withObservationTracking is one-shot.
    private func observeHotkeyChanges() {
        withObservationTracking {
            _ = settings.hotkeyKeyCode
            _ = settings.hotkeyModifiers
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hotkeyManager?.register(
                    carbonKeyCode: self.settings.hotkeyKeyCode,
                    modifiers: self.settings.hotkeyModifiers
                )
                self.observeHotkeyChanges()
            }
        }
    }
}
