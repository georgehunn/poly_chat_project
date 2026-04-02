import SwiftUI

struct SettingsView: View {
    @State private var ollamaEndpoint = "https://ollama.com/api"
    @State private var apiKey = ""
    @AppStorage("darkMode") private var darkMode = false
    @State private var systemPrompt = ""
    @State private var showingDeleteAlert = false
    @State private var showingExportView = false
    @State private var exportedData: Data?
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

                Section(header: Text("Default System Prompt")) {
                    TextEditor(text: $systemPrompt)
                        .frame(height: 100)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: systemPrompt) { _ in
                            saveSettings()
                        }
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
        // Load settings from secure storage
        if let savedEndpoint = secureStorageService.getEndpoint() {
            ollamaEndpoint = savedEndpoint
        }

        if let savedApiKey = secureStorageService.getAPIKey() {
            apiKey = savedApiKey
        }

        systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
    }

    private func saveSettings() {
        // Validate and normalize endpoint
        var normalizedEndpoint = ollamaEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing slashes
        while normalizedEndpoint.hasSuffix("/") {
            normalizedEndpoint.removeLast()
        }

        // Save to secure storage (Keychain)
        secureStorageService.saveEndpoint(normalizedEndpoint)
        secureStorageService.saveAPIKey(apiKey)

        // Save non-sensitive settings to UserDefaults
        UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt")

        print("Saved settings - Endpoint: \(normalizedEndpoint), API Key present: \(!apiKey.isEmpty)")
    }

    private func exportConversations() {
        // Export conversations as JSON
        let conversations = chatManager.conversations
        do {
            let data = try JSONEncoder().encode(conversations)

            // Create a temporary file URL
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