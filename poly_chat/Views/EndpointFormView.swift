import SwiftUI

/// Form for adding or editing a custom OpenAI-compatible API endpoint.
struct EndpointFormView: View {
    enum Mode {
        case add
        case edit(APIProviderConfig)
    }

    let mode: Mode
    var onSave: (() -> Void)?

    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var providerManager = ProviderManager.shared

    @State private var name = ""
    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var testStatus: TestStatus = .idle

    enum TestStatus {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingConfig: APIProviderConfig? {
        if case .edit(let config) = mode { return config }
        return nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Endpoint Details")) {
                    TextField("Name (e.g. My OpenAI)", text: $name)
                        .disableAutocorrection(true)
                        .autocapitalization(.words)

                    TextField("Base URL (e.g. https://api.openai.com/v1)", text: $endpoint)
                        .disableAutocorrection(true)
                        .autocapitalization(.none)
                        .keyboardType(.URL)

                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .disableAutocorrection(true)
                }

                Section {
                    Button(action: testConnection) {
                        if case .testing = testStatus {
                            HStack {
                                ProgressView().scaleEffect(0.75)
                                Text("Testing…")
                            }
                        } else {
                            Text("Test Connection")
                        }
                    }
                    .disabled({
                        if case .testing = testStatus { return true }
                        return endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }())

                    testStatusRow
                }

                Section(footer: Text("Any OpenAI-compatible API can be used here — OpenAI, local servers, or other hosted providers.")) {
                    EmptyView()
                }
            }
            .navigationTitle(isEditing ? "Edit Endpoint" : "Add Endpoint")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { populateForEdit() }
        }
    }

    @ViewBuilder
    private var testStatusRow: some View {
        switch testStatus {
        case .idle:
            EmptyView()
        case .testing:
            EmptyView()
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

    private func populateForEdit() {
        guard let config = existingConfig else { return }
        name = config.name
        endpoint = config.endpoint
        apiKey = config.apiKey
    }

    private func testConnection() {
        testStatus = .testing
        let normalizedEndpoint = normalizeEndpoint(endpoint)
        let key = apiKey

        Task {
            do {
                let tempConfig = APIProviderConfig(
                    name: name.isEmpty ? "Test" : name,
                    providerType: .openAICompatible,
                    endpoint: normalizedEndpoint,
                    apiKey: key
                )
                let models = try await OpenAIBackendAdapter.listModels(provider: tempConfig)
                testStatus = .success("Connected — \(models.count) model(s) available")
            } catch {
                testStatus = .failure("Failed: \(error.localizedDescription)")
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEndpoint = normalizeEndpoint(endpoint)

        if let existing = existingConfig {
            var updated = existing
            updated.name = trimmedName
            updated.endpoint = normalizedEndpoint
            updated.apiKey = apiKey
            providerManager.updateCustomProvider(updated)
        } else {
            providerManager.addCustomProvider(name: trimmedName, endpoint: normalizedEndpoint, apiKey: apiKey)
        }

        onSave?()
        presentationMode.wrappedValue.dismiss()
    }

    private func normalizeEndpoint(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        if !s.contains("/v1") { s += "/v1" }
        return s
    }
}
