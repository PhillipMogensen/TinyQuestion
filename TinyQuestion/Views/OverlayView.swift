import SwiftUI

struct OverlayView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("TinyQuestion")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            VStack(spacing: 8) {
                Image(systemName: "questionmark.bubble")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("Skeleton — phase 1")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(8)
    }
}

#Preview {
    OverlayView()
        .frame(width: 560, height: 420)
}
