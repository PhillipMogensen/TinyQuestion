import SwiftUI

struct ModelPickerView: View {
    enum Style {
        case statusBar
        case settingsRow
    }

    @Bindable var settings: AppSettings
    let client: OllamaClient
    var style: Style = .settingsRow

    @State private var models: [String] = []
    @State private var loadFailed: Bool = false

    var isReachable: Bool {
        !loadFailed && (models.isEmpty || models.contains(settings.model))
    }

    var body: some View {
        Menu {
            if loadFailed {
                Text("Ollama unreachable").foregroundStyle(.secondary)
            } else if models.isEmpty {
                Text("Loading…").foregroundStyle(.secondary)
            } else {
                ForEach(models, id: \.self) { name in
                    Button {
                        settings.model = name
                    } label: {
                        if name == settings.model {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            }
            Divider()
            Button("Refresh") { Task { await loadModels() } }
        } label: {
            label
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .task { await loadModels() }
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .statusBar:
            HStack(spacing: 6) {
                Circle()
                    .fill(loadFailed ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
                Text(settings.model)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        case .settingsRow:
            HStack(spacing: 8) {
                Circle()
                    .fill(loadFailed ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
                Text(settings.model)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
        }
    }

    private func loadModels() async {
        do {
            let fetched = try await client.listModels()
            models = fetched
            loadFailed = false
            // If the persisted model isn't installed, fall back to first available.
            if !fetched.contains(settings.model), let first = fetched.first {
                settings.model = first
            }
        } catch {
            loadFailed = true
        }
    }
}
