import SwiftUI

struct ModelPickerView: View {
    @Bindable var settings: AppSettings
    let client: OllamaClient

    @State private var models: [String] = []
    @State private var loadFailed: Bool = false

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
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 10))
                Text(settings.model)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .task { await loadModels() }
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
