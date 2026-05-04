import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let client: OllamaClient
    var onClose: () -> Void

    @State private var escMonitor: Any?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))

                Section(title: "System prompt") {
                    TextEditor(text: $settings.systemPrompt)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110, maxHeight: 180)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }

                Section(title: "Default model", footer: "Change the model used for new conversations.") {
                    ModelPickerView(settings: settings, client: client, style: .settingsRow)
                }

                Section(title: "Global hotkey", footer: "Press the hotkey from anywhere to open the overlay.") {
                    HotkeyCaptureView(settings: settings)
                }

                Spacer()

                HStack {
                    Spacer()
                    Text("v\(version)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .help("Back to chat (Esc)")
            .padding(14)
        }
        .onAppear {
            // .onKeyPress only fires while a child has focus. Use a local
            // event monitor so Esc closes settings regardless of where focus is.
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {
                    onClose()
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            if let m = escMonitor {
                NSEvent.removeMonitor(m)
                escMonitor = nil
            }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }
}

private struct Section<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
