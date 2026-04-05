import SwiftUI
import UIKit

struct APIConfigPopup: View {
    @Environment(\.presentationMode) var presentationMode

    @State private var endpoint = "https://ollama.com/api"
    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var validationMessageType: MessageType = .none

    enum MessageType {
        case success, error, none
    }

    let secureStorage = SecureStorageService()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ollama Configuration")) {
                    TextField("Ollama Endpoint", text: $endpoint)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    // API Key field - user types into the field below
                    SecureField("Enter API Key", text: $apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    Button("Get Free API Key from Ollama.com") {
                        if let url = URL(string: "https://ollama.com") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())

                    Button(isValidating ? "Testing Connection..." : "Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(isValidating)
                    .buttonStyle(BorderlessButtonStyle())
                    .foregroundColor(.blue)
                }

                if let message = validationMessage, validationMessageType != .none {
                    Section {
                        HStack {
                            Image(systemName: validationMessageType == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(validationMessageType == .success ? .green : .red)
                            Text(message)
                                .foregroundColor(validationMessageType == .success ? .green : .red)
                                .font(.caption)
                        }
                    }
                }

                Section(header: Text("")) {
                    Text("Enter API key to get started. You can create a free one at www.ollama.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Configure API")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .disabled(!isEndpointValid || isValidating)
                }
            }
            .onAppear {
                // Load existing settings
                if let savedEndpoint = secureStorage.getEndpoint() {
                    endpoint = savedEndpoint
                }
                if let savedApiKey = secureStorage.getAPIKey() {
                    apiKey = savedApiKey
                }
            }
        }
    }

    private var isEndpointValid: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func testConnection() async {
        guard isEndpointValid else {
            validationMessage = "Please enter a valid endpoint URL"
            validationMessageType = .error
            return
        }

        isValidating = true
        validationMessage = nil

        do {
            try await OllamaService.validateConnection(endpoint: endpoint, apiKey: apiKey.isEmpty ? nil : apiKey)
            validationMessage = "Connection successful!"
            validationMessageType = .success
        } catch OllamaService.ValidationError.unauthorized {
            validationMessage = "Connected but unauthorized. API key may be invalid."
            validationMessageType = .error
        } catch OllamaService.ValidationError.connectionFailed(let error) {
            validationMessage = "Connection failed: \(error.localizedDescription)"
            validationMessageType = .error
        } catch OllamaService.ValidationError.invalidEndpoint {
            validationMessage = "Invalid endpoint URL"
            validationMessageType = .error
        } catch {
            validationMessage = "Connection failed: \(error.localizedDescription)"
            validationMessageType = .error
        }

        isValidating = false
    }

    private func saveAndDismiss() {
        // Normalize endpoint
        var normalizedEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalizedEndpoint.hasSuffix("/") {
            normalizedEndpoint.removeLast()
        }

        // Save to secure storage
        secureStorage.saveEndpoint(normalizedEndpoint)
        secureStorage.saveAPIKey(apiKey)

        // Dismiss the popup
        presentationMode.wrappedValue.dismiss()
    }
}

struct APIConfigPopup_Previews: PreviewProvider {
    static var previews: some View {
        APIConfigPopup()
    }
}
