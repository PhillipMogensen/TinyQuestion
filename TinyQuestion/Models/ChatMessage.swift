import Foundation

struct ChatMessage: Identifiable, Equatable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case system, user, assistant
    }

    var id: UUID = UUID()
    var role: Role
    var content: String

    private enum CodingKeys: String, CodingKey {
        case role, content
    }
}
