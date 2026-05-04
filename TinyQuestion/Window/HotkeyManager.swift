import AppKit
import HotKey

final class HotkeyManager {
    private var hotKey: HotKey?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func register(key: Key, modifiers: NSEvent.ModifierFlags) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onTrigger()
        }
    }

    func unregister() {
        hotKey = nil
    }
}
