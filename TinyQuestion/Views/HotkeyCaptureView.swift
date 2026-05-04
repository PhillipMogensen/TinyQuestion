import AppKit
import SwiftUI

/// A button that, when clicked, listens for the next key combo (with at
/// least one modifier) and reports the captured carbon keycode + modifiers.
/// Esc cancels capture without changing the binding.
struct HotkeyCaptureView: View {
    @Bindable var settings: AppSettings

    @State private var capturing: Bool = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggleCapture) {
            HStack(spacing: 6) {
                Image(systemName: capturing ? "record.circle" : "keyboard")
                Text(capturing ? "Press a key combo… (Esc to cancel)" : currentLabel)
                    .font(.system(size: 12, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(capturing ? 0.18 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .onDisappear { stopCapturing() }
    }

    private var currentLabel: String {
        Self.format(modifiers: settings.hotkeyModifiers, keyCode: settings.hotkeyKeyCode)
    }

    private func toggleCapture() {
        if capturing {
            stopCapturing()
        } else {
            startCapturing()
        }
    }

    private func startCapturing() {
        capturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Allow Esc to cancel without binding
            if event.keyCode == 53 {
                stopCapturing()
                return nil
            }

            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else {
                // No modifier — refuse, stay armed.
                NSSound.beep()
                return nil
            }

            settings.hotkeyKeyCode = UInt32(event.keyCode)
            settings.hotkeyModifiers = mods
            stopCapturing()
            return nil
        }
    }

    private func stopCapturing() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        capturing = false
    }

    /// Render a hotkey as a glyph string like "⌥⌘J".
    static func format(modifiers: NSEvent.ModifierFlags, keyCode: UInt32) -> String {
        var glyphs = ""
        if modifiers.contains(.control) { glyphs += "⌃" }
        if modifiers.contains(.option)  { glyphs += "⌥" }
        if modifiers.contains(.shift)   { glyphs += "⇧" }
        if modifiers.contains(.command) { glyphs += "⌘" }
        glyphs += keyName(for: keyCode)
        return glyphs.isEmpty ? "(unbound)" : glyphs
    }

    private static func keyName(for code: UInt32) -> String {
        switch code {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "⌫"
        case 53: return "Esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let key = AppKitKeyName(code) { return key }
            return "key#\(code)"
        }
    }

    /// Use UCKeyTranslate via NSEvent's reverse map. We piggyback on the
    /// system keyboard layout by constructing a synthetic event-style lookup.
    private static func AppKitKeyName(_ code: UInt32) -> String? {
        // Hard-coded ANSI subset — covers the common cases without
        // pulling in CoreGraphics/Carbon translation APIs.
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G",
            6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-",
            28: "8", 29: "0", 30: "]", 31: "O", 32: "U",
            33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: "."
        ]
        return map[code]
    }
}
