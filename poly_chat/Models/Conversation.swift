import Foundation

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var createdAt: Date
    var updatedAt: Date
    var model: ModelInfo

    init(title: String = "New Chat", model: ModelInfo) {
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

struct ToolCall: Identifiable, Codable {
    let id: String              // "call_abc" (OpenAI) or UUID string (Ollama, which omits ids)
    let name: String            // function name, e.g. "web_search"
    let arguments: String       // JSON-encoded string, e.g. "{\"query\":\"...\"}"
    var thoughtSignature: String? // Grok/extended-thinking providers require this echoed back
}

struct Message: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    let documentAttachment: DocumentAttachment?
    let imageAttachment: ImageAttachment?
    var toolCalls: [ToolCall]?   // present on assistant messages that invoke tools
    var toolCallId: String?       // present on tool-result messages (OpenAI requires correlation)
    var toolName: String?         // present on tool-result messages — the function that was called
    var thinkingContent: String?  // reasoning trace from thinking models (DeepSeek-R1, Qwen3, etc.)

    enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), documentAttachment: DocumentAttachment? = nil, imageAttachment: ImageAttachment? = nil, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil, toolName: String? = nil, thinkingContent: String? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.documentAttachment = documentAttachment
        self.imageAttachment = imageAttachment
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.thinkingContent = thinkingContent
    }
}

public struct ImageAttachment: Codable, Identifiable {
    public let id: UUID
    public let base64Data: String   // compressed JPEG, base64-encoded
    public let mimeType: String     // "image/jpeg"
    public let createdAt: Date

    public init(base64Data: String, mimeType: String = "image/jpeg") {
        self.id = UUID()
        self.base64Data = base64Data
        self.mimeType = mimeType
        self.createdAt = Date()
    }
}

public struct DocumentAttachment: Codable, Identifiable {
    public let id: UUID
    public let filename: String
    public let textContent: String
    public let createdAt: Date

    public init(filename: String, textContent: String) {
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
    /// ID of the custom APIProviderConfig this model belongs to. nil = Ollama (default).
    var providerId: String?

    // Detailed model information
    var description: String?
    var parameterSize: String?
    var quantizationLevel: String?
    var family: String?
    var contextLength: Int?

    /// Derived from capabilities — true if the model can process images.
    var hasVision: Bool {
        capabilities.contains("vision") || capabilities.contains("multimodal")
    }

    /// Derived from capabilities — true if the model supports tool/function calling.
    var hasTools: Bool {
        capabilities.contains("tool-use") || capabilities.contains("function-calling")
    }

    init(
        name: String,
        displayName: String,
        provider: String,
        capabilities: [String],
        providerId: String? = nil,
        description: String? = nil,
        parameterSize: String? = nil,
        quantizationLevel: String? = nil,
        family: String? = nil,
        contextLength: Int? = nil
    ) {
        self.name = name
        self.displayName = displayName
        self.provider = provider
        self.capabilities = capabilities
        self.providerId = providerId
        self.description = description
        self.parameterSize = parameterSize
        self.quantizationLevel = quantizationLevel
        self.family = family
        self.contextLength = contextLength
    }

    var apiProviderName: String {
        providerId == nil ? "Ollama" : provider
    }
}
