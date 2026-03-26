import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var model: ModelInfo

    init(title: String = "New Conversation", model: ModelInfo = ModelInfo.default) {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.model = model
    }
}

extension Conversation {
    var lastMessage: String? {
        messages.last?.content
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }
}

struct ModelInfo: Codable, Hashable {
    let name: String
    let displayName: String
    let provider: String
    let capabilities: [String]

    static let `default` = ModelInfo(
        name: "llama3",
        displayName: "Llama 3",
        provider: "Ollama",
        capabilities: ["text-generation"]
    )
}