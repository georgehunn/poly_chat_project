import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var model: ModelInfo

    init(title: String = "New Conversation", model: ModelInfo) {
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

    // Detailed model information
    let description: String?
    let parameterSize: String?
    let quantizationLevel: String?
    let family: String?
    let contextLength: Int?
    let hasVision: Bool?
    let hasTools: Bool?

    init(
        name: String,
        displayName: String,
        provider: String,
        capabilities: [String],
        description: String? = nil,
        parameterSize: String? = nil,
        quantizationLevel: String? = nil,
        family: String? = nil,
        contextLength: Int? = nil,
        hasVision: Bool? = nil,
        hasTools: Bool? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.provider = provider
        self.capabilities = capabilities
        self.description = description
        self.parameterSize = parameterSize
        self.quantizationLevel = quantizationLevel
        self.family = family
        self.contextLength = contextLength
        self.hasVision = hasVision
        self.hasTools = hasTools
    }
}