import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        let initialSize = NSSize(width: 540, height: 140)
        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        hasShadow = true

        // Hide the traffic-light controls — design has no window chrome,
        // but we keep `.titled` in the style mask so the panel becomes a
        // proper key window and routes keyboard input (Return/.onSubmit etc.)
        // through the responder chain. Borderless panels don't do this reliably.
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Use a hosting controller with .preferredContentSize sizing so the
        // panel auto-resizes to fit the SwiftUI content. Empty state stays
        // compact; the panel grows as messages stream in.
        let controller = NSHostingController(rootView: rootView)
        controller.sizingOptions = [.preferredContentSize]
        contentViewController = controller
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func showCentered() {
        positionOnActiveScreen()
        makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            showCentered()
        }
    }

    private func positionOnActiveScreen() {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }

        let size = frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.15
        )
        setFrameOrigin(origin)
    }
}
