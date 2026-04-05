import Foundation
import Combine
import UniformTypeIdentifiers
import PDFKit
import UIKit

class ChatManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeToolName: String?
    @Published var showOutOfCreditsAlert = false
    @Published var showWebSearchFailedAlert = false
    @Published var showInvalidKeyAlert = false
    @Published var tavilyKeyInvalid: Bool = UserDefaults.standard.bool(forKey: "tavilyKeyInvalid") {
        didSet { UserDefaults.standard.set(tavilyKeyInvalid, forKey: "tavilyKeyInvalid") }
    }
    @Published var sendError: NSError? = nil
    @Published var activeConversationId: UUID? = nil

    private let storageService = LocalStorageService()
    private var activeSendTask: Task<Void, Never>? = nil

    init() {
        loadConversations()
    }

    func loadConversations() {
        conversations = storageService.loadConversations()
    }

    private func conversationIndex(for id: UUID) -> Int? {
        conversations.firstIndex(where: { $0.id == id })
    }

    func cancelActiveRequest() {
        activeSendTask?.cancel()
        activeSendTask = nil
        isLoading = false
        activeToolName = nil
        activeConversationId = nil
    }

    func createNewConversation(model: ModelInfo) -> Conversation {
        var newConversation = Conversation(title: "New Chat", model: model)

        // Add system prompt to new conversation if configured
        if let systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt"),
           !systemPrompt.isEmpty {
            let systemMessage = Message(
                id: UUID(),
                role: .system,
                content: systemPrompt,
                timestamp: Date()
            )
            newConversation.messages.append(systemMessage)
        }

        conversations.insert(newConversation, at: 0)
        storageService.saveConversations(conversations)
        return newConversation
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        storageService.saveConversations(conversations)

        // Clean up any PDF files that are no longer referenced by any conversation
        Task { [weak self] in
            await self?.cleanupUnusedPDFFiles()
        }
    }

    /// Clean up PDF files that are no longer referenced by any conversation
    private func cleanupUnusedPDFFiles() async {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        // Get all filenames from all conversations
        var usedFilenames = Set<String>()
        for conversation in conversations {
            for message in conversation.messages {
                if let filename = message.documentAttachment?.filename {
                    usedFilenames.insert(filename)
                }
            }
        }

        // Remove PDF files not in the used list
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            for fileURL in files {
                if fileURL.pathExtension == "pdf" {
                    if !usedFilenames.contains(fileURL.lastPathComponent) {
                        print("Removing unused PDF: \(fileURL.lastPathComponent)")
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        } catch {
            print("Error cleaning up PDF files: \(error)")
        }
    }

    func renameConversation(_ conversation: Conversation, to newName: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            return
        }

        conversations[index].title = newName
        conversations[index].updatedAt = Date()
        storageService.saveConversations(conversations)
    }

    /// Send a message with PDF document attachment
    /// - Parameters:
    ///   - message: The text message to send
    ///   - conversation: The conversation to send to
    ///   - pdfFileURL: The URL of the PDF file to attach
    /// - Returns: The assistant's response
    /// - Throws: ChatError or PDFDocumentService.PDFError
    func sendMessage(_ message: String, in conversation: Conversation, withPDFAt pdfFileURL: URL) async throws -> String {
        do {
            let documentAttachment = try await PDFDocumentService.shared.processPDF(from: pdfFileURL)
            return try await sendMessage(message, in: conversation, with: documentAttachment)
        } catch {
            // Handle all errors as PDF processing failures
            throw ChatError.pdfProcessingFailed(error)
        }
    }

    /// Send a message with an image attachment (for vision-capable models)
    func sendMessage(_ message: String, in conversation: Conversation, withImage image: UIImage) async throws -> String {
        // Compress to JPEG at ≤800px, 80% quality to keep storage reasonable
        let maxDimension: CGFloat = 800
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }

        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else {
            throw ChatError.imageProcessingFailed(NSError(domain: "ChatError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"]))
        }

        let base64 = jpegData.base64EncodedString()
        let imageAttachment = ImageAttachment(base64Data: base64, mimeType: "image/jpeg")
        return try await sendMessage(message, in: conversation, imageAttachment: imageAttachment)
    }

    /// Starts a send in a Task owned by ChatManager so it survives view navigation.
    func startSendMessage(
        _ message: String,
        in conversation: Conversation,
        fileURL: URL? = nil,
        image: UIImage? = nil,
        onSuccess: (@MainActor () -> Void)? = nil
    ) {
        activeSendTask?.cancel()
        sendError = nil
        activeSendTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.activeConversationId = conversation.id

            // Ask iOS for extra background execution time so the request survives
            // the user switching away from the app (grants up to ~3 minutes).
            var bgTaskID = UIBackgroundTaskIdentifier.invalid
            bgTaskID = UIApplication.shared.beginBackgroundTask {
                // Expiration handler: iOS is about to suspend the process.
                // End the task to avoid being killed.
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }

            defer {
                self.isLoading = false
                self.activeConversationId = nil
                if bgTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTaskID)
                }
            }

            do {
                if let fileURL {
                    _ = try await self.sendMessage(message, in: conversation, withPDFAt: fileURL)
                } else if let image {
                    _ = try await self.sendMessage(message, in: conversation, withImage: image)
                } else {
                    _ = try await self.sendMessage(message, in: conversation)
                }
                onSuccess?()
            } catch is CancellationError {
                // User cancelled — no error to show
            } catch {
                self.sendError = error as NSError
            }
        }
    }

    func sendMessage(_ message: String, in conversation: Conversation, with documentAttachment: DocumentAttachment? = nil, imageAttachment: ImageAttachment? = nil) async throws -> String {
        // Clear any previous error message
        errorMessage = nil

        // Find the conversation in our list
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            throw ChatError.conversationNotFound
        }

        var updatedConversation = conversations[index]

        // If we have a document attachment, enrich the message content now
        // This ensures only one message is created with both text and document info
        var finalContent = message
        if let attachment = documentAttachment, !attachment.textContent.isEmpty {
            finalContent = message + "\n\n--- Attached Document: \(attachment.filename) ---\n\(attachment.textContent)\n--- End of Attachment ---"
        }

        let userMessage = Message(
            id: UUID(),
            role: .user,
            content: finalContent,
            timestamp: Date(),
            documentAttachment: documentAttachment,
            imageAttachment: imageAttachment
        )
        updatedConversation.messages.append(userMessage)

        // Update timestamp
        updatedConversation.updatedAt = Date()

        // Update conversation in the list
        conversations[index] = updatedConversation

        // Save to local storage
        storageService.saveConversations(conversations)

        // Use regular flow
        return try await sendRegularMessage(conversation: updatedConversation, conversationId: conversation.id)
    }

    // MARK: - Web Search Tool Definition

    static let currentDateTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "get_current_date",
            "description": "Returns the current date, time, and timezone. Call this when the user's question depends on today's date, the current time, recent events, or the weather.",
            "parameters": [
                "type": "object",
                "properties": [:] as [String: Any],
                "required": [] as [String]
            ]
        ]
    ]

    static let webSearchTool: [String: Any] = [
        "type": "function",
        "function": [
            "name": "web_search",
            "description": "Search the web for current news, facts, or any information that may have changed since your training. Use this when the user asks about recent events, live data, or anything time-sensitive.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "A concise search query"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]

    private func extractSearchQuery(from arguments: String) -> String? {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? String else { return nil }
        return query
    }

    private func sendRegularMessage(conversation: Conversation, conversationId: UUID) async throws -> String {
        // Don't send tools when the latest user message has an image — vision queries are
        // descriptive and sending tool prompts causes some thinking models (e.g. Qwen3-VL)
        // to output meta-commentary about tool decisions instead of answering the question.
        let latestUserMessage = conversation.messages.last(where: { $0.role == .user })
        let hasImageAttachment = latestUserMessage?.imageAttachment != nil

        var tools: [[String: Any]] = []
        if !hasImageAttachment {
            tools.append(ChatManager.currentDateTool)
            if WebSearchService.shared.apiKey != nil { tools.append(ChatManager.webSearchTool) }
        }

        var workingMessages = conversation.messages
        var collectedSearchResults: [String] = []
        let maxToolIterations = 3

        let webSearchEnabled = tools.contains(where: { ($0["function"] as? [String: Any])?["name"] as? String == "web_search" })
        print("[ToolLoop] ── START ──────────────────────────────────")
        print("[ToolLoop] Model: \(conversation.model.name)")
        print("[ToolLoop] Image message: \(hasImageAttachment ? "YES — tools suppressed" : "no")")
        print("[ToolLoop] Web search: \(webSearchEnabled ? "ENABLED (Tavily key found)" : "DISABLED (no Tavily key)")")
        print("[ToolLoop] Messages in context: \(workingMessages.count)")

        do {
            for iteration in 0..<maxToolIterations {
                // On the final iteration strip tools so well-behaved models are forced to
                // synthesize a text answer from whatever they've gathered so far.
                let isLastIteration = iteration == maxToolIterations - 1
                let iterationTools = isLastIteration ? [[String: Any]]() : tools
                if isLastIteration && !tools.isEmpty {
                    let searchCount = collectedSearchResults.count
                    let dateCount = workingMessages.filter { $0.toolName == "get_current_date" }.count
                    print("[ToolLoop] Final iteration — stripping tools to force text answer")
                    print("[ToolLoop] Context summary: \(searchCount) search result(s), \(dateCount) date result(s)")
                }
                // Log A: show the role/type sequence the model will receive
                let contextDesc = workingMessages.map { msg -> String in
                    if msg.role == .assistant, let calls = msg.toolCalls, !calls.isEmpty {
                        return "asst(\(calls.map { $0.name }.joined(separator: ",")))"
                    } else if msg.role == .tool {
                        return "tool(\(msg.toolCallId?.prefix(8) ?? "?"):\(msg.toolName ?? "?"))"
                    }
                    return msg.role.rawValue
                }.joined(separator: " → ")
                print("[ToolLoop] Iteration \(iteration + 1)/\(maxToolIterations) — sending \(workingMessages.count) message(s)")
                print("[ToolLoop] Context: \(contextDesc)")

                let chatResponse: ChatServiceResponse

                try Task.checkCancellation()
                // Route by per-model providerId (custom endpoints), then fall back to
                // the active provider check, then default to Ollama.
                if let pid = conversation.model.providerId,
                   let customProvider = ProviderManager.shared.customProvider(for: pid) {
                    print("[ToolLoop] Routing to custom OpenAI adapter (provider: \(customProvider.name))")
                    let adapter = OpenAIBackendAdapter(providerConfig: customProvider)
                    chatResponse = try await adapter.generateChatResponseWithTools(
                        messages: workingMessages,
                        model: conversation.model.name,
                        tools: iterationTools
                    )
                } else if let provider = ProviderManager.shared.getActiveProvider(),
                          provider.providerType == .openAICompatible {
                    print("[ToolLoop] Routing to OpenAI adapter (provider: \(provider.name))")
                    let adapter = OpenAIBackendAdapter(providerConfig: provider)
                    chatResponse = try await adapter.generateChatResponseWithTools(
                        messages: workingMessages,
                        model: conversation.model.name,
                        tools: iterationTools
                    )
                } else {
                    print("[ToolLoop] Routing to OllamaService")
                    chatResponse = try await OllamaService.shared.generateChatResponse(
                        messages: workingMessages,
                        model: conversation.model.name,
                        tools: iterationTools
                    )
                }
                try Task.checkCancellation()

                switch chatResponse {
                case .text(let content, let thinking):
                    print("[ToolLoop] Got TEXT response (\(content.count) chars) — done")
                    if let t = thinking { print("[ToolLoop] Thinking trace: \(t.count) chars") }
                    print("[ToolLoop] ── END ────────────────────────────────────")
                    let assistantMessage = Message(id: UUID(), role: .assistant, content: content, timestamp: Date(), thinkingContent: thinking)
                    // Re-resolve index by ID so a new chat inserted since the request started
                    // doesn't cause the response to land in the wrong conversation.
                    guard let idx = conversationIndex(for: conversationId) else { return content }
                    var updatedConversation = conversations[idx]
                    updatedConversation.messages.append(assistantMessage)
                    updatedConversation.updatedAt = Date()
                    conversations[idx] = updatedConversation
                    storageService.saveConversations(conversations)

                    if needsTitleUpdate(conversation: updatedConversation) {
                        Task { [weak self] in
                            await self?.updateTitleForConversation(updatedConversation)
                        }
                    }
                    return content

                case .toolCalls(let toolCalls):
                    print("[ToolLoop] Got TOOL CALLS: \(toolCalls.map { "\($0.name)(id:\($0.id.prefix(8)))" }.joined(separator: ", "))")

                    // Log B: detect repeated calls with identical arguments
                    let prevCalls = workingMessages.compactMap { $0.toolCalls }.flatMap { $0 }
                    for call in toolCalls {
                        if prevCalls.contains(where: { $0.name == call.name && $0.arguments == call.arguments }) {
                            print("[ToolLoop] ⚠️ REPEAT CALL: \(call.name) called again with same arguments: \(call.arguments)")
                        }
                    }

                    let assistantToolMsg = Message(id: UUID(), role: .assistant, content: "", timestamp: Date(), toolCalls: toolCalls)
                    workingMessages.append(assistantToolMsg)

                    for call in toolCalls {
                        DispatchQueue.main.async { self.activeToolName = call.name }
                        let result: String
                        if call.name == "get_current_date" {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .full
                            formatter.timeStyle = .long
                            formatter.locale = Locale.current
                            formatter.timeZone = TimeZone.current
                            result = "Current date and time: \(formatter.string(from: Date())) (\(TimeZone.current.identifier))"
                            print("[ToolLoop] get_current_date → \(result)")
                        } else if call.name == "web_search" {
                            let query = extractSearchQuery(from: call.arguments) ?? call.arguments
                            print("[ToolLoop] Dispatching web_search, query: \"\(query)\"")
                            do {
                                result = try await WebSearchService.shared.search(query: query)
                                print("[ToolLoop] Search result: \(result.count) chars")
                                collectedSearchResults.append(result)
                                DispatchQueue.main.async { self.tavilyKeyInvalid = false }
                            } catch WebSearchService.WebSearchError.invalidKey {
                                print("[ToolLoop] Search FAILED — invalid API key")
                                DispatchQueue.main.async {
                                    self.tavilyKeyInvalid = true
                                    self.showInvalidKeyAlert = true
                                }
                                result = "Web search failed: API key is invalid."
                            } catch WebSearchService.WebSearchError.outOfCredits {
                                print("[ToolLoop] Search FAILED — out of credits")
                                DispatchQueue.main.async { self.showOutOfCreditsAlert = true }
                                result = "Web search unavailable: API credits exhausted."
                            } catch {
                                print("[ToolLoop] Search FAILED: \(error)")
                                DispatchQueue.main.async { self.showWebSearchFailedAlert = true }
                                result = "Web search failed: \(error.localizedDescription)"
                            }
                        } else {
                            print("[ToolLoop] Unknown tool requested: \(call.name)")
                            result = "Unknown tool: \(call.name)"
                        }
                        DispatchQueue.main.async { self.activeToolName = nil }
                        // Log C: confirm result is correlated to the call that requested it
                        print("[ToolLoop] Tool result: \(call.id.prefix(12)) → \(call.name) → \(result.count) chars")
                        let toolResultMsg = Message(id: UUID(), role: .tool, content: result, timestamp: Date(), toolCallId: call.id, toolName: call.name)
                        workingMessages.append(toolResultMsg)
                    }
                }
            }

            // Model kept tool-calling without answering even after exhausting all iterations.
            // Sending the same tool-heavy history again won't help — some models (e.g. nemotron)
            // ignore tools:[] and keep generating tool calls when they see role:tool messages.
            // Instead, build a fresh single-turn prompt that embeds all gathered search results
            // as plain text context. This breaks the tool-loop pattern completely.
            print("[ToolLoop] Max iterations reached — rebuilding prompt with search context")
            let userQuery = conversation.messages.last(where: { $0.role == .user })?.content ?? ""
            let searchResults = collectedSearchResults.joined(separator: "\n\n---\n\n")
            let syntheticContent = searchResults.isEmpty
                ? userQuery
                : "\(userQuery)\n\nHere is information gathered from web searches:\n\n\(searchResults)\n\nPlease answer based on the above information."
            let syntheticMessages = [Message(id: UUID(), role: .user, content: syntheticContent, timestamp: Date())]

            let finalResponse: ChatServiceResponse
            if let pid = conversation.model.providerId,
               let customProvider = ProviderManager.shared.customProvider(for: pid) {
                let adapter = OpenAIBackendAdapter(providerConfig: customProvider)
                finalResponse = try await adapter.generateChatResponseWithTools(
                    messages: syntheticMessages, model: conversation.model.name, tools: [])
            } else if let provider = ProviderManager.shared.getActiveProvider(),
                      provider.providerType == .openAICompatible {
                let adapter = OpenAIBackendAdapter(providerConfig: provider)
                finalResponse = try await adapter.generateChatResponseWithTools(
                    messages: syntheticMessages, model: conversation.model.name, tools: [])
            } else {
                finalResponse = try await OllamaService.shared.generateChatResponse(
                    messages: syntheticMessages, model: conversation.model.name, tools: [])
            }
            guard case .text(let content, let thinking) = finalResponse else {
                throw NSError(domain: "ChatError", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Model continued tool-calling after max iterations."])
            }
            print("[ToolLoop] Synthetic prompt answer (\(content.count) chars)")
            print("[ToolLoop] ── END (synthetic) ───────────────────────────")
            let assistantMessage = Message(id: UUID(), role: .assistant, content: content, timestamp: Date(), thinkingContent: thinking)
            guard let idxForced = conversationIndex(for: conversationId) else { return content }
            var updatedConversationForced = conversations[idxForced]
            updatedConversationForced.messages.append(assistantMessage)
            updatedConversationForced.updatedAt = Date()
            conversations[idxForced] = updatedConversationForced
            storageService.saveConversations(conversations)
            if needsTitleUpdate(conversation: updatedConversationForced) {
                Task { [weak self] in await self?.updateTitleForConversation(updatedConversationForced) }
            }
            return content

        } catch let nsError as NSError where nsError.localizedDescription.contains("thought_signature") {
            DispatchQueue.main.async { self.activeToolName = nil }
            // Some models (e.g. Gemini via Ollama) require thought_signature in tool calls but don't
            // return it in responses — Ollama strips it. Retry the original messages without tools.
            print("[ToolLoop] thought_signature incompatibility — retrying without tools")
            let fallback = try await OllamaService.shared.generateChatResponse(
                messages: conversation.messages,
                model: conversation.model.name,
                tools: []
            )
            guard case .text(let content, let thinking) = fallback else {
                throw NSError(domain: "ChatError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unexpected tool call in fallback."])
            }
            print("[ToolLoop] Fallback succeeded (\(content.count) chars)")
            print("[ToolLoop] ── END (fallback) ─────────────────────")
            let assistantMessage = Message(id: UUID(), role: .assistant, content: content, timestamp: Date(), thinkingContent: thinking)
            guard let idxFallback = conversationIndex(for: conversationId) else { return content }
            var updatedConversationFallback = conversations[idxFallback]
            updatedConversationFallback.messages.append(assistantMessage)
            updatedConversationFallback.updatedAt = Date()
            conversations[idxFallback] = updatedConversationFallback
            storageService.saveConversations(conversations)
            if needsTitleUpdate(conversation: updatedConversationFallback) {
                Task { [weak self] in await self?.updateTitleForConversation(updatedConversationFallback) }
            }
            return content

        } catch {
            print("[ToolLoop] CAUGHT ERROR: \(error)")
            print("[ToolLoop] ── END (error) ──────────────────────────")
            activeToolName = nil
            let errorContent = "Error: \(error.localizedDescription)"
            let errorMsg = Message(id: UUID(), role: .assistant, content: errorContent, timestamp: Date())
            if let idxError = conversationIndex(for: conversationId) {
                var errorConversation = conversations[idxError]
                errorConversation.messages.append(errorMsg)
                errorConversation.updatedAt = Date()
                conversations[idxError] = errorConversation
                storageService.saveConversations(conversations)
            }
            errorMessage = error.localizedDescription
            throw error
        }
    }

    /// Checks if the conversation needs a title update (first user + assistant exchange completed)
    private func needsTitleUpdate(conversation: Conversation) -> Bool {
        // Filter out system messages
        let nonSystemMessages = conversation.messages.filter { $0.role != .system }

        // Need exactly 2 messages (user + assistant) to generate meaningful title on first exchange
        guard nonSystemMessages.count == 2 else {
            return false
        }

        // Check if title is still "New Chat" (meaning it hasn't been updated yet)
        return conversation.title == "New Chat"
    }

    /// Update a message and truncate the conversation after that message
    /// - Parameters:
    ///   - messageId: The ID of the message to update
    ///   - newContent: The new content for the message
    ///   - conversation: The conversation containing the message
    func updateMessage(_ messageId: UUID, to newContent: String, in conversation: Conversation) async throws {
        // Find the conversation in our list
        guard let index = conversations.firstIndex(where: { $0.id == conversation.id }) else {
            throw ChatError.conversationNotFound
        }

        var updatedConversation = conversations[index]

        // Find the message to update
        guard let messageIndex = updatedConversation.messages.firstIndex(where: { $0.id == messageId }) else {
            throw ChatError.messageNotFound
        }

        // Update the message content
        var updatedMessage = updatedConversation.messages[messageIndex]
        updatedMessage.content = newContent
        updatedConversation.messages[messageIndex] = updatedMessage

        // Truncate all messages after the updated message
        updatedConversation.messages.removeSubrange((messageIndex + 1)..<updatedConversation.messages.count)

        // Update timestamp
        updatedConversation.updatedAt = Date()

        // Update conversation in the list
        conversations[index] = updatedConversation

        // Save to local storage
        storageService.saveConversations(conversations)

        // Resend to get a fresh AI response for the edited message
        isLoading = true
        defer { isLoading = false }
        _ = try await sendRegularMessage(conversation: updatedConversation, conversationId: conversation.id)
    }

    /// Update conversation title using LLM based on message content
    private func updateTitleForConversation(_ conversation: Conversation) async {
        // Filter out system messages for title generation
        let nonSystemMessages = conversation.messages.filter { $0.role != .system }

        guard nonSystemMessages.count >= 2 else {
            return
        }

        let newTitle = await NameGenerationService.shared.generateTitleFromMessages(nonSystemMessages, model: conversation.model)

        // Only update if we got a valid title and it's different from "New Chat"
        if !newTitle.isEmpty && newTitle != "New Chat" {
            if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
                conversations[index].title = newTitle
                conversations[index].updatedAt = Date()
                storageService.saveConversations(conversations)
                print("Updated title to: \(newTitle)")
            }
        }
    }
}

enum ChatError: Error {
    case conversationNotFound
    case pdfProcessingFailed(Error)
    case imageProcessingFailed(Error)
    case documentTooLarge
    case noTextInDocument
    case invalidPDF
    case messageNotFound
}
