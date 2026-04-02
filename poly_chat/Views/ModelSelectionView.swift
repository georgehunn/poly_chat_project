import SwiftUI

struct ModelSelectionView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var chatManager: ChatManager
    @State private var showingConfigAlert = false
    @State private var showingSettings = false

    var onModelSelected: ((ModelInfo) -> Void)?

    init(onModelSelected: ((ModelInfo) -> Void)? = nil) {
        self.onModelSelected = onModelSelected
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select a Model")) {
                    if modelManager.isLoading {
                        HStack {
                            Spacer()
                            VStack {
                                ProgressView()
                                Text("Loading models...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                    } else if modelManager.models.isEmpty {
                        Text("No models available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sortedModels, id: \.name) { model in
                            Button(action: {
                                selectModel(model)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(model.displayName)
                                            .font(.headline)
                                        Text(model.provider)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 4) {
                                        if model.hasVision == true {
                                            CapabilityBadge(icon: "eye.fill", label: "Vision", color: .purple)
                                        }
                                        if model.hasTools == true {
                                            CapabilityBadge(icon: "wrench.and.screwdriver.fill", label: "Tools", color: .orange)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Model")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if modelManager.models.isEmpty && !modelManager.isLoading {
                modelManager.loadModels()
            }
        }
        .alert("Configuration Required", isPresented: $showingConfigAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                showingSettings = true
            }
        } message: {
            Text("URL and API key not set up. Please configure them in Settings.")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func selectModel(_ model: ModelInfo) {
        // Check if URL and API key are configured before allowing model selection
        if !OllamaService.isConfigured() {
            showingConfigAlert = true
            return
        }

        if let onModelSelected = onModelSelected {
            onModelSelected(model)
        } else {
            // Default behavior: create new conversation
            let newConversation = chatManager.createNewConversation(model: model)
        }
        presentationMode.wrappedValue.dismiss()
    }

    private var sortedModels: [ModelInfo] {
        modelManager.models.sorted { $0.name < $1.name }
    }
}
