import SwiftUI

struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 40)
                bubble
            } else {
                bubble
                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        Group {
            if message.content.isEmpty {
                Text("…")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else if message.role == .user {
                Text(message.content)
                    .font(.system(size: 14))
                    .textSelection(.enabled)
            } else {
                MarkdownContent(text: message.content)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(message.role == .user
                      ? Color.accentColor.opacity(0.18)
                      : Color.secondary.opacity(0.12))
        )
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}
