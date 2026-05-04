import SwiftUI

struct ConversationView: View {
    @Bindable var conversation: Conversation
    @Bindable var settings: AppSettings
    let client: OllamaClient
    var onDismiss: () -> Void

    @State private var input: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .onAppear { inputFocused = true }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if conversation.messages.isEmpty {
                        Text("Ask anything.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(conversation.messages) { msg in
                            MessageView(message: msg).id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: conversation.messages.last?.content) { _, _ in
                guard let id = conversation.messages.last?.id else { return }
                proxy.scrollTo(id, anchor: .bottom)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                guard let id = conversation.messages.last?.id else { return }
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                TextField("Ask…", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($inputFocused)
                    .onSubmit(submit)
                    .submitLabel(.send)
                    .disabled(conversation.isStreaming)

                if conversation.isStreaming {
                    ProgressView().controlSize(.small)
                }
            }

            HStack {
                Spacer()
                ModelPickerView(settings: settings, client: client)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.white.opacity(0.06)),
            alignment: .top
        )
    }

    private func submit() {
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        input = ""
        Task {
            await conversation.send(
                text,
                model: settings.model,
                systemPrompt: settings.systemPrompt,
                client: client
            )
        }
    }
}
