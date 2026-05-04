import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let defaultSystemPrompt = """
    Match the length of your answer to what the question actually needs. \
    Factual lookups get a single word or phrase. \
    "How" and "why" questions get a short paragraph that actually explains the mechanism — \
    not just the name of the concept. \
    No preamble, no apologies, no restating the question.
    """

    static let defaultModel = "phi4-mini:latest"

    /// Carbon virtual keycode for "J" — default summon key.
    static let defaultHotkeyKeyCode: UInt32 = 38

    /// Default hotkey modifiers: ⌥⌘ (Option + Command).
    static let defaultHotkeyModifiers: NSEvent.ModifierFlags = [.command, .option]

    private let defaults: UserDefaults

    var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    var hotkeyKeyCode: UInt32 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode) }
    }

    var hotkeyModifiers: NSEvent.ModifierFlags {
        didSet { defaults.set(Int(hotkeyModifiers.rawValue), forKey: Keys.hotkeyModifiers) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        self.model = defaults.string(forKey: Keys.model) ?? Self.defaultModel

        if defaults.object(forKey: Keys.hotkeyKeyCode) != nil {
            self.hotkeyKeyCode = UInt32(defaults.integer(forKey: Keys.hotkeyKeyCode))
        } else {
            self.hotkeyKeyCode = Self.defaultHotkeyKeyCode
        }

        if defaults.object(forKey: Keys.hotkeyModifiers) != nil {
            self.hotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UInt(defaults.integer(forKey: Keys.hotkeyModifiers))
            )
        } else {
            self.hotkeyModifiers = Self.defaultHotkeyModifiers
        }
    }

    private enum Keys {
        static let systemPrompt = "tinyquestion.systemPrompt"
        static let model = "tinyquestion.model"
        static let hotkeyKeyCode = "tinyquestion.hotkeyKeyCode"
        static let hotkeyModifiers = "tinyquestion.hotkeyModifiers"
    }
}
