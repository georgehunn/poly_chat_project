import Foundation

class OllamaService {
    static let shared = OllamaService()

    private let secureStorage = SecureStorageService()

    private init() {}

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    private func dataWithRetry(for request: URLRequest, retries: Int = 3) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 1...retries {
            do {
                return try await session.data(for: request)
            } catch {
                lastError = error
                print("[OllamaService] Attempt \(attempt) failed: \(error)")
                if attempt < retries {
                    try await Task.sleep(nanoseconds: UInt64(1_000_000_000 * attempt))
                }
            }
        }
        throw lastError!
    }

    /// Validation result for connection testing
    enum ValidationError: Error {
        case noEndpoint
        case invalidEndpoint
        case connectionFailed(Error)
        case unauthorized
        case unknown
    }

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

    /// Validates the connection to the Ollama endpoint
    /// - Parameters:
    ///   - endpoint: The endpoint URL to test
    ///   - apiKey: Optional API key for authentication
    /// - Returns: Void but throws error if validation fails
    static func validateConnection(endpoint: String, apiKey: String? = nil) async throws {
        var normalizedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing slashes
        while normalizedEndpoint.hasSuffix("/") {
            normalizedEndpoint.removeLast()
        }

        // Add /api if it's not already there
        if !normalizedEndpoint.hasSuffix("/api") && !normalizedEndpoint.contains("/api/") {
            normalizedEndpoint += "/api"
        }

        let urlString = "\(normalizedEndpoint)/tags"

        guard let url = URL(string: urlString) else {
            throw ValidationError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        // Add API key if provided
        if let apiKey = apiKey, !apiKey.isEmpty {
            let authValue = apiKey.hasPrefix("Bearer ") ? apiKey : "Bearer \(apiKey)"
            request.setValue(authValue, forHTTPHeaderField: "Authorization")
        }

        let validationConfig = URLSessionConfiguration.default
        validationConfig.timeoutIntervalForRequest = 30
        let validationSession = URLSession(configuration: validationConfig)

        do {
            let (data, response) = try await validationSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw ValidationError.unauthorized
                } else if httpResponse.statusCode >= 400 {
                    throw ValidationError.connectionFailed(NSError(domain: "OllamaError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned \(httpResponse.statusCode)"]))
                }
            }

        } catch {
            if let urlError = error as? URLError {
                throw ValidationError.connectionFailed(urlError)
            } else if let ollamaError = error as? ValidationError {
                throw ollamaError
            } else {
                throw ValidationError.connectionFailed(error)
            }
        }
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
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey.hasPrefix("Bearer ") ? apiKey : "Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body for title generation")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData
        request.timeoutInterval = 90

        do {
            let (data, response) = try await dataWithRetry(for: request)

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

    func generateChatResponse(messages: [Message], model: String, tools: [[String: Any]] = []) async throws -> ChatServiceResponse {
        let urlString = "\(baseURL)/chat"
        print("Attempting to connect to: \(urlString)")
        print("BaseURL: \(baseURL)")

        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            throw URLError(.badURL)
        }

        // Convert messages to Ollama format, handling tool roles and tool_calls fields
        let ollamaMessages: [[String: Any]] = messages.map { message in
            switch message.role {
            case .system:
                return ["role": message.role.rawValue, "content": message.content]
            case .user:
                if let img = message.imageAttachment {
                    // Ollama vision: pass base64 image(s) alongside the text content
                    return ["role": "user", "content": message.content, "images": [img.base64Data]]
                }
                return ["role": "user", "content": message.content]
            case .assistant:
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    let ollaCalls = toolCalls.map { call -> [String: Any] in
                        // Ollama expects arguments as an object, not a JSON string
                        let argsObj = (try? JSONSerialization.jsonObject(with: Data(call.arguments.utf8))) ?? [:]
                        var callDict: [String: Any] = [
                            "id": call.id,
                            "type": "function",
                            "function": ["name": call.name, "arguments": argsObj]
                        ]
                        // Thinking models (Qwen3, DeepSeek-R1, etc.) require thought_signature echoed back
                        if let sig = call.thoughtSignature {
                            callDict["thought_signature"] = sig
                        }
                        return callDict
                    }
                    var assistantDict: [String: Any] = ["role": "assistant", "tool_calls": ollaCalls]
                    if !message.content.isEmpty { assistantDict["content"] = message.content }
                    return assistantDict
                }
                return ["role": "assistant", "content": message.content]
            case .tool:
                var dict: [String: Any] = ["role": "tool", "content": message.content]
                if let id = message.toolCallId { dict["tool_call_id"] = id }
                if let name = message.toolName { dict["name"] = name }
                return dict
            }
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": ollamaMessages,
            "stream": false
        ]
        if !tools.isEmpty {
            requestBody["tools"] = tools
            print("[OllamaService] Sending \(tools.count) tool(s) in request")
        }
        print("[OllamaService] Request: model=\(model), messages=\(ollamaMessages.count)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey.hasPrefix("Bearer ") ? apiKey : "Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            print("Using API key for authentication")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData
        request.timeoutInterval = 90

        do {
            print("Sending request to Ollama...")
            #if DEBUG
            let start = Date()
            let (data, response) = try await dataWithRetry(for: request)
            print("[OllamaService] Chat request took \(String(format: "%.1f", Date().timeIntervalSince(start)))s")
            #else
            let (data, response) = try await dataWithRetry(for: request)
            #endif

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

                    let errorMessage = "Server error \(httpResponse.statusCode) \(statusString)\(errorBody)"

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

                    throw NSError(domain: errorDomain, code: errorCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("Response data: \(responseString)")
            }

            // Check for tool_calls via raw JSON before attempting Codable decode
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageDict = jsonObject["message"] as? [String: Any],
               let toolCallsData = messageDict["tool_calls"] as? [[String: Any]],
               !toolCallsData.isEmpty {

                print("[OllamaService] Response contains \(toolCallsData.count) tool call(s) — parsing...")
                var toolCalls: [ToolCall] = []
                for callData in toolCallsData {
                    if let function_ = callData["function"] as? [String: Any],
                       let name = function_["name"] as? String {
                        let argsObj = function_["arguments"] ?? [:]
                        let argsString: String
                        if let argsData = try? JSONSerialization.data(withJSONObject: argsObj),
                           let str = String(data: argsData, encoding: .utf8) {
                            argsString = str
                        } else {
                            argsString = "{}"
                        }
                        let callId = callData["id"] as? String ?? UUID().uuidString
                        let thoughtSignature = callData["thought_signature"] as? String
                        print("[OllamaService] Tool call: id=\(callId) \(name)(\(argsString))\(thoughtSignature != nil ? " [has thought_signature]" : " [no thought_signature]")")
                        toolCalls.append(ToolCall(id: callId, name: name, arguments: argsString, thoughtSignature: thoughtSignature))
                    }
                }
                if !toolCalls.isEmpty {
                    return .toolCalls(toolCalls)
                }
            }

            // Try Codable decode for regular text responses
            do {
                let ollamaResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
                var content = ollamaResponse.message.content

                // Always extract the thinking field if present (reasoning models like DeepSeek-R1, Qwen3)
                var thinkingContent: String? = nil
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let messageDict = jsonObject["message"] as? [String: Any],
                   let thinking = messageDict["thinking"] as? String,
                   !thinking.isEmpty {
                    thinkingContent = thinking
                }

                // Fallback: some models (e.g. kimi-k2.5) put the answer in "thinking" and leave "content" empty
                if content.isEmpty, let thinking = thinkingContent {
                    print("[OllamaService] content empty — using thinking field as response (\(thinking.count) chars)")
                    content = thinking
                    thinkingContent = nil  // avoid showing it twice
                } else if thinkingContent != nil {
                    print("[OllamaService] thinking field present (\(thinkingContent!.count) chars)")
                }

                print("Successfully received response: \(content)")
                return .text(content, thinking: thinkingContent)
            } catch {
                print("Failed to decode as OllamaChatResponse: \(error)")
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let messageDict = jsonObject["message"] as? [String: Any] {
                    let content = messageDict["content"] as? String ?? ""
                    let thinking = messageDict["thinking"] as? String ?? ""
                    let resolved = content.isEmpty ? thinking : content
                    let thinkingToShow: String? = (!content.isEmpty && !thinking.isEmpty) ? thinking : nil
                    if !resolved.isEmpty {
                        print("Extracted content directly: \(resolved)")
                        return .text(resolved, thinking: thinkingToShow)
                    }
                }
                throw error
            }
        } catch let decodingError as DecodingError {
            print("Decoding error in generateChatResponse: \(decodingError)")
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
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey.hasPrefix("Bearer ") ? apiKey : "Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            print("Fetching models from Ollama...")
            let (data, response) = try await session.data(for: request)

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
        if let apiKey = secureStorage.getAPIKey(),
           !apiKey.isEmpty {
            request.setValue(apiKey.hasPrefix("Bearer ") ? apiKey : "Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("Failed to serialize request body for model details")
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            print("Fetching model details from Ollama...")
            let (data, response) = try await session.data(for: request)

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

/// Unified response type for chat APIs — either plain text or a list of tool calls to execute.
enum ChatServiceResponse {
    case text(String, thinking: String?)
    case toolCalls([ToolCall])
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