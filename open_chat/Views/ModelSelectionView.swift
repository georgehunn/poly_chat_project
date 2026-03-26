import SwiftUI

struct ModelSelectionView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @Binding var selectedModel: ModelInfo?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Models")) {
                    if modelManager.models.isEmpty {
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
                    } else {
                        ForEach(modelManager.models, id: \.name) { model in
                            Button(action: {
                                selectedModel = model
                                presentationMode.wrappedValue.dismiss()
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

                                    if selectedModel?.name == model.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                if !modelManager.models.isEmpty {
                    Section(header: Text("Model Information")) {
                        if let model = selectedModel {
                            Text("Selected: \(model.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No model selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                modelManager.loadModels()
            }
        }
    }
}