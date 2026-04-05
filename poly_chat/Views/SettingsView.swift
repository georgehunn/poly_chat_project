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
    @State private var tavilyAPIKey = ""
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("showThinkingTraces") private var showThinkingTraces = true
    @State private var systemPrompt = ""
    @State private var showingDeleteAlert = false
    @State private var showingExportView = false
    @State private var tavilyStatus: ValidationState = .idle
    @State private var showingAddEndpoint = false
    @State private var endpointToEdit: APIProviderConfig?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var chatManager: ChatManager
    @ObservedObject private var providerManager = ProviderManager.shared

    let localStorageService = LocalStorageService()
    let secureStorageService = SecureStorageService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ollama Configuration")) {
                    TextField("Endpoint", text: $ollamaEndpoint)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .submitLabel(.done)
                        .onSubmit { saveSettings() }
                        .onChange(of: ollamaEndpoint) { _ in saveSettings() }
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit { saveSettings() }
                        .onChange(of: apiKey) { _ in saveSettings() }
                    Link("Get an Ollama API key at ollama.com", destination: URL(string: "https://ollama.com")!)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text("Ollama lets you run large language models locally or access hosted models. An API key is only required for remote/hosted Ollama instances.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Custom API Endpoints")) {
                    if providerManager.customProviders.isEmpty {
                        Text("No custom endpoints configured")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(providerManager.customProviders) { provider in
                            Button(action: { endpointToEdit = provider }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.name)
                                        .foregroundColor(.primary)
                                    Text(provider.endpoint)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { i in
                                providerManager.deleteCustomProvider(providerManager.customProviders[i])
                            }
                        }
                    }
                    Button(action: { showingAddEndpoint = true }) {
                        Label("Add Endpoint", systemImage: "plus.circle")
                    }
                    .foregroundColor(.accentColor)
                    Text("Add any OpenAI-compatible API endpoint. Models from these endpoints will appear alongside Ollama models when starting a new chat.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Web Search")) {
                    SecureField("Tavily API Key", text: $tavilyAPIKey)
                        .textContentType(.password)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit { saveSettings() }
                        .onChange(of: tavilyAPIKey) { _ in
                            saveSettings()
                            tavilyStatus = .idle
                            chatManager.tavilyKeyInvalid = false
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
                    .disabled(tavilyAPIKey.isEmpty || {
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
                    Toggle("Show thinking traces", isOn: $showThinkingTraces)
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
                        showingExportView = true
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
                ExportConversationsView(conversations: chatManager.conversations)
            }
            .onAppear { loadSettings() }
            .sheet(isPresented: $showingAddEndpoint) {
                EndpointFormView(mode: .add)
            }
            .sheet(item: $endpointToEdit) { config in
                EndpointFormView(mode: .edit(config))
            }
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
        if let savedTavilyKey = secureStorageService.getTavilyAPIKey() {
            tavilyAPIKey = savedTavilyKey
        }
        systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
    }

    private func saveSettings() {
        var normalizedEndpoint = ollamaEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalizedEndpoint.hasSuffix("/") { normalizedEndpoint.removeLast() }

        secureStorageService.saveEndpoint(normalizedEndpoint)
        secureStorageService.saveAPIKey(apiKey)
        secureStorageService.saveTavilyAPIKey(tavilyAPIKey)
        UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt")

        print("Saved settings - Endpoint: \(normalizedEndpoint), API Key present: \(!apiKey.isEmpty)")
    }

    private func deleteAllConversations() {
        chatManager.conversations.removeAll()
        localStorageService.deleteAllData()
    }
}
