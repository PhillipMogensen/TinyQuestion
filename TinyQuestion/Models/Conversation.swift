import Foundation
import Observation

@MainActor
@Observable
final class Conversation {
    var messages: [ChatMessage] = []
    var isStreaming: Bool = false

    func clear() {
        messages.removeAll()
        isStreaming = false
    }

    func send(_ text: String, model: String, systemPrompt: String, client: OllamaClient) async {
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

        do {
            for try await delta in client.streamChat(messages: requestMessages, model: model) {
                if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages[idx].content += delta
                }
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                messages[idx].content = "⚠️ \(error.localizedDescription)"
            }
        }
        isStreaming = false
    }
}
