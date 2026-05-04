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
        Text(message.content.isEmpty ? "…" : message.content)
            .font(.system(size: 14))
            .textSelection(.enabled)
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
