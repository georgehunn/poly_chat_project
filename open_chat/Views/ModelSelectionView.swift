import SwiftUI

struct ModelSelectionView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var chatManager: ChatManager

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
                        ForEach(modelManager.models, id: \.name) { model in
                            Button(action: {
                                selectModel(model)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(model.displayName)
                                            .font(.headline)
                                        Text(model.provider)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
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
    }

    private func selectModel(_ model: ModelInfo) {
        if let onModelSelected = onModelSelected {
            onModelSelected(model)
        } else {
            // Default behavior: create new conversation
            let newConversation = chatManager.createNewConversation(model: model)
        }
        presentationMode.wrappedValue.dismiss()
    }
}