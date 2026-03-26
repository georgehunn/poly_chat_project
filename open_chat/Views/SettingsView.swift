import SwiftUI

struct SettingsView: View {
    @State private var ollamaEndpoint = "http://localhost:11434"
    @State private var apiKey = ""
    @State private var darkMode = false
    @State private var showingDeleteAlert = false
    @State private var showingExportView = false
    @State private var exportedData: Data?
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
                        .onSubmit {
                            saveSettings()
                        }
                        .onChange(of: ollamaEndpoint) { newValue in
                            // Auto-save when endpoint changes
                            saveSettings()
                        }
                    TextField("API Key (optional)", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                        .disableAutocorrection(true)
                        .submitLabel(.done)
                        .onSubmit {
                            saveSettings()
                        }
                        .onChange(of: apiKey) { newValue in
                            // Auto-save when API key changes
                            saveSettings()
                        }
                }

                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                        .onChange(of: darkMode) { _ in
                            saveSettings()
                        }
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
                    Text("OpenChat v1.0")
                    Text("Open source ChatGPT alternative")
                }
            }
            .navigationTitle("Settings")
            .alert("Confirm Deletion", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteAllConversations()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete all conversations? This cannot be undone.")
            }
            .sheet(isPresented: $showingExportView) {
                if let data = exportedData {
                    SimpleShareView(data: data)
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        // Load settings from secure storage and UserDefaults
        if let savedEndpoint = secureStorageService.getEndpoint() {
            ollamaEndpoint = savedEndpoint
        } else if let savedEndpoint = UserDefaults.standard.string(forKey: "ollamaEndpoint") {
            ollamaEndpoint = savedEndpoint
            // Migrate to secure storage
            secureStorageService.saveEndpoint(savedEndpoint)
            UserDefaults.standard.removeObject(forKey: "ollamaEndpoint")
        }

        if let savedApiKey = secureStorageService.getAPIKey() {
            apiKey = savedApiKey
        } else if let savedApiKey = UserDefaults.standard.string(forKey: "apiKey") {
            apiKey = savedApiKey
            // Migrate to secure storage
            secureStorageService.saveAPIKey(savedApiKey)
            UserDefaults.standard.removeObject(forKey: "apiKey")
        }

        darkMode = UserDefaults.standard.bool(forKey: "darkMode")
    }

    private func saveSettings() {
        // Validate and normalize endpoint
        var normalizedEndpoint = ollamaEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing slashes
        while normalizedEndpoint.hasSuffix("/") {
            normalizedEndpoint.removeLast()
        }

        // Save validated endpoint
        UserDefaults.standard.set(normalizedEndpoint, forKey: "ollamaEndpoint")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        UserDefaults.standard.set(darkMode, forKey: "darkMode")

        print("Saved settings - Endpoint: \(normalizedEndpoint), API Key present: \(!apiKey.isEmpty)")
    }

    private func exportConversations() {
        // Export conversations as JSON
        let conversations = chatManager.conversations
        do {
            let data = try JSONEncoder().encode(conversations)

            // Create a temporary file URL
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("openchat_export.json")
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