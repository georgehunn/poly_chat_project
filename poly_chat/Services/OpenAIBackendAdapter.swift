import Foundation

/// Backend adapter for OpenAI-compatible APIs (Grok, OpenAI, etc.)
class OpenAIBackendAdapter: BackendAdapter {
    let name: String

    private let providerConfig: APIProviderConfig

    init(providerConfig: APIProviderConfig) {
        self.providerConfig = providerConfig
        self.name = providerConfig.name
    }

    /// Sends a message to the OpenAI-compatible API and returns a response
    /// - Parameters:
    ///   - messages: The conversation history
    ///   - model: The model to use for generation
    /// - Returns: The response message from the API
    func sendMessage(messages: [Message], model: String) async throws -> Message {
        let response = try await generateChatResponse(messages: messages, model: model)

        return Message(
            role: .assistant,
            content: response
        )
    }

    private func generateChatResponse(messages: [Message], model: String) async throws -> String {
        let urlString = "\(providerConfig.endpoint)/chat/completions"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        // Convert messages to the format expected by OpenAI API
        let openAIMessages = messages.map { message -> [String: String] in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
            "stream": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key if available
        if !providerConfig.apiKey.isEmpty {
            // Grok and OpenAI both use Bearer token
            request.setValue("Bearer \(providerConfig.apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 400 {
                    let statusString = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    var errorBody = ""
                    if let responseString = String(data: data, encoding: .utf8) {
                        errorBody = ": \(responseString)"
                    }
                    let errorMessage = "Server error \(httpResponse.statusCode) \(statusString)\(errorBody)"
                    throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }

            // Try to decode OpenAI-compatible response
            do {
                let openAIResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                return openAIResponse.choices[0].message.content
            } catch {
                // Try to extract content from generic JSON
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonObject["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return content
                }
                throw error
            }
        } catch let urlError as URLError {
            throw urlError
        } catch {
            throw error
        }
    }
}

// OpenAI-compatible response structure
struct OpenAIChatResponse: Codable {
    let id: String
    let choices: [Choice]
    let created: Int64
    let model: String
    let object: String
    let systemFingerprint: String?
    let usage: Usage?

    struct Choice: Codable {
        let finishReason: String?
        let index: Int
        let message: Message
    }

    struct Message: Codable {
        let content: String
        let role: String
    }

    struct Usage: Codable {
        let completionTokens: Int
        let promptTokens: Int
        let totalTokens: Int
    }
}
