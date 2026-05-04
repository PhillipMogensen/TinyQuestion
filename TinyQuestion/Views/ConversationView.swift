import AppKit
import SwiftUI

struct ConversationView: View {
    @Bindable var conversation: Conversation
    @Bindable var settings: AppSettings
    let client: OllamaClient
    var onDismiss: () -> Void
    var onShowSettings: () -> Void

    @State private var input: String = ""
    @State private var modelReachable: Bool = true
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InputBar(
                text: $input,
                isStreaming: conversation.isStreaming,
                inputFocused: $inputFocused,
                onSubmit: submit,
                onStop: { conversation.clear() }
            )

            StatusBar(
                settings: settings,
                client: client,
                modelReachable: $modelReachable,
                onShowSettings: onShowSettings
            )

            if !conversation.messages.isEmpty {
                turnsScroll
                    .frame(maxHeight: 360)
            }
        }
        .padding(14)
        .onAppear { inputFocused = true }
        .onChange(of: conversation.isStreaming) { _, streaming in
            // Streaming just ended — restore focus so the user can type a
            // follow-up immediately. .disabled(isStreaming) on the TextField
            // resigns first responder when streaming starts.
            if !streaming { inputFocused = true }
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(KeyEquivalent(","), phases: .down) { press in
            if press.modifiers.contains(.command) {
                onShowSettings()
                return .handled
            }
            return .ignored
        }
    }

    private var turnsScroll: some View {
        let pairs = Array(turns(from: conversation.messages).reversed())
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(pairs) { turn in
                        TurnView(
                            turn: turn,
                            isStreaming: conversation.isStreaming,
                            onCopy: { copy(turn.assistant?.content ?? "") },
                            onRegenerate: { regenerate(turn) }
                        )
                        .id(turn.id)
                    }
                }
                .padding(.top, 4)
            }
            .onChange(of: conversation.messages.last?.content) { _, _ in
                if let first = pairs.first { proxy.scrollTo(first.id, anchor: .top) }
            }
            .onChange(of: conversation.messages.count) { _, _ in
                if let first = pairs.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }

    private func submit() {
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        input = ""
        conversation.send(
            text,
            model: settings.model,
            systemPrompt: settings.systemPrompt,
            client: client
        )
    }

    private func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func regenerate(_ turn: Turn) {
        guard !conversation.isStreaming else { return }
        let userText = turn.user.content
        var doomed: Set<UUID> = [turn.user.id]
        if let aid = turn.assistant?.id { doomed.insert(aid) }
        // Drop this turn's user+assistant pair, then re-send so the model
        // sees the same prior context but produces a fresh answer.
        conversation.messages.removeAll { doomed.contains($0.id) }
        conversation.send(
            userText,
            model: settings.model,
            systemPrompt: settings.systemPrompt,
            client: client
        )
    }
}

// MARK: - Turn pairing

struct Turn: Identifiable {
    let user: ChatMessage
    let assistant: ChatMessage?
    var id: UUID { user.id }
}

private func turns(from messages: [ChatMessage]) -> [Turn] {
    var result: [Turn] = []
    var pendingUser: ChatMessage?
    for msg in messages {
        switch msg.role {
        case .user:
            if let u = pendingUser { result.append(Turn(user: u, assistant: nil)) }
            pendingUser = msg
        case .assistant:
            if let u = pendingUser {
                result.append(Turn(user: u, assistant: msg))
                pendingUser = nil
            }
        case .system:
            continue
        }
    }
    if let u = pendingUser { result.append(Turn(user: u, assistant: nil)) }
    return result
}

// MARK: - Input bar

private struct InputBar: View {
    @Binding var text: String
    let isStreaming: Bool
    var inputFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Ask a question...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused(inputFocused)
                .submitLabel(.send)
                .disabled(isStreaming)
                .onSubmit(onSubmit)

            Button {
                if isStreaming { onStop() } else { onSubmit() }
            } label: {
                Image(systemName: isStreaming ? "stop.fill" : "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(canSend ? Color.accentColor : Color.secondary.opacity(0.4))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isStreaming && !canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Status bar

private struct StatusBar: View {
    @Bindable var settings: AppSettings
    let client: OllamaClient
    @Binding var modelReachable: Bool
    let onShowSettings: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ModelPickerView(settings: settings, client: client, style: .statusBar)

            Spacer()

            Text(hotkeyHint)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button(action: onShowSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 4)
    }

    private var hotkeyHint: String {
        let combo = HotkeyCaptureView.format(
            modifiers: settings.hotkeyModifiers,
            keyCode: settings.hotkeyKeyCode
        )
        return "\(combo) to toggle"
    }
}

// MARK: - Turn view

private struct TurnView: View {
    let turn: Turn
    let isStreaming: Bool
    let onCopy: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(turn.user.content)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            assistantCard
        }
    }

    @ViewBuilder
    private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let assistant = turn.assistant {
                if assistant.content.isEmpty {
                    Text("…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    MarkdownContent(text: assistant.content)
                        .font(.system(size: 14))
                }

                if !assistant.content.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: onCopy) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy answer")
                        .disabled(isStreaming)

                        Button(action: onRegenerate) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Regenerate")
                        .disabled(isStreaming)

                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
