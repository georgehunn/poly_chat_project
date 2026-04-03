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
        let chatResponse = try await generateChatResponseWithTools(messages: messages, model: model, tools: [])
        switch chatResponse {
        case .text(let content, _):
            return Message(role: .assistant, content: content)
        case .toolCalls:
            return Message(role: .assistant, content: "")
        }
    }

    func generateChatResponseWithTools(messages: [Message], model: String, tools: [[String: Any]]) async throws -> ChatServiceResponse {
        let urlString = "\(providerConfig.endpoint)/chat/completions"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        // Convert messages to OpenAI format, handling tool roles and tool_calls fields
        let openAIMessages: [[String: Any]] = messages.map { message in
            switch message.role {
            case .system:
                return ["role": "system", "content": message.content]
            case .user:
                if let img = message.imageAttachment {
                    // OpenAI vision: content must be an array of typed parts
                    let contentArray: [[String: Any]] = [
                        ["type": "text", "text": message.content],
                        ["type": "image_url", "image_url": ["url": "data:\(img.mimeType);base64,\(img.base64Data)"]]
                    ]
                    return ["role": "user", "content": contentArray]
                }
                return ["role": "user", "content": message.content]
            case .assistant:
                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    let oaiCalls = toolCalls.map { call -> [String: Any] in
                        var callDict: [String: Any] = [
                            "id": call.id,
                            "type": "function",
                            "function": ["name": call.name, "arguments": call.arguments]
                        ]
                        // Grok and other extended-thinking providers require thought_signature echoed back
                        if let sig = call.thoughtSignature {
                            callDict["thought_signature"] = sig
                        }
                        return callDict
                    }
                    return ["role": "assistant", "content": NSNull(), "tool_calls": oaiCalls]
                }
                return ["role": "assistant", "content": message.content]
            case .tool:
                var dict: [String: Any] = ["role": "tool", "content": message.content]
                if let toolCallId = message.toolCallId {
                    dict["tool_call_id"] = toolCallId
                }
                return dict
            }
        }

        var requestBody: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
            "stream": false
        ]
        if !tools.isEmpty {
            requestBody["tools"] = tools
            print("[OpenAIAdapter] Sending \(tools.count) tool(s) in request")
        }
        print("[OpenAIAdapter] Request: model=\(model), messages=\(openAIMessages.count), endpoint=\(providerConfig.endpoint)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !providerConfig.apiKey.isEmpty {
            request.setValue("Bearer \(providerConfig.apiKey)", forHTTPHeaderField: "Authorization")
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw URLError(.cannotParseResponse)
        }

        request.httpBody = jsonData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("[OpenAIAdapter] HTTP \(httpResponse.statusCode)")
                if httpResponse.statusCode >= 400 {
                    let statusString = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
                    var errorBody = ""
                    if let responseString = String(data: data, encoding: .utf8) {
                        errorBody = ": \(responseString)"
                        print("[OpenAIAdapter] ERROR body: \(responseString)")
                    }
                    throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode) \(statusString)\(errorBody)"])
                }
            }

            // Check for tool_calls via raw JSON first — OpenAI sets content=null on tool call responses,
            // which would crash the Codable struct.
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = jsonObject["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let messageDict = firstChoice["message"] as? [String: Any] {

                if let toolCallsData = messageDict["tool_calls"] as? [[String: Any]], !toolCallsData.isEmpty {
                    print("[OpenAIAdapter] Response contains \(toolCallsData.count) tool call(s) — parsing...")
                    var toolCalls: [ToolCall] = []
                    for callData in toolCallsData {
                        let callId = callData["id"] as? String ?? UUID().uuidString
                        let thoughtSignature = callData["thought_signature"] as? String
                        if let function_ = callData["function"] as? [String: Any],
                           let name = function_["name"] as? String,
                           let arguments = function_["arguments"] as? String {
                            print("[OpenAIAdapter] Tool call: \(name)(\(arguments))\(thoughtSignature != nil ? " [has thought_signature]" : "")")
                            toolCalls.append(ToolCall(id: callId, name: name, arguments: arguments, thoughtSignature: thoughtSignature))
                        }
                    }
                    if !toolCalls.isEmpty {
                        return .toolCalls(toolCalls)
                    }
                }

                if let content = messageDict["content"] as? String {
                    let thinking = messageDict["thinking"] as? String
                    let thinkingContent: String? = (thinking != nil && !thinking!.isEmpty) ? thinking : nil
                    return .text(content, thinking: thinkingContent)
                }
            }

            // Fallback: Codable decode
            let openAIResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            let msg = openAIResponse.choices[0].message
            let thinkingContent: String? = msg.thinking.flatMap { $0.isEmpty ? nil : $0 }
            return .text(msg.content, thinking: thinkingContent)
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
        let thinking: String?
    }

    struct Usage: Codable {
        let completionTokens: Int
        let promptTokens: Int
        let totalTokens: Int
    }
}
