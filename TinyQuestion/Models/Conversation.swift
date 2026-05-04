import Foundation
import Observation

@MainActor
@Observable
final class Conversation {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false

    @ObservationIgnored
    private var streamingTask: Task<Void, Never>?

    func clear() {
        streamingTask?.cancel()
        streamingTask = nil
        messages.removeAll()
        isStreaming = false
    }

    func send(_ text: String, model: String, systemPrompt: String, client: OllamaClient) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        var requestMessages: [ChatMessage] = []
        if !systemPrompt.isEmpty {
            requestMessages.append(ChatMessage(role: .system, content: systemPrompt))
        }
        requestMessages.append(contentsOf: messages)
        let userMsg = ChatMessage(role: .user, content: trimmed)
        requestMessages.append(userMsg)

        messages.append(userMsg)
        let assistant = ChatMessage(role: .assistant, content: "")
        let assistantId = assistant.id
        messages.append(assistant)
        isStreaming = true

        streamingTask = Task { @MainActor [weak self] in
            defer {
                self?.isStreaming = false
                self?.streamingTask = nil
            }
            do {
                for try await delta in client.streamChat(messages: requestMessages, model: model) {
                    try Task.checkCancellation()
                    guard let self else { return }
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                        self.messages[idx].content += delta
                    }
                }
            } catch is CancellationError {
                // User dismissed mid-stream; nothing to display.
                return
            } catch {
                guard let self else { return }
                if let idx = self.messages.firstIndex(where: { $0.id == assistantId }) {
                    self.messages[idx].content = "⚠️ \(error.localizedDescription)"
                }
            }
        }
    }
}
