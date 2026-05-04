import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let client: OllamaClient
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 6) {
                Text("System prompt")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextEditor(text: $settings.systemPrompt)
                    .font(.system(size: 13))
                    .frame(minHeight: 100, maxHeight: 160)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                Button("Reset to default") {
                    settings.systemPrompt = AppSettings.defaultSystemPrompt
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Default model")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ModelPickerView(settings: settings, client: client)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Global hotkey")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HotkeyCaptureView(settings: settings)
            }

            Spacer()
        }
        .padding(14)
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Back to chat (Esc)")
        }
    }
}
