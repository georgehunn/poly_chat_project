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
    let documentAttachment: DocumentAttachment?

    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), documentAttachment: DocumentAttachment? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.documentAttachment = documentAttachment
    }
}

struct DocumentAttachment: Codable, Identifiable {
    let id: UUID
    let filename: String
    let textContent: String
    let createdAt: Date

    init(filename: String, textContent: String) {
        self.id = UUID()
        self.filename = filename
        self.textContent = textContent
        self.createdAt = Date()
    }
}

struct ModelInfo: Codable, Hashable {
    var name: String
    var displayName: String
    var provider: String
    var capabilities: [String]

    // Detailed model information
    var description: String?
    var parameterSize: String?
    var quantizationLevel: String?
    var family: String?
    var contextLength: Int?
    var hasVision: Bool?
    var hasTools: Bool?

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