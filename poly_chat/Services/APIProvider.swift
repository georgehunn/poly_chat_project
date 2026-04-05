import Foundation

/// Represents the type of API provider
enum ProviderType: String, Codable, CaseIterable {
    case ollama = "Ollama"
    case openAICompatible = "OpenAI-Compatible"

    var supportsAPIKey: Bool {
        true
    }

    // Migrate old persisted values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "Ollama":
            self = .ollama
        case "Grok", "OpenAI", "OpenAI-Compatible":
            self = .openAICompatible
        default:
            self = .openAICompatible
        }
    }
}

/// Represents a stored API provider configuration
struct APIProviderConfig: Identifiable, Codable {
    let id: String
    var name: String
    var providerType: ProviderType
    var endpoint: String
    var apiKey: String

    init(id: String = UUID().uuidString, name: String, providerType: ProviderType, endpoint: String, apiKey: String = "") {
        self.id = id
        self.name = name
        self.providerType = providerType
        self.endpoint = endpoint
        self.apiKey = apiKey
    }

    // Normalize endpoint for storage
    mutating func normalizeEndpoint() {
        var normalized = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        // Add /api or /v1 based on provider type if not already present
        let providerPath: String
        switch providerType {
        case .ollama:
            providerPath = "/api"
        case .openAICompatible:
            providerPath = "/v1"
        }

        if !normalized.contains(providerPath) {
            normalized += providerPath
        }
        self.endpoint = normalized
    }
}
