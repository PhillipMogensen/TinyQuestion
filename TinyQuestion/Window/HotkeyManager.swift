import AppKit
import HotKey

final class HotkeyManager {
    private var hotKey: HotKey?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    /// Re-registers the hotkey. Replaces any existing binding.
    /// Returns false if the carbon key code can't be mapped to a known key.
    @discardableResult
    func register(carbonKeyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard let key = Key(carbonKeyCode: carbonKeyCode) else {
            hotKey = nil
            return false
        }
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onTrigger()
        }
        return true
    }

    func unregister() {
        hotKey = nil
    }
}
