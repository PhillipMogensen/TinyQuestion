import SwiftUI

struct OverlayView: View {
    @Bindable var conversation: Conversation
    @Bindable var settings: AppSettings
    let client: OllamaClient
    var onDismiss: () -> Void

    var body: some View {
        ConversationView(
            conversation: conversation,
            settings: settings,
            client: client,
            onDismiss: onDismiss
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(8)
    }
}
