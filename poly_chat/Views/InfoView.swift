import SwiftUI

struct InfoView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        Text("PolyChat Help")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 10)

                    // How to Use
                    InfoSectionView(title: "How to Use Poly_Chat") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1. Follow API key setup instructions below")
                                .padding(.vertical, 2)
                            Text("2. Explore available models by tapping the 💻 icon")
                                .padding(.vertical, 2)
                            Text("3. Start a new chat by tapping the ✏️ icon")
                                .padding(.vertical, 2)
                            Text("4. Select a model from the list when prompted")
                                .padding(.vertical, 2)
                            Text("5. Type your message and tap send")
                                .padding(.vertical, 2)
                        }
                    }

                    // API Key Information
                    InfoSectionView(title: "API Key Information") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Poly_Chat works with models that are accessable via API, Ollama has a large amount of opensource models that can be accessed for free if you create an account.")
                                .padding(.bottom, 5)

                            Text("To use Ollama servers:")
                                .fontWeight(.semibold)
                                .padding(.top, 5)

                            Text("1. Set up Ollama account and create an API key")
                                .padding(.vertical, 2)
                            Text("2. enter the url https://ollama.com/api in the url field in settings")
                                .padding(.vertical, 2)
                            Text("3. Add your API key in the API key field in settings")
                                .padding(.vertical, 2)

                            Text("Note: API keys are stored securely in your device's keychain.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                        }
                    }

                    // Ollama Information
                    InfoSectionView(title: "About Poly_Chat") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Poly_Chat allows you to access LLMs via api while keeping ownership over your data - nothing is saved on the cloud")
                                .padding(.bottom, 5)

                            Link("Visit our website to understand more about the project", destination: URL(string: "https://www.polychat.me")!)
                                .foregroundColor(.blue)
                                .underline()

                            Text("Values:")
                                .fontWeight(.semibold)
                                .padding(.top, 5)

                            Text("1. Privacy first")
                                .padding(.vertical, 2)
                            Text("2. Transparency of models and data usage")
                                .padding(.vertical, 2)
                            Text("3. Democratic developement")
                                .padding(.vertical, 2)

                        }
                    }

                    // Tips
                    InfoSectionView(title: "Tips") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("• Different models have different strengths and capabilities")
                                .padding(.vertical, 2)
                            Text("• Larger models generally provide better responses but use more resources")
                                .padding(.vertical, 2)
                            Text("• Check model details to understand their capabilities before use")
                                .padding(.vertical, 2)
                            Text("• You can export and backup your conversations from Settings")
                                .padding(.vertical, 2)
                        }
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct InfoSectionView<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            content
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct InfoView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView()
    }
}