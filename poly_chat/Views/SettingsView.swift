import SwiftUI

private enum ValidationState {
    case idle
    case testing
    case success(String)
    case failure(String)
}

struct SettingsView: View {
    @State private var ollamaEndpoint = "https://ollama.com/api"
    @State private var apiKey = ""
    @State private var braveAPIKey = ""
    @AppStorage("darkMode") private var darkMode = false
    @State private var systemPrompt = ""
    @State private var showingDeleteAlert = false
    @State private var showingExportView = false
    @State private var exportedData: Data?
    @State private var ollamaStatus: ValidationState = .idle
    @State private var tavilyStatus: ValidationState = .idle
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var chatManager: ChatManager

    let localStorageService = LocalStorageService()
    let secureStorageService = SecureStorageService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ollama Configuration")) {
                    TextField("Endpoint", text: $ollamaEndpoint)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                        .onSubmit { saveSettings() }
                        .onChange(of: ollamaEndpoint) { _ in
                            saveSettings()
                            ollamaStatus = .idle
                        }
                    TextField("API Key (optional)", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit { saveSettings() }
                        .onChange(of: apiKey) { _ in
                            saveSettings()
                            ollamaStatus = .idle
                        }
                    Button("Test Connection") {
                        saveSettings()
                        ollamaStatus = .testing
                        Task {
                            do {
                                try await OllamaService.validateConnection(
                                    endpoint: ollamaEndpoint,
                                    apiKey: apiKey.isEmpty ? nil : apiKey
                                )
                                ollamaStatus = .success("Connected")
                            } catch {
                                ollamaStatus = .failure(error.localizedDescription)
                            }
                        }
                    }
                    .disabled(ollamaEndpoint.isEmpty || {
                        if case .testing = ollamaStatus { return true }
                        return false
                    }())
                    statusRow(ollamaStatus)
                }

                Section(header: Text("Web Search")) {
                    SecureField("Tavily API Key", text: $braveAPIKey)
                        .textContentType(.password)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit { saveSettings() }
                        .onChange(of: braveAPIKey) { _ in
                            saveSettings()
                            tavilyStatus = .idle
                        }
                    Button("Test Key") {
                        saveSettings()
                        tavilyStatus = .testing
                        Task {
                            do {
                                try await WebSearchService.shared.validateAPIKey()
                                tavilyStatus = .success("Key is valid")
                            } catch {
                                tavilyStatus = .failure(error.localizedDescription)
                            }
                        }
                    }
                    .disabled(braveAPIKey.isEmpty || {
                        if case .testing = tavilyStatus { return true }
                        return false
                    }())
                    statusRow(tavilyStatus)
                    Link("Get a free key at app.tavily.com", destination: URL(string: "https://app.tavily.com")!)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text("1,000 free searches/month. When configured, models that support tool use will automatically search the web for current information.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                        .onChange(of: darkMode) { _ in saveSettings() }
                }

                Section(header: Text("Default System Prompt")) {
                    TextEditor(text: $systemPrompt)
                        .frame(height: 100)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: systemPrompt) { _ in saveSettings() }
                    Text("This prompt will be added to the beginning of each new conversation to help the model understand your preferences.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Data Management")) {
                    Button("Export Conversations") {
                        exportConversations()
                    }
                    Button("Delete All Conversations") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("About")) {
                    Text("PolyChat v1.0")
                    Text("Open source AI chat application")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Confirm Deletion", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) { deleteAllConversations() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete all conversations? This cannot be undone.")
            }
            .sheet(isPresented: $showingExportView) {
                if let data = exportedData {
                    SimpleShareView(data: data)
                }
            }
            .onAppear { loadSettings() }
        }
    }

    @ViewBuilder
    private func statusRow(_ state: ValidationState) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.75)
                Text("Testing…").font(.caption).foregroundColor(.secondary)
            }
        case .success(let msg):
            Label(msg, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }

    private func loadSettings() {
        if let savedEndpoint = secureStorageService.getEndpoint() {
            ollamaEndpoint = savedEndpoint
        }
        if let savedApiKey = secureStorageService.getAPIKey() {
            apiKey = savedApiKey
        }
        if let savedBraveKey = secureStorageService.getBraveAPIKey() {
            braveAPIKey = savedBraveKey
        }
        systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
    }

    private func saveSettings() {
        var normalizedEndpoint = ollamaEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalizedEndpoint.hasSuffix("/") { normalizedEndpoint.removeLast() }

        secureStorageService.saveEndpoint(normalizedEndpoint)
        secureStorageService.saveAPIKey(apiKey)
        secureStorageService.saveBraveAPIKey(braveAPIKey)
        UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt")

        print("Saved settings - Endpoint: \(normalizedEndpoint), API Key present: \(!apiKey.isEmpty)")
    }

    private func exportConversations() {
        let conversations = chatManager.conversations
        do {
            let data = try JSONEncoder().encode(conversations)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("polychat_export.json")
            try data.write(to: tempURL)
            exportedData = data
            showingExportView = true
        } catch {
            print("Error exporting conversations: \(error)")
        }
    }

    private func deleteAllConversations() {
        chatManager.conversations.removeAll()
        localStorageService.deleteAllData()
    }
}
