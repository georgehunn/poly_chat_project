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
                            Text("1. Follow API key setup instructions (below)")
                                .padding(.vertical, 2)
                            Text("2. Explore models by tapping the 💻 icon")
                                .padding(.vertical, 2)
                            Text("3. Start a new chat by tapping the ✏️ icon")
                                .padding(.vertical, 2)
                            Text("4. Choose a model when prompted")
                                .padding(.vertical, 2)
                            Text("5. Type your message and tap send")
                                .padding(.vertical, 2)
                        }
                    }
                    // Ollama Information
                    InfoSectionView(title: "About Poly_Chat") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Poly_Chat is an open source oroject that allows you to access LLMs via api while keeping ownership over your data. We save nothing on the cloud (check with api provider for their specific policy)")
                                .padding(.bottom, 5)

                            Link("Project website", destination: URL(string: "https://www.polychat.me")!)
                                .foregroundColor(.blue)
                                .underline()
                            

                            Link("Project on github", destination: URL(string: "https://github.com/georgehunn/poly_chat_project")!)
                                .foregroundColor(.blue)
                                .underline()
                            Text("If you enjoy this app, please consider giving it a star ⭐️. If you'd like to contribute, check out the GitHub repo or feel free to reach out.")
                                .padding(.vertical, 2)

                            Text("Values:")
                                .fontWeight(.semibold)
                                .padding(.top, 5)

                            Text("1. Control - Use the models you want, switch anytime.")
                                .padding(.vertical, 2)
                            Text("2. Privacy first - Your data stays on your device.")
                                .padding(.vertical, 2)
                            Text("3. Useful > flashy - Useful features that support how people actually use AI.")
                                .padding(.vertical, 2)

                        }
                    }


                    // API Key Information
                    InfoSectionView(title: "API Key Information") {
                        VStack(alignment: .leading, spacing: 14) {

                            Text("PolyChat connects to external services using API keys. Your data stays on your device — API keys are stored securely in your keychain.")
                                .padding(.bottom, 4)

                            // MARK: - Ollama Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Ollama (Models)")
                                    .font(.headline)

                                Text("Access a wide range of open-source models hosted on Ollama Cloud. Supports chat, tools, and multi-turn conversations.")
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1. Create an Ollama account")
                                    Text("2. Generate an API key")
                                    Text("3. Set URL to https://ollama.com/api")
                                    Text("4. Paste your API key in Settings")
                                }
                                .padding(.top, 4)

                            Link("Read about Ollama's cloud models and data processing", destination: URL(string: "https://ollama.com/blog/cloud-models")!)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                                .padding(.top, 4)
                            }
                            Divider().padding(.vertical, 4)
                            // MARK: - General API Endpoint Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Other API endpoints")
                                    .font(.headline)

                                Text("Connect to any OpenAI-compatible API endpoint. Models from these endpoints will appear alongside Ollama models when starting a new chat. Note: Some endpoints may not support chat or all features (e.g. tools, multi-turn). Check the documentation for required configuration.")
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1. Set up you api key with your provider")
                                    Text("2. Enter your API endpoint URL and key in Settings")
                                    Text("3. Test your connection and start chatting!")
                                }
                                .padding(.top, 4)
                            }
                            Divider().padding(.vertical, 4)

                            // MARK: - Tavily Section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tavily (Web Search)")
                                    .font(.headline)

                                Text("Enable real-time web search for your chats using Tavily’s API. A free tier is available.")
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("1. Create an account at tavily.com")
                                    Text("2. Generate an API key")
                                    Text("3. Add your API key in Settings")
                                }
                                .padding(.top, 4)
                            }

                            Text("Note: API keys are stored securely in your device’s keychain.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 6)
                    }
}

                    // Ollama Information
                    InfoSectionView(title: "About Poly_Chat") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Poly_Chat is an open source oroject that allows you to access LLMs via api while keeping ownership over your data. We save nothing on the cloud (check with api provider for their specific policy)")
                                .padding(.bottom, 5)

                            Link("Project website", destination: URL(string: "https://www.polychat.me")!)
                                .foregroundColor(.blue)
                                .underline()
                            

                            Link("Project on github", destination: URL(string: "https://github.com/georgehunn/poly_chat_project")!)
                                .foregroundColor(.blue)
                                .underline()
                            Text("If you enjoy this app, please consider giving it a star ⭐️. If you'd like to contribute, check out the GitHub repo or feel free to reach out.")
                                .padding(.vertical, 2)

                            Text("Values:")
                                .fontWeight(.semibold)
                                .padding(.top, 5)

                            Text("1. Control - Use the models you want, switch anytime.")
                                .padding(.vertical, 2)
                            Text("2. Privacy first - Your data stays on your device.")
                                .padding(.vertical, 2)
                            Text("3. Useful > flashy - Useful features that support how people actually use AI.")
                                .padding(.vertical, 2)

                        }
                    }

                    // Tips
                    InfoSectionView(title: "Tips") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Different models have different strengths and capabilities")
                                .padding(.vertical, 2)
                            Text("Larger models generally provide better responses but use more resources")
                                .padding(.vertical, 2)
                            Text("Check model details to understand their capabilities before use")
                                .padding(.vertical, 2)
                            Text("You can export and backup your conversations from Settings")
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