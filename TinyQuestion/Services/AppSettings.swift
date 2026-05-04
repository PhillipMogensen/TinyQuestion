import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let defaultSystemPrompt = """
    You answer questions tersely. No preamble, no apologies, no restating the question. \
    If the answer is a single word or phrase, just say it.
    """

    static let defaultModel = "phi4-mini:latest"

    private let defaults: UserDefaults

    var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.systemPrompt = defaults.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        self.model = defaults.string(forKey: Keys.model) ?? Self.defaultModel
    }

    private enum Keys {
        static let systemPrompt = "tinyquestion.systemPrompt"
        static let model = "tinyquestion.model"
    }
}
