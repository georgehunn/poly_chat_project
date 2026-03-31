import Foundation

/// Represents the type of API provider
enum ProviderType: String, Codable, CaseIterable {
    case ollama = "Ollama"
    case grok = "Grok"
    case openAI = "OpenAI"

    var defaultEndpoint: String {
        switch self {
        case .ollama:
            return "https://ollama.com/api"
        case .grok:
            return "https://api.x.ai/v1"
        case .openAI:
            return "https://api.openai.com/v1"
        }
    }

    var supportsAPIKey: Bool {
        true // All supported providers use API keys
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
        case .grok, .openAI:
            providerPath = "/v1"
        }

        if !normalized.contains(providerPath) {
            normalized += providerPath
        }
        self.endpoint = normalized
    }
}
