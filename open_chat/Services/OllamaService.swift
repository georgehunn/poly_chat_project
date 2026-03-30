import Foundation

class OllamaService {
    static let shared = OllamaService()

    private init() {}

    /// Checks if the Ollama URL is properly configured
    /// - Returns: true if endpoint is set in Keychain
    static func isConfigured() -> Bool {
        let secureStorage = SecureStorageService()

        // Check endpoint - read from Keychain
        guard let endpoint = secureStorage.getEndpoint(), !endpoint.isEmpty else {
            return false
        }

        // API key is optional - only check if present
        // If API key is empty, we'll try without authentication

        return true
    }

    /// Checks if both URL and API key are configured
    /// - Returns: true if endpoint is set AND API key is not empty
    static func isFullyConfigured() -> Bool {
        let secureStorage = SecureStorageService()

        // Check endpoint - read from Keychain
        guard let endpoint = secureStorage.getEndpoint(), !endpoint.isEmpty else {
            return false
        }

        // Check API key - read from Keychain
        guard let apiKey = secureStorage.getAPIKey(), !apiKey.isEmpty else {
            return false
        }

        return true
    }

    /// Gets the configuration status message
    /// - Returns: A message describing the current configuration status
    static func getConfigStatusMessage() -> String {
        let secureStorage = SecureStorageService()
        let endpoint = secureStorage.getEndpoint()
        let apiKey = secureStorage.getAPIKey()

        if endpoint == nil || endpoint?.isEmpty == true {
            return "URL is not set up. Please configure the endpoint in Settings."
        } else if apiKey == nil || apiKey?.isEmpty == true {
            return "API key is not set up. Please configure your API key in Settings."
        }
        return "URL and API key not set up. Please configure them in Settings."
    }

    private var baseURL: String {
        let secureStorage = SecureStorageService()
        // Get from Keychain or use default
        if let savedEndpoint = secureStorage.getEndpoint(),
           !savedEndpoint.isEmpty {
            // Normalize the endpoint
            var endpoint = savedEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

            // Remove trailing slashes
            while endpoint.hasSuffix("/") {
                endpoint.removeLast()
            }

            // Add /api if it's not already there
            if !endpoint.hasSuffix("/api") && !endpoint.contains("/api/") {
                endpoint += "/api"
            }

            print("Using Ollama endpoint: \(endpoint)")
            return endpoint
        }
        return "https://ollama.com/api"
    }

    /// Generate a short title (3 words) for a conversation using the LLM
    /// - Parameters:
    ///   - messages: The conversation messages (typically user + assistant exchange)
    ///   - model: The model name to use
    /// - Returns: A short title summarizing the conversation
    func generateTitle(for messages: [Message], model: String) async throws -> String {
        // Create a summary request with the first few messages
        let summaryPrompt = """
        Provide a short title (2-4 words) that summarizes the main topic of this conversation.
        Respond with ONLY the title text, no quotes or punctuation.

        Conversation:
        \(messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n\n"))
        """

        let summaryMessages = [
            Message(id: UUID(), role: .system, content: "You are a helpful assistant that creates concise titles for conversations.", timestamp: Date()),
            Message(id: UUID(), role: .user, content: summaryPrompt, timestamp: Date())
        ]

        let urlString = "\(baseURL)/chat"
        print("Generating title using: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            throw URLError(.badURL)
        }

        let ollamaMessages = summaryMessages.map { message -> [String: String] in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        let secureStorage = SecureStorageService()
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body for title generation")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                let statusString = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                var errorBody = ""
                if let responseString = String(data: data, encoding: .utf8) {
                    errorBody = ": \(responseString)"
                }
                let errorMessage = "Title generation error \(httpResponse.statusCode) \(statusString)\(errorBody)"
                throw NSError(domain: "OllamaTitleError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Title generation response: \(responseString)")
            }

            // Try to decode as our expected format
            do {
                let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
                let title = ollamaResponse.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
                // Clean up the title - remove quotes, punctuation, etc.
                let cleanedTitle = title.replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .replacingOccurrences(of: "`", with: "")
                    .components(separatedBy: .whitespacesAndNewlines).prefix(4).joined(separator: " ")
                return cleanedTitle
            } catch {
                // Try to extract content directly
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = jsonObject["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    let cleanedTitle = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\"", with: "")
                        .components(separatedBy: .whitespacesAndNewlines).prefix(4).joined(separator: " ")
                    return cleanedTitle
                }
                throw error
            }
        } catch {
            print("Error generating title: \(error)")
            throw error
        }
    }

    func generateChatResponse(messages: [Message], model: String) async throws -> String {
        let urlString = "\(baseURL)/chat"
        print("Attempting to connect to: \(urlString)")
        print("BaseURL: \(baseURL)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            throw URLError(.badURL)
        }

        // Convert messages to the format expected by Ollama chat API
        let ollamaMessages = messages.map { message -> [String: String] in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        let secureStorage = SecureStorageService()
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
            print("Using API key for authentication")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            print("Sending request to Ollama...")
            let (data, response) = try await URLSession.shared.data(for: request)

            // Print response info for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")

                // Check for HTTP errors
                if httpResponse.statusCode >= 400 {
                    let statusString = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    var errorBody = ""
                    if let responseString = String(data: data, encoding: .utf8) {
                        errorBody = ": \(responseString)"
                    }
                    print("HTTP Error \(httpResponse.statusCode) \(statusString)\(errorBody)")

                    // Create a more descriptive error with the status code and response
                    let errorMessage = "Server error \(httpResponse.statusCode) \(statusString)\(errorBody)"

                    // Determine error domain and code based on status
                    let errorDomain: String
                    let errorCode: Int

                    if httpResponse.statusCode == 401 {
                        errorDomain = "OllamaUnauthorizedError"
                        errorCode = 401
                    } else if httpResponse.statusCode == 404 {
                        errorDomain = "OllamaUnsupportedURLError"
                        errorCode = 404
                    } else {
                        errorDomain = "OllamaError"
                        errorCode = Int(httpResponse.statusCode)
                    }

                    let nsError = NSError(domain: errorDomain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    throw nsError
                }
            }

            // Print response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
            }

            // Try to parse as JSON to see what we're actually getting
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                print("Parsed JSON response: \(jsonResponse)")
            } catch {
                print("Failed to parse response as JSON: \(error)")
            }

            // Try to decode as our expected format first
            do {
                let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
                print("Successfully received response: \(ollamaResponse.message.content)")
                return ollamaResponse.message.content
            } catch {
                print("Failed to decode as OllamaChatResponse: \(error)")
                // Try to decode as a generic JSON to see what we're getting
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Raw response object: \(jsonObject)")

                        // Try to extract content even if model field is missing
                        if let message = jsonObject["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            print("Extracted content directly: \(content)")
                            return content
                        }

                        // If we can't get content, throw the original error
                        throw error
                    }
                } catch {
                    print("Failed to parse response as generic JSON: \(error)")
                }

                // Re-throw the original decoding error
                throw error
            }
        } catch let decodingError as DecodingError {
            print("Decoding error in generateChatResponse: \(decodingError)")
            // Print more details about the decoding error
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("Key '\(key)' not found. Coding path: \(context.codingPath)")
            case .typeMismatch(let type, let context):
                print("Type mismatch. Expected \(type). Coding path: \(context.codingPath)")
            case .valueNotFound(let type, let context):
                print("Value not found. Expected \(type). Coding path: \(context.codingPath)")
            case .dataCorrupted(let context):
                print("Data corrupted. Coding path: \(context.codingPath)")
            @unknown default:
                print("Unknown decoding error: \(decodingError)")
            }
            throw decodingError
        } catch let urlError as URLError where urlError.code == .timedOut {
            print("Request to Ollama timed out: \(urlError)")
            throw URLError(.timedOut)
        } catch {
            print("Error in generateChatResponse: \(error)")
            throw error
        }
    }


    func listModels() async throws -> [OllamaModel] {
        let urlString = "\(baseURL)/tags"
        print("Attempting to fetch models from: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL for models: \(urlString)")
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add API key if available
        let secureStorage = SecureStorageService()
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        do {
            print("Fetching models from Ollama...")
            let (data, response) = try await URLSession.shared.data(for: request)

            // Print response info for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Models HTTP Status: \(httpResponse.statusCode)")
            }

            let modelsResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            print("Successfully fetched \(modelsResponse.models.count) models")
            return modelsResponse.models
        } catch {
            print("Error fetching models: \(error)")
            throw error
        }
    }

    func getModelDetails(name: String) async throws -> OllamaModelDetails {
        let urlString = "\(baseURL)/show"
        print("Attempting to fetch model details for: \(name) from URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL for model details: \(urlString)")
            throw URLError(.badURL)
        }

        let requestBody: [String: Any] = [
            "name": name
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        let secureStorage = SecureStorageService()
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body for model details")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            print("Fetching model details from Ollama...")
            let (data, response) = try await URLSession.shared.data(for: request)

            // Print response info for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Model details HTTP Status: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
            }

            // Print raw response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw model details response: \(responseString)")
            }

            let modelDetails = try JSONDecoder().decode(OllamaModelDetails.self, from: data)
            print("Successfully fetched details for model: \(name)")

            // Print decoded details for debugging
            print("Decoded model details - License: \(String(describing: modelDetails.license?.prefix(100)))")
            print("Decoded model details - Parameters: \(String(describing: modelDetails.parameters?.prefix(100)))")
            print("Decoded model details - Modelfile: \(String(describing: modelDetails.modelfile?.prefix(100)))")
            print("Decoded model details - Capabilities: \(String(describing: modelDetails.capabilities))")

            return modelDetails
        } catch let decodingError as DecodingError {
            print("Decoding error fetching model details: \(decodingError)")
            // Print the raw data for debugging if we have it
            throw decodingError
        } catch let urlError as URLError {
            print("URL error fetching model details: \(urlError)")
            throw urlError
        } catch {
            print("Generic error fetching model details: \(error)")
            throw error
        }
    }
}

struct OllamaChatResponse: Codable {
    let model: String?
    let message: OllamaMessage
    let done: Bool
}


struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaModel: Codable {
    let name: String
    let modified_at: String
    let size: Int
}

// Detailed model information from Ollama API
struct OllamaModelDetails: Codable {
    let license: String?
    let modelfile: String?
    let parameters: String?
    let template: String?
    let details: ModelDetails?
    let model_info: [String: JSONValue]?
    let capabilities: Capabilities?

    enum CodingKeys: String, CodingKey {
        case license, modelfile, parameters, template, details
        case model_info = "model_info"
        case capabilities
    }
}

struct ModelDetails: Codable {
    let format: String?
    let family: String?
    let families: [String]?
    let parameter_size: String?
    let quantization_level: String?

    enum CodingKeys: String, CodingKey {
        case format, family, families
        case parameter_size = "parameter_size"
        case quantization_level = "quantization_level"
    }
}

struct Capabilities: Codable {
    let completion: Bool?
    let vision: Bool?
}

// Generic JSON value type for handling dynamic model_info content
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if container.decodeNil() {
            self = .null
        } else if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
        } else if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}