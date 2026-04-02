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
                if modelManager.isLoading {
                    Section(header: Text("Select a Model")) {
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
                    }
                } else if modelManager.models.isEmpty {
                    Section(header: Text("Select a Model")) {
                        Text("No models available")
                            .foregroundColor(.secondary)
                    }
                } else {
                    let starred = sortedModels.filter { modelManager.isStarred($0) }
                    let unstarred = sortedModels.filter { !modelManager.isStarred($0) }

                    if !starred.isEmpty {
                        Section(header: Text("Starred")) {
                            ForEach(starred, id: \.name) { model in
                                modelSelectionRow(model)
                            }
                        }
                    }

                    Section(header: Text(starred.isEmpty ? "Select a Model" : "All Models")) {
                        ForEach(unstarred, id: \.name) { model in
                            modelSelectionRow(model)
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

    @ViewBuilder
    private func modelSelectionRow(_ model: ModelInfo) -> some View {
        Button(action: {
            selectModel(model)
        }) {
            HStack {
                if modelManager.isStarred(model) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.yellow)
                }
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

    private var sortedModels: [ModelInfo] {
        modelManager.models.sorted { $0.name < $1.name }
    }
}
